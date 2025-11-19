# see also config/application.rb
begin
  # Rails 8.1 compat, https://github.com/reidmorrison/rails_semantic_logger/pull/276#issuecomment-3533151110
  require 'rails_semantic_logger/version'
  raise "Check monkey patch best-before-by" if RailsSemanticLogger::VERSION != "4.18.0"
  class RailsSemanticLogger::ActiveRecord::LogSubscriber
    def self.runtime = 0
    def self.runtime=(_ms); end
  end
end
