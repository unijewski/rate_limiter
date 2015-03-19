require 'rate_limiter/version'
require 'pry'

class RateLimiter
  def initialize(app, options = { limit: '60' })
    @app = app
    @options = options
    @xratelimit = @options[:limit]
    @xratelimit_reset = time_now + 3600
    @clients = {}
  end

  def call(env)
    @ip = env['REMOTE_ADDR']
    find_or_create_client
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
    headers.merge!('X-RateLimit-Limit' => @current_client[:xratelimit].to_s)
    headers.merge!('X-RateLimit-Remaining' => @current_client[:remaining_xratelimit].to_s)
    headers.merge!('X-RateLimit-Reset' => @current_client[:xratelimit_reset].to_s)
  end

  def decrease_xratelimit
    @current_client[:remaining_xratelimit] -= 1
  end

  def xratelimit_reached?
    @current_client[:remaining_xratelimit] < 0
  end

  def reset_xratelimit
    return unless time_now > @current_client[:xratelimit_reset]
    @current_client[:xratelimit_reset] = time_now + 3600
    @current_client[:remaining_xratelimit] = @xratelimit.to_i
  end

  def time_now
    Time.now.to_i
  end

  def find_or_create_client
    if @clients.select { |client| client[@ip] }.empty?
      @clients[@ip] = {
        xratelimit: @xratelimit,
        remaining_xratelimit: @xratelimit.to_i,
        xratelimit_reset: @xratelimit_reset
      }
    end
    @current_client = @clients[@ip]
  end
end
