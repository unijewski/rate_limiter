require 'rate_limiter/version'
require 'pry'

class RateLimiter
  def initialize(app, options = { limit: 60 })
    @app = app
    @options = options
    @rate_limit = @options[:limit]
    @reset_limit_at = time_now + 3600
    @clients = {}
  end

  def call(env)
    @ip = env['REMOTE_ADDR']
    find_or_create_client
    reset_rate_limit
    if rate_limit_reached?
      [429, {}, []]
    else
      status, headers, body = @app.call(env)
      define_headers(headers)
      [status, headers, body]
    end
  end

  private

  def define_headers(headers)
    decrease_rate_limit
    add_rate_limit_header(headers)
    add_remaining_rate_limit_header(headers)
    add_reset_limit_at_header(headers)
  end

  def decrease_rate_limit
    @current_client[:remaining_rate_limit] -= 1
  end

  def add_rate_limit_header(headers)
    headers['X-RateLimit-Limit'] = @current_client[:rate_limit].to_s
  end

  def add_remaining_rate_limit_header(headers)
    headers['X-RateLimit-Remaining'] = @current_client[:remaining_rate_limit].to_s
  end

  def add_reset_limit_at_header(headers)
    headers['X-RateLimit-Reset'] = @current_client[:reset_limit_at].to_s
  end

  def rate_limit_reached?
    @current_client[:remaining_rate_limit] <= 0
  end

  def reset_rate_limit
    return unless time_now > @current_client[:reset_limit_at]
    @current_client[:reset_limit_at] = time_now + 3600
    @current_client[:remaining_rate_limit] = @rate_limit
  end

  def time_now
    Time.now.to_i
  end

  def find_or_create_client
    if @clients.select { |client| client[@ip] }.empty?
      @clients[@ip] = {
        rate_limit: @rate_limit,
        remaining_rate_limit: @rate_limit,
        reset_limit_at: @reset_limit_at
      }
    end
    @current_client = @clients[@ip]
  end
end
