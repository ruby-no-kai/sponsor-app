Sentry.init do  |config|
  config.dsn = ENV['SENTRY_DSN']
  config.background_worker_threads = 0 if ENV['AWS_LAMBDA_FUNCTION_NAME']
end
