# typed: true
# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Sorbet accepts only constant mixins (4002); tapioca's DSL RBI declares these helpers.
  class_eval { include Rails.application.routes.url_helpers }

  def default_url_options
    {host: Rails.application.config.x.public_url_host, protocol: 'https'}
  end
end
