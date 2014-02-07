def run(opts)
  EM.synchrony do
    server = opts[:server] || :thin
    host = opts[:host] || '0.0.0.0'
    port = opts[:port] || '12137'
    app = opts[:app]

    dispatch = Rack::Builder.app do
      use Rack::FiberPool
      use Rack::Cache,
        metastore:   'memcached://localhost:11211/meta',
        entitystore: 'memcached://localhost:11211/body'

      map Sinatra::Application.assets_prefix do
        run Sinatra::Application.assets
      end

      map "/" do
        run Sinatra::Application
      end
    end

    unless [:thin, :hatetepe, :goliath].include? server
      raise "Need an EM webserver, but #{server} isn't"
    end

    Rack::Server.start({
      app:    dispatch,
      server: server,
      Host:   host,
      Port:   port
    })

    require "ws/main"

    require "integration/pry"
  end
  
#rescue Exception => e
#  puts "*** Reactor stopped, exception raised"
#  $stdin = STDIN
#  binding.pry
end
