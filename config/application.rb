require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SponsorApp2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :ja]
    config.i18n.fallbacks = [:en]

    begin
      config.semantic_logger.application = "sponsor-app"
      config.semantic_logger.environment = Rails.env
      config.rails_semantic_logger.started = :info

      config.log_tags = {
        request_id: :request_id,
        method: :request_method,
        path: :path_info,
        ip: :ip,
      }

      if ENV["RAILS_LOG_TO_STDOUT"].present?
        config.rails_semantic_logger.add_file_appender = false
        config.semantic_logger.add_appender(io: $stdout, formatter: :json)
      end
    end
  end
end
