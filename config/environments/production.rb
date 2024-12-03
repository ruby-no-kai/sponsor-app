require "active_support/core_ext/integer/time"

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
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.public_file_server.headers = {'Cache-Control' => "public, max-age=172800, s-maxage=2592000"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true
  config.ssl_options = { hsts: { subdomains: false } } # TODO: update
  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store
  # config.cache_store = :redis_cache_store, { url: [ENV['REDIS_URL']], pool_size: 5, pool_timeout: 5 }

  config.session_store(:cookie_store,
    expire_after: 14.days,
    key: '__Host-rk-sponsorapp2-sess',
    same_site: :lax,
    secure: true,
  )

  # Use a real queuing backend for Active Job (and separate queues per environment)
  config.active_job.queue_adapter = ENV.fetch('ENABLE_SHORYUKEN', '1') == '1' ? :shoryuken : :inline
  # config.active_job.queue_name_prefix = "sponsor_app2_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
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

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  config.active_record.cache_versioning = false

  config.x.mailgun.api_key = ENV['MAILGUN_API_KEY']

  config.x.sentry.dsn = ENV['SENTRY_DSN']
end
