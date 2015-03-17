require 'spec_helper'

describe RateLimiter do
  let(:app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:stack) { RateLimiter.new(app) }
  let(:wrapper) { Rack::Lint.new(stack) }
  let(:request) { Rack::MockRequest.new(wrapper) }
  let(:response) { request.get('/') }

  context 'when we send a request' do
    it 'should respond successfully' do
      expect(response.status).to eq 200
      expect(response.body).to eq 'Hello world'
    end

    it 'should contain headers' do
      expect(response.headers).to include('X-RateLimit-Limit')
      expect(response.headers['X-RateLimit-Limit']).to eq '60'
    end

    context 'with a different value for X-RateLimit' do
      it 'should contain the proper limit' do
        response.headers['X-RateLimit-Limit'] = '40'
        expect(response.headers['X-RateLimit-Limit']).to eq '40'
      end
    end
  end
end
