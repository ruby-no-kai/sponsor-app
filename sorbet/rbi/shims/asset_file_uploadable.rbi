# typed: true

# Columns and readers of the including models, which Sorbet cannot see from
# the module.
module AssetFileUploadable
  sig { returns(String) }
  def prefix; end

  sig { returns(String) }
  def handle; end

  sig { params(value: String).returns(String) }
  def handle=(value); end

  sig { returns(T.nilable(String)) }
  def filename; end

  sig { returns(T.nilable(String)) }
  def content_type; end

  sig { params(value: T.nilable(String)).returns(T.nilable(String)) }
  def content_type=(value); end

  sig { returns(String) }
  def version_id; end

  sig { params(value: String).returns(String) }
  def version_id=(value); end

  sig { params(value: T.nilable(ActiveSupport::TimeWithZone)).returns(T.nilable(ActiveSupport::TimeWithZone)) }
  def last_modified_at=(value); end

  sig { params(value: String).returns(String) }
  def checksum_sha256=(value); end
end
