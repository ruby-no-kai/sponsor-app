source 'https://rubygems.org'
ruby '2.5.1' if ENV['STACK'] || ENV['IS_HEROKU']

gem 'rails', '~> 5.2.1'
gem 'rails-i18n', '~> 5.1'
gem 'rack-contrib'

gem 'pg', '>= 0.18', '< 2.0'
gem 'redis-rails'

gem 'addressable'
gem 'commonmarker'
gem 'aws-sdk-core' # STS
gem 'aws-sdk-s3'
gem 'omniauth'
gem 'omniauth-github'
gem 'octokit'
gem 'hashdiff'

gem 'jbuilder', '~> 2.5'
gem 'haml', '>= 5.0.0'
gem 'webpacker', '>= 4.0.0.pre.3'

gem 'letter_opener_web', git: 'https://github.com/fgrehm/letter_opener_web', ref: 'ab50ad09a2af5350bdca9c079bba73523e64f4cd' # https://github.com/fgrehm/letter_opener_web/pull/83
gem 'rspec-rails'

gem 'revision_plate'

gem 'puma'


# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'

group :development, :test do
  # gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  # gem 'web-console', '>= 3.3.0'
end
