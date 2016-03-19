require "opal/connect/version"
require 'base64'

if RUBY_ENGINE == 'opal'
  module Kernel
    def puts(*args)
      require 'console'
      $console.log(*args)
    end
  end
end

# Opal corelib is already loaded from CDN
module Opal
  module Connect

    CLIENT_OPTIONS = %w'url plugins' unless RUBY_ENGINE == 'opal'

    class << self
      def options
        @options ||= Connect::ConnectCache.new(
          hot_reload: false,
          url: '/connect',
          plugins: []
        )
      end

      def options=(opts)
        @options = opts
      end if RUBY_ENGINE == 'opal'

      def setup
        yield(options) if block_given?

        # make sure we include the default plugins with connect
        options[:plugins].each { |plug| Connect.plugin plug.to_sym }

        unless RUBY_ENGINE == 'opal'
          write_plugins_file
          write_entry_file
        end
      end

      def included(klass)
        if RUBY_ENGINE != 'opal'
          file = caller[0][/[^:]*/].sub(Dir.pwd, '')[1..-1]
          files << file unless files.include?(file)
        end

        klass.extend ConnectPlugins::Base::ClassMethods

        # include default plugins
        Connect.options[:plugins].each { |plug| klass.plugin plug.to_sym }
      end

      # We need to wripte a plugins.rb file which has all the plugins required
      # by the server, so that the client can require them.  Opal doesn't handle
      # dynamically generated imports, which is the reason we make a single file.
      def write_plugins_file
        path = "#{Dir.pwd}/.connect/plugins.rb"
        FileUtils.mkdir_p(File.dirname(path))

        file = File.open(path, File::RDWR|File::CREAT, 0644)
        file.flock(File::LOCK_EX|File::LOCK_NB)

        ConnectPlugins.plugins.each do |name, _|
          file.puts "require 'opal/connect/plugins/#{name}'"
        end

        file.close
      end
    end

    class ConnectError < StandardError; end

    class ConnectCache
      # Create a new thread safe cache.
      def initialize(options = false)
        @mutex = Mutex.new if RUBY_ENGINE != 'opal'
        @hash = options || {}
      end

      # Make getting value from underlying hash thread safe.
      def [](key)
        if RUBY_ENGINE == 'opal'
          @hash[key]
        else
          @mutex.synchronize { @hash[key] }
        end
      end

      # Make setting value in underlying hash thread safe.
      def []=(key, value)
        if RUBY_ENGINE == 'opal'
          @hash[key] = value
        else
          @mutex.synchronize { @hash[key] = value }
        end
      end

      def to_json
        @mutex.synchronize { @hash.to_json }
      end

      def hash
        if RUBY_ENGINE == 'opal'
          @hash
        else
          @mutex.synchronize { @hash }
        end
      end

      def each
        if RUBY_ENGINE == 'opal'
          @hash.each { |key, value| yield key, value }
        else
          @mutex.synchronize do
            @hash.each { |key, value| yield key, value }
          end
        end
      end
    end

    module ConnectPlugins
      @plugins = ConnectCache.new

      def self.plugins
        @plugins
      end

      def self.load_plugin(name)
        h = @plugins
        unless plugin = h[name]
          unless RUBY_ENGINE == 'opal'
            require "opal/connect/plugins/#{name}"
            raise ConnectError, "Plugin #{name} did not register itself correctly in Roda::RodaPlugins" unless plugin = h[name]
          end
        end
        plugin
      end

      # Register the given plugin with Roda, so that it can be loaded using #plugin
      # with a symbol.  Should be used by plugin files. Example:
      #
      #   Roda::RodaPlugins.register_plugin(:plugin_name, PluginModule)
      def self.register_plugin(name, mod)
        @plugins[name] = mod
      end

      module Base
        module InstanceMethods
          if RUBY_ENGINE != 'opal'
            def to_js(method, *options)
              if hl = Connect.options[:hot_reload]
                hl = {} unless hl.is_a? Hash
                hl = { host: 'http://localhost', port: 8080 }.merge hl

                Connect.write_entry_file(self.class, method, *options)

                "#{__send__(method, *options)}<script src='#{hl[:host]}:#{hl[:port]}/main.js'></script>"
              else
                js = Connect.build Connect.javascript(self.class, method, *options)

                "#{send(method, *options)}<script>#{js}</script>"
              end
            end
          end
        end

        module ClassMethods
          def setup(&block)
            yield
          end

          # Load a new plugin into the current class.  A plugin can be a module
          # which is used directly, or a symbol represented a registered plugin
          # which will be required and then used. Returns nil.
          #
          #   Connect.plugin PluginModule
          #   Connect.plugin :csrf
          def plugin(plugin, *args, &block)
            raise ConnectError, "Cannot add a plugin to a frozen Connect class" if RUBY_ENGINE != 'opal' && frozen?
            plugin = ConnectPlugins.load_plugin(plugin) if plugin.is_a?(Symbol)
            plugin.load_dependencies(self, *args, &block) if plugin.respond_to?(:load_dependencies)
            include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
            extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)
            Connect.extend(plugin::ConnectClassMethods) if defined?(plugin::ConnectClassMethods)
            Connect.include(plugin::ConnectInstanceMethods) if defined?(plugin::ConnectInstanceMethods)
            plugin.configure(self, *args, &block) if plugin.respond_to?(:configure)
            nil
          end

          if RUBY_ENGINE != 'opal'
            def files
              @files ||= []
            end

            def build(code)
              builder = Opal::Builder.new

              builder.build_str(code, '(inline)').to_s
            end

            def javascript(klass, method, *options)
              return unless klass

              %{
                Opal::Connect.server_methods = JSON.parse(
                  Base64.decode64('#{Base64.encode64 Connect.server_methods.to_json}')
                )

                Document.ready? do
                  klass = #{klass.name}.new

                  if klass.respond_to?(:#{method})
                    klass.__send__(:#{method}, *JSON.parse(Base64.decode64('#{Base64.encode64 options.to_json}')))
                  end

                  Opal::Connect.events_start
                end
              }
            end

            def write_entry_file(klass = false, method = false, *options)
              Opal.use_gem 'opal-jquery'

              path = "#{Dir.pwd}/.connect/entry.js"

              required_files = Connect.files.map do |file|
                "`require('#{file}')`"
              end.join(';')

              client_options = Connect.options.hash.select do |key, _|
                CLIENT_OPTIONS.include? key.to_s
              end

              client_options = Base64.encode64 client_options.to_json

              code = "Opal::Connect.options = JSON.parse(Base64.decode64('#{client_options}'));"
              code = "#{code} Opal::Connect.setup;"

              if !Connect.options[:hot_reload]
                code = "#{code} #{required_files}"
              else
                code << %{
                  `if (module.hot) {`
                    `module.hot.accept()`
                    #{required_files}
                    Opal::Connect.events_teardown
                    #{Connect.javascript(klass, method, *options)}
                  `}`
                }
              end

              FileUtils.mkdir_p(File.dirname(path))
              file = File.open(path, File::RDWR|File::CREAT, 0644)
              file.flock(File::LOCK_EX|File::LOCK_NB)
              file.puts build(code)
              file.close
            end
          end
        end
      end
    end

    if RUBY_ENGINE == 'opal'
      require ".connect/plugins"
    end

    extend ConnectPlugins::Base::ClassMethods
    plugin ConnectPlugins::Base
  end
end
