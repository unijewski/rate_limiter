require 'rate_limiter/version'
require 'pry'

class RateLimiter
  def initialize(app, options = { limit: '60' })
    @app = app
    @options = options
    @xratelimit = @options[:limit]
    @remaining_xratelimit = @xratelimit.to_i
    @xratelimit_reset = time_now + 3600
  end

  def call(env)
    reset_xratelimit
    if xratelimit_reached?
      [429, {}, []]
    else
      status, headers, body = @app.call(env)
      define_headers(headers)
      [status, headers, body]
    end
  end

  private

  def define_headers(headers)
    decrease_xratelimit
    headers.merge!('X-RateLimit-Limit' => @xratelimit.to_s)
    headers.merge!('X-RateLimit-Remaining' => @remaining_xratelimit.to_s)
    headers.merge!('X-RateLimit-Reset' => @xratelimit_reset.to_s)
  end

  def decrease_xratelimit
    @remaining_xratelimit -= 1
  end

  def xratelimit_reached?
    @remaining_xratelimit < 0
  end

  def reset_xratelimit
    return unless time_now > @xratelimit_reset
    @xratelimit_reset = time_now + 3600
    @remaining_xratelimit = @xratelimit.to_i
  end

  def time_now
    Time.now.to_i
  end
end
