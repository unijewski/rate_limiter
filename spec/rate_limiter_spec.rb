require 'spec_helper'

describe RateLimiter do
  let(:empty_app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:app) { Rack::Lint.new(rate_limiter) }
  let(:time) { Timecop.freeze(3600).to_i }

  context 'when we make multiple requests' do
    let(:rate_limiter) { RateLimiter.new(empty_app) }

    it 'should decrease the remaining rate limit' do
      get('/')
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '59'
      2.times { get('/') }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '57'
      3.times { get('/') }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '54'
    end
  end

  context 'when the middleware does not have any specified options' do
    let(:rate_limiter) { RateLimiter.new(empty_app) }

    before { get('/') }

    it 'should respond successfully' do
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq 'Hello world'
    end

    it 'should contain the rate limiting headers' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq '60'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '59'
      expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
    end
  end

  context 'when the middleware has given limit as an option' do
    let(:rate_limiter) { RateLimiter.new(empty_app, limit: 10) }

    before { 2.times { get('/') } }

    it 'should contain the rate limiting headers' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq '10'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '8'
      expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
    end

    it 'should respond successfully 10 times in total' do
      8.times { get('/') }
      expect(last_response.status).to eq 200
    end

    context 'and the limit was reached' do
      before { 9.times { get('/') } }

      it 'should get the 429 status code' do
        expect(last_response.status).to eq 429
      end

      it 'should not call the "call" method' do
        expect(empty_app).not_to receive(:call)
        get('/')
      end

      context 'but after an hour' do
        before { Timecop.travel(3601) }

        it 'should reset the limit' do
          get('/')
          expect(last_response.headers['X-RateLimit-Remaining']).to eq '9'
          expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
        end
      end
    end
  end

  describe 'Client detection' do
    context 'when the block is given' do
      let(:rate_limiter) do
        RateLimiter.new(empty_app, limit: 10) do |env|
          Rack::Request.new(env).params['api_token']
        end
      end

      it 'should set the rate limiting headers for each of requests' do
        get('/?api_token=token')
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '9'
        2.times { get('/?api_token=token2') }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '8'
        5.times { get('/?api_token=token3') }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '5'
      end
    end

    context 'when the block returns nil' do
      let(:rate_limiter) do
        RateLimiter.new(empty_app, limit: 10) { nil }
      end

      it 'should set remaining limit header to nil' do
        get('/?api_token=token')
        expect(last_response.headers).not_to include('X-RateLimit-Limit')
        expect(last_response.headers).not_to include('X-RateLimit-Remaining')
        expect(last_response.headers).not_to include('X-RateLimit-Reset')
      end
    end

    context 'when the block is not given' do
      let(:rate_limiter) { RateLimiter.new(empty_app, limit: 10) }

      it 'should set a proper remaining limit for each of them' do
        get('/', {}, 'REMOTE_ADDR' => '10.0.0.1')
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '9'
        2.times { get('/', {}, 'REMOTE_ADDR' => '10.0.0.2') }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '8'
        3.times { get('/', {}, 'REMOTE_ADDR' => '10.0.0.3') }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '7'
      end
    end
  end

  describe 'Custom store' do
    let(:store) { Store.new }
    let(:hash) { { remaining_rate_limit: 30, reset_limit_at: time + 1000 } }
    let(:rate_limiter) { RateLimiter.new(empty_app, store: store) }

    context 'when we call the store' do
      before do
        expect(store).to receive(:get).at_least(:once).with('10.0.0.1').and_return(hash)
        get('/', {}, 'REMOTE_ADDR' => '10.0.0.1')
      end

      it 'should set and get proper values' do
        expect(store.get('10.0.0.1')).to eq(hash)
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '29'
        expect(last_response.headers['X-RateLimit-Reset']).to eq((time + 1000).to_s)
      end
    end
  end
end
