Rails.configuration.semantic_logger.application = "sponsor-app"
Rails.configuration.semantic_logger.environment = Rails.env
Rails.configuration.rails_semantic_logger.started = :info

Rails.configuration.log_tags = {
  request_id: :request_id,
  method: :request_method,
  path: :path_info,
  ip: :ip,
}

if ENV["RAILS_LOG_TO_STDOUT"].present?
  Rails.configuration.rails_semantic_logger.add_file_appender = false
  Rails.configuration.semantic_logger.add_appender(io: $stdout, formatter: :json)
end

begin
  # Rails 8.1 compat, https://github.com/reidmorrison/rails_semantic_logger/pull/276#issuecomment-3533151110
  require 'rails_semantic_logger/version'
  raise "Check monkey patch best-before-by" if RailsSemanticLogger::VERSION != "4.18.0"
  class RailsSemanticLogger::ActiveRecord::LogSubscriber
    def self.runtime = 0
    def self.runtime=(_ms); end
  end
end
