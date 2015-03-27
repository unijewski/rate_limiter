# RateLimiter

This gem is a Rack middleware working like a filter that can pass the request on to an application and filter the response that is returned. It works with any Rack app. We can determine how many requests we handle within an hour and set a custom store, like [Dalli](https://github.com/mperham/dalli). The middleware is customized and able to distinguish clients that means instead of the IP address it can be based on `api_token` parameter from the request.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rate_limiter', git: 'https://github.com/unijewski/rate_limiter'
```

And then execute:

    $ bundle

## Usage

Rails application using Dalli:
```ruby
Rails.application.configure do |c|
    c.middleware.use RateLimiter, limit: 100, store: Dalli::Client.new(<required options>)
end
```

You may also check how to use the gem with Rails application [here](https://github.com/unijewski/middleware_test_app).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/rate_limiter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
