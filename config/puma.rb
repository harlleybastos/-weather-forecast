threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Workers share forecasts through Redis.
worker_count = Integer(ENV.fetch("WEB_CONCURRENCY", 0))
if worker_count > 0
  workers worker_count
  preload_app!
end

port ENV.fetch("PORT", 3000)
plugin :tmp_restart
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
