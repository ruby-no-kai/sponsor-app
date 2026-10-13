# typed: true

# Tapioca emits no instance variables, and the #bucket_url override in
# config/initializers/aws_s3_patches.rb reads these.
class Aws::S3::PresignedPost
  def initialize(credentials, bucket_region, bucket_name, options = T.unsafe(nil))
    @bucket_region = T.let(T.unsafe(nil), String)
    @bucket_name = T.let(T.unsafe(nil), String)
    @accelerate = T.let(T.unsafe(nil), T::Boolean)
  end
end

# Defined on first reference by Aws::Errors::DynamicErrors, for an error answered with no body,
# such as a HeadObject of a missing key.
class Aws::S3::Errors::NotFound < Aws::S3::Errors::ServiceError; end
