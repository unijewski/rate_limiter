require 'spec_helper'

describe RateLimiter do
  let(:info) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:wrapper) { Rack::Lint.new(app) }

  context 'when we send a request without options' do
    let(:app) { RateLimiter.new(info) }

    before { get('/') }

    it 'should respond successfully' do
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq 'Hello world'
    end

    it 'should contain headers' do
      expect(last_response.headers).to include('X-RateLimit-Limit')
      expect(last_response.headers).to include('X-RateLimit-Remaining')
      expect(last_response.headers['X-RateLimit-Limit']).to eq '60'
    end
  end

  context 'when we send requests with options' do
    let(:app) { RateLimiter.new(info, limit: '10') }

    before { get('/') }

    it 'should contain the proper limit' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq '10'
    end

    context '5 times in total' do
      before { 4.times { get('/') } }

      it 'should decrease X-RateLimit-Remaining' do
        expect(last_response.headers['X-RateLimit-Remaining']).to eq '5'
      end
    end

    context 'the limit was reached' do
      before { 12.times { get('/') } }

      it 'should get the 429 status code' do
        expect(last_response.status).to eq 429
        expect(app).not_to receive(:call)
      end
    end
  end
end
