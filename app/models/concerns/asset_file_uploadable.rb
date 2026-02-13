require 'active_support/concern'

module AssetFileUploadable
  extend ActiveSupport::Concern

  MAX_FILE_SIZE = 200.megabytes

  included do
    validates :handle, presence: true

    before_validation do
      self.handle ||= SecureRandom.urlsafe_base64(32)
    end
  end

  def object_key
    raise unless self.persisted?
    "#{self.class.asset_file_global_prefix}#{prefix}#{handle}--#{id}"
  end

  def make_session
    upload_url_and_fields.merge(
      id: id.to_s,
    )
  end

  def download_url
    presigner.presigned_url(
      :get_object,
      bucket: self.class.asset_file_bucket,
      key: object_key,
      expires_in: 3600,
      response_content_disposition: "attachment; filename=\"#{filename}\"",
    )
  end

  def get_object
    s3_client.get_object(bucket: self.class.asset_file_bucket, key: object_key)
  end

  def put_object(**args)
    s3_client.put_object(bucket: self.class.asset_file_bucket, key: object_key, **args)
  end

  def upload_url_and_fields
    max_file_size = self.class.const_get(:MAX_FILE_SIZE)
    # see also config/initializers/aws_s3_patches.rb to force dualstack endpoint
    sign = Aws::S3::PresignedPost.new(
      Session.new(self).credentials,
      self.class.asset_file_region,
      self.class.asset_file_bucket,
      {
        key: object_key,
        signature_expiration: Time.now+900,
        content_length_range: 0..max_file_size,
        use_accelerate_endpoint: true,
        allow_any: ['Content-Type', 'x-amz-checksum-algorithm', 'x-amz-checksum-sha256'],
      },
    )
    {
      url: sign.url,
      fields: sign.fields,
      max_size: max_file_size,
    }
  end

  def update_object_header
    head = s3_client.head_object(bucket: self.class.asset_file_bucket, key: object_key, checksum_mode: :enabled)
    self.version_id = head.version_id if head.version_id != version_id
    self.last_modified_at = head.last_modified
    self.checksum_sha256 = head.checksum_sha256 || "-"
    self
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(use_dualstack_endpoint: true, region: self.class.asset_file_region, logger: Rails.logger)
  end

  private

  def presigner
    @presigner ||= Aws::S3::Presigner.new(client: s3_client)
  end

  class_methods do
    def asset_file_region
      Rails.application.config.x.asset_file_uploadable.region
    end

    def asset_file_bucket
      Rails.application.config.x.asset_file_uploadable.bucket
    end

    def asset_file_global_prefix
      Rails.application.config.x.asset_file_uploadable.prefix
    end

    def asset_file_role
      Rails.application.config.x.asset_file_uploadable.role
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
            Resource: "arn:aws:s3:::#{file.class.asset_file_bucket}/#{file.object_key}",
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
        role_arn: file.class.asset_file_role,
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
