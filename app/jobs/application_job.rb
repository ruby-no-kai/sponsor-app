class ApplicationJob < ActiveJob::Base
  queue_as ENV['SPONSOR_APP_SHORYUKEN_QUEUE'] if ENV['SPONSOR_APP_SHORYUKEN_QUEUE']

  include Rails.application.routes.url_helpers

  def default_url_options
    {host: Rails.application.config.x.public_url_host, protocol: 'https'}
  end
end
