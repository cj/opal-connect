module Opal
  module Connect
    class RakeTask
      include Rake::DSL if defined? Rake::DSL

      def initialize(name = 'webpack', opts = {})
        namespace name do
          desc "Start webpack"
          task :run do
            envs = initialize_connect
            exec(envs, 'webpack --progress --watch')
          end

          desc "Build webpack"
          task :build do
            envs = initialize_connect
            exec(envs, 'webpack --progress')
          end
        end

        namespace 'rspec' do
          desc "RSpec Connect Tests"
          task :connect do
            begin
              path    = File.expand_path('../../../../phantom.js', __FILE__)
              options = Opal::Connect.options[:rspec]
              @url    = "http://#{options[:host]}:#{options[:port]}/#{options[:path]}"

              server = Thread.new do
                Thread.current.abort_on_exception = true
                Rack::Server.start(
                  config: options[:config],
                  Host: options[:host],
                  Port: options[:port],
                  AccessLog: []
                )
              end

              wait_for_server

              `#{options[:phantomjs_bin] || 'phantomjs'} #{path} #{@url}`
            ensure
              server.kill
            end
          end
        end
      end

      def wait_for_server
        # avoid retryable dependency
        tries = 0
        up = false
        uri =  URI.parse @url

        while tries < 4 && !up
          tries += 1
          sleep 0.5
          begin
            # Using TCPSocket, not net/http open because executing the HTTP GET / will incur a decent delay just to check if the server is up
            # in order to better communicate to the user what is going on, save the actual HTTP request for the phantom/node run
            # the only objective here is to see if the Rack server has started
            socket = TCPSocket.new uri.hostname, uri.port
            up = true
            socket.close
          rescue Errno::ECONNREFUSED
            # server not up yet
          end
        end
      end

      def initialize_connect
        return unless defined? Opal.append_path

        ENV.to_h.merge({
          BUNDLE_BIN: true,
          CONNECT_STUBS: "#{Opal::Connect.stubbed_files.join(',')},opal-connect,opal-jquery,opal-rspec",
          OPAL_LOAD_PATH: Opal.paths.join(":"),
          OPAL_USE_BUNDLER: true
        }).inject({}) { |env, (k, v)| env[k.to_s] = v.to_s; env }
      end
    end
  end
end
