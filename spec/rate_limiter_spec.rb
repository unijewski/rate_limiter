require 'spec_helper'

describe RateLimiter do
  let(:info) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }
  let(:wrapper) { Rack::Lint.new(app) }
  let(:time) { Timecop.freeze(3600).to_i }

  context 'when we send a request without options' do
    let(:app) { RateLimiter.new(info) }

    before { get('/') }

    it 'should respond successfully' do
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq 'Hello world'
    end

    it 'should contain the proper headers' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq '60'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '59'
      expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
    end
  end

  context 'when we send requests with options' do
    let(:app) { RateLimiter.new(info, limit: '10') }

    before { 2.times { get('/') } }

    it 'should contain the proper headers' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq '10'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq '8'
      expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
    end

    context 'and the limit was reached' do
      before { 12.times { get('/') } }

      it 'should get the 429 status code' do
        expect(last_response.status).to eq 429
        expect(app).not_to receive(:call)
      end

      context 'but after an hour' do
        before do
          Timecop.travel(3601)
          get('/')
        end

        it 'should reset the limit' do
          expect(last_response.headers['X-RateLimit-Reset']).to eq time.to_s
        end
      end
    end
  end
end
