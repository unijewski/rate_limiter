require 'spec_helper'
require 'pry'

describe RateLimiter do
  let(:app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:stack) { RateLimiter.new(app) }
  let(:request) { Rack::MockRequest.new(stack) }
  let(:response) { request.get('/') }

  context 'when we send a request' do
    it 'should respond successfully' do
      expect(response.status).to eq 200
      expect(response.body).to eq 'Hello world'
    end

    it 'should contain headers' do
      expect(response.headers).to include('X-RateLimit-Limit')
      expect(response.headers['X-RateLimit-Limit']).to eq 60
    end
  end
end
