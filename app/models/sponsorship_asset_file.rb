class SponsorshipAssetFile < ApplicationRecord
  REGION = ENV['S3_FILES_REGION']
  BUCKET = ENV['S3_FILES_BUCKET']
  PREFIX = ENV['S3_FILES_PREFIX']

  MAX_FILE_SIZE = 200.megabytes

  ROLE = ENV['S3_FILES_ROLE']

  belongs_to :sponsorship, optional: true

  scope :available_for_user, ->(id, session_asset_file_ids: [], available_sponsorship_ids: []) do
    where(id:)
      .merge(
        SponsorshipAssetFile.where(sponsorship_id: available_sponsorship_ids)
          .or(SponsorshipAssetFile.where(sponsorship_id: nil, id: session_asset_file_ids || []))
      )
  end

  validates :handle, presence: true

  validate :validate_ownership_not_changed

  before_validation do
    self.handle ||= SecureRandom.urlsafe_base64(32)
  end

  def copy_to!(conference)
    dst = self.class.create!(prefix: "c-#{conference.id}/", extension: self.extension)
    s3_client.copy_object(
      bucket: BUCKET,
      copy_source: "#{BUCKET}/#{object_key}",
      key: dst.object_key,
    )
    dst.update_object_header
    dst
  end

  def object_key
    raise unless self.persisted?
    "#{PREFIX}#{prefix}#{handle}--#{id}"
  end

  def make_session
    upload_url_and_fields.merge(
      id: id.to_s,
    )
  end

  def filename
    "S#{id}_#{sponsorship&.slug}.#{extension}"
  end

  def download_url
    presigner.presigned_url(
      :get_object,
      bucket: BUCKET,
      key: object_key,
      expires_in: 3600,
      response_content_disposition: "attachment; filename=\"#{filename}\"",
    )
  end

  def upload_url_and_fields
    # see also config/initializers/aws_s3_patches.rb to force dualstack endpoint
    sign = Aws::S3::PresignedPost.new(
      Session.new(self).credentials, # don't leak primary session token
      REGION,
      BUCKET,
      {
        key: object_key,
        signature_expiration: Time.now+900,
        content_length_range: 0..MAX_FILE_SIZE,
        use_accelerate_endpoint: true,
        allow_any: ['Content-Type', 'x-amz-checksum-algorithm', 'x-amz-checksum-sha256'],
      },
    )
    {
      url: sign.url,
      fields: sign.fields,
      max_size: MAX_FILE_SIZE,
    }
  end

  def update_object_header
    head = s3_client.head_object(bucket: BUCKET, key: object_key, checksum_mode: :enabled)
    self.version_id = head.version_id if head.version_id != version_id
    self.last_modified_at = head.last_modified
    self.checksum_sha256 = head.checksum_sha256 || "-"
    self
  end

  private def presigner
    @presigner ||= Aws::S3::Presigner.new(client: s3_client)
  end

  private def s3_client
    @s3_client ||= Aws::S3::Client.new(use_dualstack_endpoint: true, region: REGION, logger: Rails.logger)
  end

  private def validate_ownership_not_changed
    if sponsorship_id_changed? && !sponsorship_id_was.nil?
      errors.add :sponsorship_id, "cannot be changed"
    end
  end

  class Session
    def initialize(file)
      @file = file
    end

    attr_reader :file

    def sts
      @sts ||= Aws::STS::Client.new
    end

    def iam_policy
      {
        Version: '2012-10-17',
        Statement: [
          {
            Effect: 'Allow',
            Action: %w(
              s3:PutObject
            ),
            Resource: "arn:aws:s3:::#{BUCKET}/#{file.object_key}",
            Condition: {
              StringEqualsIfExists: {
                "s3:x-amz-storage-class" => "STANDARD",
              },
              Null: {
                "s3:x-amz-server-side-encryption" => true,
                "s3:x-amz-server-side-encryption-aws-kms-key-id" => true,
                "s3:x-amz-website-redirect-location" => true,
                # These cannot be applied unless a bucket has ObjectLockConfiguration, but to ensure safety
                "s3:object-lock-legal-hold" => true,
                "s3:object-lock-retain-until-date" => true,
                "s3:object-lock-remaining-retention-days" => true,
                # ACLs cannot be applied unless s3:PutObjectAcl
              },
            },
          },
        ],
      }
    end

    def role_session
      @role_session ||= sts.assume_role(
        duration_seconds: 900,
        role_arn: ROLE,
        role_session_name: "file-#{file.id.to_s}",
        policy: iam_policy.to_json,
      )
    end

    def credentials
      Aws::Credentials.new(
        role_session.credentials.access_key_id,
        role_session.credentials.secret_access_key,
        role_session.credentials.session_token,
      )
    end
  end
end
