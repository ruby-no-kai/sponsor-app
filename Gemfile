# frozen_string_literal: true

source 'https://rubygems.org'

gem 'rails', '~> 8.1.0'
gem 'rails-i18n', '~> 8.0'
gem 'rack-contrib'

gem 'pg', '>= 0.18', '< 2.0'
gem 'connection_pool'

gem 'addressable'
gem 'commonmarker'
gem 'aws-sdk-core' # STS
gem 'aws-sdk-s3'
gem 'aws-sdk-sqs'
gem 'aws-sdk-ssm'
gem 'omniauth'
gem 'omniauth-github'
gem 'octokit'
gem 'jwt'
gem 'hashdiff'
gem 'httpx'

gem 'nokogiri', require: false
gem 'rexml', require: false # letter-opener
gem 'jsonnet', require: false

gem 'shoryuken'
gem 'lambdakiq'

gem 'google-protobuf'
gem 'sponsor_app-proto', path: 'gen/proto/ruby'
gem 'connect_rpc_rails', git: 'https://github.com/ivry-inc/connect_rpc_rails.git', ref: '85c44368d8ec764e3f06966bd7038323af79eb47'
gem 'protobufable', git: 'https://github.com/sorah/protobufable.git', ref: '3e143adcb76aa5db5b7b4269479356e1c5ddcd5e'
gem 'protovalidate', '0.1.0.beta3'

gem 'alba'
gem 'jbuilder', '~> 2.9'
gem 'haml'
gem 'vite_rails'

gem 'premailer-rails'

gem 'revision_plate'
gem "sentry-ruby"
gem "sentry-rails"
gem 'rails_semantic_logger'

gem 'puma', require: false
gem 'aws_lambda_ric', require: false
gem 'apigatewayv2_rack'

gem 'open3', require: false

gem 'bootsnap', require: false

group :production do
end

group :development, :test do
  # gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
  gem 'listen'

  gem 'letter_opener_web'
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'webmock', require: false

  gem "rubocop", require: false
  gem "rubocop-shopify", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-factory_bot", require: false

  gem "sorbet", require: false
  gem "tapioca", require: false
end

group :development do
  gem 'openssl'
  # gem 'web-console', '>= 3.3.0'
end
