require 'rate_limiter/version'
require 'rate_limiter/store'

class RateLimiter
  DEFAULT_BLOCK = proc { |env| env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'] }

  def initialize(app, options = {}, &block)
    options = { limit: 60, store: Store.new }.merge(options)
    @app = app
    @options = options
    @total_limit = @options[:limit]
    @reset_limit_at = time_now + 3600
    @store = options[:store]
    @block = block || DEFAULT_BLOCK
  end

  def call(env)
    @id = @block.call(env)

    unless @id.nil?
      find_or_create_client
      reset_rate_limit
      return [429, {}, []] if total_limit_reached?
      decrease_rate_limit
    end

    @app.call(env).tap do |_status, headers, _body|
      add_headers(headers) unless @id.nil?
    end
  end

  private

  def add_headers(headers)
    headers['X-RateLimit-Limit'] = @total_limit.to_s
    headers['X-RateLimit-Remaining'] = @current_client[:remaining_rate_limit].to_s
    headers['X-RateLimit-Reset'] = @current_client[:reset_limit_at].to_s
  end

  def decrease_rate_limit
    @current_client[:remaining_rate_limit] -= 1
    @store.set(@id, @current_client)
  end

  def total_limit_reached?
    @current_client[:remaining_rate_limit] <= 0
  end

  def reset_rate_limit
    return unless time_now > @current_client[:reset_limit_at]
    @current_client[:reset_limit_at] = time_now + 3600
    @current_client[:remaining_rate_limit] = @total_limit
    @store.set(@id, @current_client)
  end

  def time_now
    Time.now.to_i
  end

  def find_or_create_client
    if @store.get(@id).nil?
      client_data = { remaining_rate_limit: @total_limit, reset_limit_at: @reset_limit_at }
      @store.set(@id, client_data)
    end
    @current_client = @store.get(@id)
  end
end
