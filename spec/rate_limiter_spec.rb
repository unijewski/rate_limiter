require 'spec_helper'

describe RateLimiter do
  let(:app) { proc { ['200', { 'Content-Type' => 'text/html' }, ['Hello world']] } }

  it 'should respond successfully' do
    get '/'
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq 'Hello world'
  end
end
