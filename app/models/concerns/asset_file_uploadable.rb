# frozen_string_literal: true

require 'active_support/concern'

module AssetFileUploadable
  extend ActiveSupport::Concern

  MAX_FILE_SIZE = 200.megabytes

  included do
    validates :handle, presence: true

    before_validation do
      self.handle ||= SecureRandom.urlsafe_base64(32)
    end

    before_destroy :capture_object_key_for_cleanup
    after_destroy :destroy_s3_object
  end

  def object_key
    raise unless persisted?

    "#{self.class.asset_file_global_prefix}#{prefix}#{handle}--#{id}"
  end

  def make_session
    upload_url_and_fields.merge(
      id: id.to_s,
    )
  end

  def download_url(disposition: :attachment)
    encoded_filename = ERB::Util.url_encode(filename)
    content_disposition = if filename.ascii_only?
      "#{disposition}; filename=\"#{filename}\""
    else
      "#{disposition}; filename=\"#{encoded_filename}\"; filename*=UTF-8''#{encoded_filename}"
    end

    presigner.presigned_url(
      :get_object,
      bucket: self.class.asset_file_bucket,
      key: object_key,
      expires_in: 3600,
      response_content_disposition: content_disposition,
    )
  end

  def get_object(**args)
    s3_client.get_object(bucket: self.class.asset_file_bucket, key: object_key, **args)
  end

  def put_object(**args)
    s3_client.put_object(bucket: self.class.asset_file_bucket, key: object_key, **args)
  end

  def upload_url_and_fields
    max_file_size = self.class.const_get(:MAX_FILE_SIZE)

    # Use exact Content-Type from model attribute (validated by AR before this call).
    # This pins the presigned POST to the specific content type the client declared.
    post_opts = {
      key: object_key,
      signature_expiration: Time.zone.now + 900,
      content_length_range: 0..max_file_size,
      use_accelerate_endpoint: true,
      allow_any: ['x-amz-checksum-algorithm', 'x-amz-checksum-sha256'],
    }
    if content_type.present?
      post_opts[:content_type] = content_type
    else
      post_opts[:allow_any] += ['Content-Type']
    end

    # see also config/initializers/aws_s3_patches.rb to force dualstack endpoint
    sign = Aws::S3::PresignedPost.new(
      Session.new(self).credentials,
      self.class.asset_file_region,
      self.class.asset_file_bucket,
      post_opts,
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
    self.content_type = head.content_type
    self
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(use_dualstack_endpoint: true, region: self.class.asset_file_region, logger: Rails.logger)
  end

  private def capture_object_key_for_cleanup
    @object_key_for_cleanup = object_key
  end

  private def destroy_s3_object
    return unless @object_key_for_cleanup

    s3_client.delete_object(bucket: self.class.asset_file_bucket, key: @object_key_for_cleanup)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.warn("Failed to delete S3 object #{@object_key_for_cleanup}: #{e.message}")
  end

  private def presigner
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
      resource = "arn:aws:s3:::#{file.class.asset_file_bucket}/#{file.object_key}"
      {
        Version: '2012-10-17',
        Statement: [
          {
            Effect: 'Allow',
            Action: %w(s3:PutObject),
            Resource: resource,
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
        role_session_name: "file-#{file.id}",
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
