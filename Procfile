web: bundle exec puma -C config/puma.rb
resque: env QUEUE=* TERM_CHILD=1 RESQUE_TERM_TIMEOUT=7 bundle exec rake resque:setup resque:work
scheduler: env QUEUE=* TERM_CHILD=1 RESQUE_TERM_TIMEOUT=7 bundle exec rake resque:scheduler
