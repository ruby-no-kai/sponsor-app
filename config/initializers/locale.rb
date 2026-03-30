# frozen_string_literal: true

require 'rack/contrib/locale'
Rails.application.config.middleware.use Rack::Locale
