require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.x.public_url_host = ENV.fetch('DEFAULT_URL_HOST', 'localhost:3000')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  config.active_job.queue_adapter = :inline
  if ENV['ENABLE_SIDEKIQ']
    config.active_job.queue_name_prefix = "sponsor_app"
    config.active_job.queue_adapter = :sidekiq
  end

  if ENV['MAILGUN_SMTP_PASSWORD']
    config.action_mailer.smtp_settings = {
      :port           => ENV['MAILGUN_SMTP_PORT'],
      :address        => ENV['MAILGUN_SMTP_SERVER'],
      :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
      :password       => ENV['MAILGUN_SMTP_PASSWORD'],
      :domain         => ENV.fetch('DEFAULT_EMAIL_HOST'),
      :authentication => :plain,
      enable_starttls_auto: true,
    }
    config.action_mailer.delivery_method = :smtp
  else
    config.action_mailer.delivery_method = :letter_opener_web
  end


  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  config.action_mailer.default_url_options = {host: config.x.public_url_host, protocol: 'https'}

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # *.lo.example.org
  config.action_dispatch.tld_length = 2

  config.x.org_name = "RubyKaigi"

  config.x.default_email_address = ENV.fetch('DEFAULT_EMAIL_ADDRESS',  'sponsorapp@localhost')
  config.x.default_email_reply_to = ENV.fetch('DEFAULT_EMAIL_REPLY_TO', config.x.default_email_address)
  config.x.default_email_host_part = ENV.fetch('DEFAULT_EMAIL_HOST', 'localhost')

  config.x.github.repo = ENV['GITHUB_REPO']
  config.x.github.client_id = ENV['GITHUB_CLIENT_ID']
  config.x.github.client_secret = ENV['GITHUB_CLIENT_SECRET']
  config.x.github.app_id = ENV['GITHUB_APP_ID']
  config.x.github.private_key = ENV['GITHUB_CLIENT_PRIVATE_KEY'] && OpenSSL::PKey::RSA.new(ENV['GITHUB_CLIENT_PRIVATE_KEY'].unpack1('m*'), '')

  config.x.slack.webhook_urls = {
    default: ENV['SLACK_WEBHOOK_URL'],
    feed: ENV['SLACK_WEBHOOK_URL'],
  }

  config.x.mailgun.api_key = ENV['MAILGUN_API_KEY']
  config.x.sentry.dsn = ENV['SENTRY_DSN']

  config.x.tito.token = ENV['TITO_API_TOKEN']
end
