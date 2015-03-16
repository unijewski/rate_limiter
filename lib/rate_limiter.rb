require 'rate_limiter/version'

class RateLimiter
  def initialize(app, options = {})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, body = @app.call(env)
    set_x_ratelimit(headers)
    [status, headers, body]
  end

  def set_x_ratelimit(headers)
    value = @options[:limit] || 60
    headers.merge!('X-RateLimit-Limit' => value)
  end
end
