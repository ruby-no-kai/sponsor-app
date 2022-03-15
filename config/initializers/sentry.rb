if ENV['SENTRY_DSN']
  Sentry.init do  |config|
    config.dsn = ENV.fetch('SENTRY_DSN')
  end
end
