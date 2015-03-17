require 'rate_limiter/version'
require 'pry'

class RateLimiter
  def initialize(app, options = {})
    @app = app
    @options = options
    xratelimit = @options[:limit] || 60
    @xratelimit = xratelimit.to_i
    @remaining_xratelimit = @xratelimit
  end

  def call(env)
    status, headers, body = @app.call(env)
    if xratelimit_reached?
      [429, {}, []]
    else
      define_headers(headers)
      [status, headers, body]
    end
  end

  private

  def define_headers(headers)
    decrease_xratelimit
    headers.merge!('X-RateLimit-Limit' => @xratelimit.to_s)
    headers.merge!('X-RateLimit-Remaining' => @remaining_xratelimit.to_s)
  end

  def decrease_xratelimit
    @remaining_xratelimit -= 1
  end

  def xratelimit_reached?
    @remaining_xratelimit < 0
  end
end
