$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rate_limiter'
require 'rack/test'
require 'timecop'

include Rack::Test::Methods
