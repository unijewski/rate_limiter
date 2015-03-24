require 'rate_limiter/version'
require 'rate_limiter/store'
require 'pry'

class RateLimiter
  DEFAULT_BLOCK = proc { |env| env['REMOTE_ADDR'] }

  def initialize(app, options = {}, &block)
    options = { limit: 60, store: Store.new }.merge(options)
    @app = app
    @options = options
    @rate_limit = @options[:limit]
    @reset_limit_at = time_now + 3600
    @clients = options[:store]
    @block = block || DEFAULT_BLOCK
  end

  def call(env)
    @id = @block.call(env)
    find_or_create_client
    reset_rate_limit
    return [429, {}, []] if rate_limit_reached?
    status, headers, body = @app.call(env)
    return [status, headers, body] if @id.nil?
    define_headers(headers)
    [status, headers, body]
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
    if @clients.get(@id).nil?
      @clients.set(@id,
      {
        rate_limit: @rate_limit,
        remaining_rate_limit: @rate_limit,
        reset_limit_at: @reset_limit_at
      })
    end
    @current_client = @clients.get(@id)
  end
end
