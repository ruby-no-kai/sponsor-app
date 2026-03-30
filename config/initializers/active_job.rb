# frozen_string_literal: true

Rails.application.configure do
  ENV['JOB_ADAPTER'] ||= 'shoryuken' if ENV['ENABLE_SHORYUKEN']
  adapter = case ENV['JOB_ADAPTER']
  when 'shoryuken'
    :shoryuken
  when 'lambdakiq'
    :lambdakiq
  else
    :inline
  end
  ActiveJob::Base.queue_adapter = config.active_job.queue_adapter = adapter
end

ActiveJob::Base.queue_as ENV['LAMBDAKIQ_QUEUE'] if ENV['LAMBDAKIQ_QUEUE']
ActiveJob::Base.queue_as ENV['SPONSOR_APP_SHORYUKEN_QUEUE'] if ENV['SPONSOR_APP_SHORYUKEN_QUEUE']
