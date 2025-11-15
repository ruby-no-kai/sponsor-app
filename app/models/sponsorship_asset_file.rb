class SponsorshipAssetFile < ApplicationRecord
  REGION = ENV['S3_FILES_REGION']
  BUCKET = ENV['S3_FILES_BUCKET']
  PREFIX = ENV['S3_FILES_PREFIX']

  ROLE = ENV['S3_FILES_ROLE']

  belongs_to :sponsorship, optional: true
  validates :handle, presence: true

  validate :validate_ownership_not_changed

  before_validation do
    self.handle ||= SecureRandom.urlsafe_base64(32)
  end

  def copy_to!(conference)
    dst = self.class.create!(prefix: "c-#{conference.id}/", extension: self.extension)
    Aws::S3::Client.new(logger: Rails.logger, region: REGION).copy_object(
      bucket: BUCKET,
      copy_source: "#{BUCKET}/#{object_key}",
      key: dst.object_key,
    )
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
        content_length_range: 0..200.megabytes,
        use_accelerate_endpoint: true,
        allow_any: ['Content-Type'],
      },
    )
    {
      url: sign.url,
      fields: sign.fields,
    }
  end

  private def presigner
    @presigner ||= Aws::S3::Presigner.new(client: Aws::S3::Client.new(use_dualstack_endpoint: true, region: REGION))
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
