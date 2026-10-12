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
