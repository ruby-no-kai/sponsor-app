ActiveJob::Base.include Lambdakiq::Worker
ActionMailer::MailDeliveryJob.include Lambdakiq::Worker
ActionMailer::MailDeliveryJob.queue_as ENV['LAMBDAKIQ_QUEUE'] if ENV['LAMBDAKIQ_QUEUE']
