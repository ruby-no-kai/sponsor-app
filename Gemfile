source 'https://rubygems.org'
ruby '~> 3.0.3' if ENV['STACK'] || ENV['IS_HEROKU']

gem 'rails', '~> 6.1.0'
gem 'rails-i18n', '~> 6.0'
gem 'rack-contrib'

gem 'pg', '>= 0.18', '< 2.0'
gem 'connection_pool'

gem 'addressable'
gem 'commonmarker'
gem 'aws-sdk-core' # STS
gem 'aws-sdk-s3'
gem 'omniauth', '< 2'
gem 'omniauth-github'
gem 'octokit'
gem 'jwt'
gem 'hashdiff'
gem 'rqrcode'
gem 'faraday'
gem 'faraday_middleware'

gem 'nokogiri'
gem 'rexml' # letter-opener

gem 'sidekiq'

gem 'jbuilder', '~> 2.9'
gem 'haml'
gem 'simpacker'

gem 'premailer-rails'

gem 'letter_opener_web', git: 'https://github.com/fgrehm/letter_opener_web', ref: 'ab50ad09a2af5350bdca9c079bba73523e64f4cd' # https://github.com/fgrehm/letter_opener_web/pull/83
gem 'rspec-rails'

gem 'revision_plate'
gem "sentry-ruby"
gem "sentry-sidekiq"
gem "sentry-rails"

gem 'puma'

group :production do
  gem 'barnes'
end

# Redis cache store
gem 'redis', '~> 4.0'

group :development, :test do
  # gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'listen'
end

group :development do
  # gem 'web-console', '>= 3.3.0'
end
