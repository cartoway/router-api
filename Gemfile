source 'https://rubygems.org'
ruby '>= 3'

gem 'puma'
gem 'rack'
gem 'rack-cors'
gem 'rack-server-pages'
gem 'rake'

gem 'grape'
gem 'grape-entity'
gem 'grape_logging'
gem 'grape-swagger'
gem 'grape-swagger-entity'

gem 'actionpack'
gem 'activesupport'
gem 'addressable'
gem 'border_patrol'
gem 'i18n'
gem 'rack-contrib'
gem 'rest-client'

gem 'ai4r'

gem 'sentry-ruby'

group :test do
  gem 'fakeredis'
  gem 'minitest'
  gem 'minitest-focus'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'byebug'
  gem 'rubocop-policy', github: 'cartoway/rubocop-policy'
end

gem 'dotenv'
gem 'flexible_polyline'
gem 'polylines'

group :development, :production do
  gem 'redis', '< 5' # redis-store is buggy with redis 5 https://github.com/redis-store/redis-store/issues/358
end

group :production do
  gem 'redis-activesupport'
  gem 'redis-store'
end
