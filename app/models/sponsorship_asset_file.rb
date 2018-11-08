class SponsorshipAssetFile < ApplicationRecord
  REGION = ENV['S3_FILES_REGION']
  BUCKET = ENV['S3_FILES_BUCKET']
  PREFIX = ENV['S3_FILES_PREFIX']

  ROLE = ENV['S3_FILES_ROLE']

  belongs_to :sponsorship, optional: true
  validates :handle, presence: true

  before_validation do
    self.handle ||= SecureRandom.urlsafe_base64(32)
  end

  def object_key
    raise unless self.persisted?
    "#{PREFIX}#{prefix}#{handle}--#{id}"
  end

  def make_session
    Session.new(self).as_json
  end

  def download_url
    presigner = Aws::S3::Presigner.new(client: Aws::S3::Client.new(use_dualstack_endpoint: true, region: REGION))
    presigner.presigned_url(
      :get_object,
      bucket: BUCKET,
      key: object_key,
      expires_in: 3600,
      response_content_disposition: "attachment; filename=\"S#{sponsorship&.id}_#{sponsorship&.name&.gsub(%r{ |　|/|:|,|\.},'_')}.#{extension}\"",
    )
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

    def as_json
      {
        id: file.id.to_s,
        region: REGION,
        bucket: BUCKET,
        key: file.object_key,
        credentials: {
          access_key_id: role_session.credentials.access_key_id,
          secret_access_key: role_session.credentials.secret_access_key,
          session_token: role_session.credentials.session_token,
        },
      }
    end
  end
end
