bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker: bundle exec sidekiq -e $RAILS_ENV -c $SIDEKIQ_WORKERS
