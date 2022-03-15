Rails.application.configure do
  unless ENV['STACK'] # not during heroku build
    config.x.public_url_host = ENV.fetch('DEFAULT_URL_HOST')

    config.x.org_name = ENV.fetch('ORG_NAME')

    config.x.default_email_address = ENV.fetch('DEFAULT_EMAIL_ADDRESS')
    config.x.default_email_reply_to = ENV.fetch('DEFAULT_EMAIL_REPLY_TO', config.x.default_email_address)
    config.x.default_email_host_part = ENV.fetch('DEFAULT_EMAIL_HOST')

    config.x.github.repo = ENV.fetch('GITHUB_REPO')
    config.x.github.client_id = ENV.fetch('GITHUB_CLIENT_ID')
    config.x.github.client_secret = ENV.fetch('GITHUB_CLIENT_SECRET')
    config.x.github.app_id = ENV.fetch('GITHUB_APP_ID')
    config.x.github.private_key = OpenSSL::PKey::RSA.new(ENV.fetch('GITHUB_CLIENT_PRIVATE_KEY').unpack1('m*'), '')

    config.x.tito.token = ENV.fetch('TITO_API_TOKEN')

    config.x.slack.webhook_urls = {
      default: ENV.fetch('SLACK_WEBHOOK_URL'),
      feed: ENV.fetch('SLACK_WEBHOOK_URL_FOR_FEED', ENV.fetch('SLACK_WEBHOOK_URL')),
    }
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.public_file_server.headers = {'Cache-Control' => "public, max-age=172800, s-maxage=2592000"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true
  config.ssl_options = { hsts: { subdomains: false } }

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :debug

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store
  config.cache_store = :redis_cache_store, { url: [ENV['REDIS_URL']], pool_size: 5, pool_timeout: 5 }

  config.session_store = :cache_store, {
    expire_in: 14.days,
  }

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  config.active_job.queue_adapter = ENV.fetch('DISABLE_SIDEKIQ', '0') == '1' ? :inline : :sidekiq
  # config.active_job.queue_name_prefix = "sponsor_app2_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  config.action_mailer.default_url_options = {host: config.x.public_url_host, protocol: 'https'}

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
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Inserts middleware to perform automatic connection switching.

  # The `database_selector` hash is used to pass options to the DatabaseSelector
  # middleware. The `delay` is used to determine how long to wait after a write
  # to send a subsequent read to the primary.
  #
  # The `database_resolver` class is used by the middleware to determine which
  # database is appropriate to use based on the time delay.
  #
  # The `database_resolver_context` class is used by the middleware to set
  # timestamps for the last write to the primary. The resolver uses the context
  # class timestamps to determine how long to wait before reading from the
  # replica.
  #
  # By default Rails will store a last write timestamp in the session. The
  # DatabaseSelector middleware is designed as such you can define your own
  # strategy for connection switching and pass that into the middleware through
  # these configuration options.
  # config.active_record.database_selector = { delay: 2.seconds }
  # config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  # config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session

  config.active_record.cache_versioning = false

  config.x.mailgun.api_key = ENV['MAILGUN_API_KEY']

  config.x.sentry.dsn = ENV['SENTRY_DSN']
end
