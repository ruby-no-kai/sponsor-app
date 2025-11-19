Rails.application.configure do
  ENV['JOB_ADAPTER'] ||= 'shoryuken' if ENV['ENABLE_SHORYUKEN']
  case ENV['JOB_ADAPTER']
  when 'shoryuken'
    ActiveJob::Base.queue_adapter = config.active_job.queue_adapter = :shoryuken
  when 'lambdakiq'
    ActiveJob::Base.queue_adapter = config.active_job.queue_adapter = :lambdakiq
  else
    ActiveJob::Base.queue_adapter = config.active_job.queue_adapter = :inline
  end
end

ActiveJob::Base.queue_as ENV['LAMBDAKIQ_QUEUE'] if ENV['LAMBDAKIQ_QUEUE']
ActiveJob::Base.queue_as ENV['SPONSOR_APP_SHORYUKEN_QUEUE'] if ENV['SPONSOR_APP_SHORYUKEN_QUEUE']
