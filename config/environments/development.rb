require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.x.public_url_host = ENV.fetch('DEFAULT_URL_HOST', 'localhost:3000')

  config.x.asset_file_uploadable.region = ENV['S3_FILES_REGION']
  config.x.asset_file_uploadable.bucket = ENV['S3_FILES_BUCKET']
  config.x.asset_file_uploadable.prefix = ENV['S3_FILES_PREFIX']
  config.x.asset_file_uploadable.role = ENV['S3_FILES_ROLE']

  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = ENV['EAGER_LOAD'] == '1'

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :memory_store

  # see also config/initializers/active_job.rb
  # config.active_job.queue_adapter = :inline

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

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Set localhost to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: config.x.public_url_host, protocol: 'https'}

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Highlight code that triggered redirect in logs.
  config.action_dispatch.verbose_redirect_logs = true

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
  config.x.locale_cookie_name = '__Host-rk-sponsorapp2-hl'

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

  config.x.dev.sponsor_impersonation = true
end
