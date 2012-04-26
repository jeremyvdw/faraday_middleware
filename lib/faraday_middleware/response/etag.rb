require 'faraday'

module FaradayMiddleware
  
  class Etag < Faraday::Middleware
    SAFE_REQUESTS = [:get, :head]
    
    attr_reader :cache
    
    def initialize(app, options = {}, &block)
      super(app)
      @options = options
      
      @cache = @options.fetch(:cache, &block)
    end
    
    def call(env)
      # cache safe requests only
      return @app.call(env) unless SAFE_REQUESTS.include?(env[:method])
      
      cache_key = [ cache_key_prefix, env[:url].path ]
      cached = cache.fetch(cache_key)
      
      if cached
        env[:request_headers]["If-None-Match"] ||= cached[:response_headers]["Etag"]
      end
      
      @app.call(env).on_complete do
        if cached && env[:status] == 304
          env[:body] = cached[:body]
        end
        
        if !cached && env[:response_headers]["Etag"]
          @cache.write(cache_key, env)
        end
      end
    end
    
    def cache_key_prefix
      @options.fetch(:cache_key_prefix, :faraday_etags)
    end
  end
  
end
