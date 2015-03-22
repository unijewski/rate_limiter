require 'spec_helper'

describe RateLimiter do
  let(:empty_app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:time) { Timecop.freeze(3600).to_i }

  context 'when we send a request' do
    let(:app) { Rack::Lint.new(RateLimiter.new(empty_app)) }

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

  context 'when we send requests and pass options' do
    let(:app) { Rack::Lint.new(RateLimiter.new(empty_app, limit: 10)) }

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
      it 'should get the 429 status code' do
        9.times { get('/') }
        expect(last_response.status).to eq 429
        expect(app).not_to receive(:call)
      end

      context 'but after an hour' do
        before { Timecop.travel(3601) }

        it 'should reset the limit' do
          get('/')
          remaining_rate_limit = last_response.headers['X-RateLimit-Remaining'].to_i
          rate_limit = last_response.headers['X-RateLimit-Limit'].to_i
          expect(remaining_rate_limit).to eq rate_limit - 1
          expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
        end
      end
    end
  end

  context 'when we distinguish requests' do
    context 'and the block is given' do
      let(:app) do
        Rack::Lint.new(RateLimiter.new(empty_app, limit: 10) do |env|
          Rack::Request.new(env).params['api_token']
        end)
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

    context 'and the block is as nil' do
      let(:app) do
        Rack::Lint.new(RateLimiter.new(empty_app, limit: 10) { nil })
      end

      it 'should set remaining limit header to nil' do
        get('/?api_token=token')
        expect(last_response.headers).not_to include('X-RateLimit-Limit')
        expect(last_response.headers).not_to include('X-RateLimit-Remaining')
        expect(last_response.headers).not_to include('X-RateLimit-Reset')
      end
    end

    context 'and the block is not given' do
      let(:app) { Rack::Lint.new(RateLimiter.new(empty_app, limit: 10)) }

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
end
