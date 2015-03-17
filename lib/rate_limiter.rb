require 'rate_limiter/version'

class RateLimiter
  def initialize(app, options = {})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, body = @app.call(env)
     change_xratelimit(headers)
    [status, headers, body]
  end

  def change_xratelimit(headers)
    value = @options[:limit] || '60'
    headers.merge!('X-RateLimit-Limit' => value)
  end
end
