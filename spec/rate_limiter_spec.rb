require 'spec_helper'

describe RateLimiter do
  let(:app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:wrapper) { Rack::Lint.new(stack) }
  let(:request) { Rack::MockRequest.new(wrapper) }
  let(:response) { request.get('/') }

  context 'when we send a request without options' do
    let(:stack) { RateLimiter.new(app) }

    it 'should respond successfully' do
      expect(response.status).to eq 200
      expect(response.body).to eq 'Hello world'
    end

    it 'should contain headers' do
      expect(response.headers).to include('X-RateLimit-Limit')
      expect(response.headers).to include('X-RateLimit-Remaining')
      expect(response.headers['X-RateLimit-Limit']).to eq '60'
    end
  end

  context 'when we send a request with options' do
    let(:stack) { RateLimiter.new(app, limit: '40') }

    it 'should contain the proper limit' do
      expect(response.headers['X-RateLimit-Limit']).to eq '40'
    end

    context '5 times in total' do
      before { 4.times { request.get('/') } }

      it 'should decrease X-RateLimit-Remaining' do
        expect(response.headers['X-RateLimit-Remaining']).to eq '35'
      end
    end
  end
end
