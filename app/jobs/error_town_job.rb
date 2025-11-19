class ErrorTownJob < ApplicationJob
  class Boom < StandardError; end

  def perform(request_id)
    raise Boom, "boom boom! #{request_id}"
  end
end
