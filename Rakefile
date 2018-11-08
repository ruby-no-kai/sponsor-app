# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
ENV['NODE_ENV'] = 'production' if ENV['STACK'] # Force NODE_ENV=production during heroku build for yarn integrity check

Rails.application.load_tasks
