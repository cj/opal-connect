module Opal
  module Connect
    module ConnectPlugins
      entry { "require '#{sprockets[:jquery_path]}'" }

      module Sprockets
        def self.configure(connect, options = {})
          opts = connect.options[:sprockets] ||= {
            debug: false,
            prefix: '/connect/assets',
            maps_prefix: '/connect/__OPAL_SOURCE_MAPS__',
            append_paths: []
          }

          opts.merge! options

          opts[:server] = Opal::Server.new do |s|
            s.append_path '.connect'
            opts[:append_paths].each { |path| s.append_path path }
          end.sprockets

          opts[:maps_app] = Opal::SourceMapServer.new(opts[:server], opts[:maps_prefix])

          opts[:maps_prefix_url] = opts[:maps_prefix][1..-1]
          opts[:prefix_url]      = opts[:prefix][1..-1]

          # Monkeypatch sourcemap header support into sprockets
          ::Opal::Sprockets::SourceMapHeaderPatch.inject!(opts[:maps_prefix])
        end unless RUBY_ENGINE == 'opal'

        module ClassMethods
          def sprockets
            Connect.options[:sprockets]
          end

          def javascript_include_tag(file, options = {})
            ::Opal::Sprockets.javascript_include_tag(file,
              sprockets: sprockets[:server],
              prefix: sprockets[:prefix], debug: options[:debug] || sprockets[:debug]
            )
          end

          def connect_include_tag(options = {})
            javascript_include_tag 'entry', options
          end
        end

        module InstanceMethods
          def sprockets
            @_sprockets ||= Connect.options[:sprockets].dup
          end
        end
      end

      register_plugin(:sprockets, Sprockets)
    end
  end
end
