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
gem 'omniauth'
gem 'omniauth-github'
gem 'octokit'
gem 'jwt'
gem 'hashdiff'
gem 'rqrcode'
gem 'faraday'
gem 'faraday_middleware'

gem 'nokogiri'
gem 'rexml' # letter-opener

gem 'shoryuken'

gem 'jbuilder', '~> 2.9'
gem 'haml'
gem 'simpacker'

gem 'premailer-rails'

gem 'revision_plate'
gem "sentry-ruby"
gem "sentry-rails"
gem 'rails_semantic_logger'

gem 'puma'

group :production do
  gem 'barnes'
end

group :development, :test do
  # gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
  gem 'listen'

  gem 'letter_opener_web', git: 'https://github.com/fgrehm/letter_opener_web', ref: 'ab50ad09a2af5350bdca9c079bba73523e64f4cd' # https://github.com/fgrehm/letter_opener_web/pull/83
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  # gem 'web-console', '>= 3.3.0'
end
