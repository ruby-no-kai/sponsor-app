require 'aws-sdk-s3'

# force use_dualstack_endpoint for presigned posts
module Aws
  module S3
    class PresignedPost
      def bucket_url
        params = Aws::S3::EndpointParameters.new(
          bucket: @bucket_name,
          region: @bucket_region,
          accelerate: @accelerate,
          use_global_endpoint: true,
          use_dual_stack: true,
        )
        endpoint = Aws::S3::EndpointProvider.new.resolve_endpoint(params)
        endpoint.url
      end
    end
  end
end
