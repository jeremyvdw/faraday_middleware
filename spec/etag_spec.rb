require 'helper'
require 'faraday_middleware/response/etag'
require 'faraday'

# expose a method in Test adapter that should have been public
Faraday::Adapter::Test::Stubs.class_eval { public :new_stub }

describe FaradayMiddleware::Etag do
  CACHE_CONTENT = { [:faraday_etags, "/cached"] => { :body => 'Hello World!' } }
  
  let(:middleware_options) { {:cache => CACHE_CONTENT} }
  
  shared_examples_for 'a successful cached with ETag response' do |status_code|
    [:head, :get].each do |method|
      it "returning the ETag header for a #{method.to_s.upcase} request" do
        connection do |stub|
          stub.new_stub(method, '/cached') { [status_code, { 'Etag' => 'd8e2-5e0b5400' }, ''] }
        end.run_request(method, '/cached', nil, {'If-None-Match' => 'd8e2-5e0b5400'}).tap { |response|
          response.headers['Etag'].should eql('d8e2-5e0b5400')
        }
      end
    end
    
    it "returning the cached body for a GET request" do
      connection do |stub|
        stub.get('/cached') { [status_code, { 'Etag' => 'd8e2-5e0b5400' }, ''] }
      end.get('/cached', nil, {'If-None-Match' => 'd8e2-5e0b5400'}).tap { |response|
        response.body.should eql('Hello World!')
      }
    end
  end
  
  context 'for cached response' do
    it_should_behave_like 'a successful cached with ETag response', 304
  end
  
  private
  
  def connection(options = middleware_options)
    Faraday.new do |c|
      c.use described_class, options
      c.adapter :test do |stub|
        yield(stub) if block_given?
      end
    end
  end
end
