if ENV['SENTRY_DSN']
  Sentry.init do |config|
    config.dsn = env['SENTRY_DSN']
  end
end
