Sentry.init do  |config|
  config.dsn = ENV['SENTRY_DSN']
  config.background_worker_threads = 0 if ENV['AWS_LAMBDA_FUNCTION_NAME']

  config.traces_sample_rate = 0.25
  config.enable_logs = true
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
end
