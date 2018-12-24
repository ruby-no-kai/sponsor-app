web: bundle exec puma -p $PORT -C config/puma.rb
worker: bundle exec sidekiq -t 30 -c 4 -q default -q mailers
