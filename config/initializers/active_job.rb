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
