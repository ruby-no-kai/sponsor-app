Rails.application.configure do
  ENV['JOB_ADAPTER'] ||= 'shoryuken' if ENV['ENABLE_SHORYUKEN']
  case ENV['JOB_ADAPTER']
  when 'shoryuken'
    config.active_job.queue_adapter = :shoryuken
  when 'lambdakiq'
    config.active_job.queue_adapter = :lambdakiq
  end
end
