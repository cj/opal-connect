require "opal/connect/version"
require 'base64'

if RUBY_ENGINE == 'opal'
  module Kernel
    def puts(*args)
      require 'console'
      $console.log(*args)
    end
  end
else
  Opal.append_path File.expand_path('../..', __FILE__).untaint
end

module Opal
  module Connect
    CLIENT_OPTIONS = %w'url plugins' unless RUBY_ENGINE == 'opal'

    class << self
      attr_accessor :pids

      def run(scope, server, opts = {})
        if ENV['CUTEST']
          scope.run server
        else
          @pids   = []
          options = { env: { RACK_ENV: ENV['RACK_ENV']} }.merge opts

          envs = options[:env].to_a.map { |k, v| "#{k}=#{v}" }.join ' '
          pids << {
            name: 'webpack',
            pid: Process.spawn("#{envs} bundle exec rake webpack:run")
          }

          if (cutest = Connect.options[:cutest]) && pids.select { |pid| pid[:name] == 'cutest' }.empty?
            envs = cutest[:env].to_a.map { |k, v| "#{k}=#{v}" }.join ' '
            pids << {
              name: 'cutest',
              pid: Process.spawn("#{envs} #{cutest[:run]}")
            }
          end

          scope.send(:at_exit) { quit_pids }

          scope.run server
        end
      rescue
        quit_pids
      end

      def quit_pids
        begin
          while pids.length > 0
            Process.kill "QUIT", (pids.shift)[:pid]
          end
        rescue
          # process already dead
        end
      end

      def options
        @options ||= Connect::ConnectCache.new(
          hot_reload: false,
          url: '/connect',
          plugins: [],
          setup_ran: false,
          javascript: [],
          plugin_requires: []
        )
      end

      def options=(opts)
        @options = opts
      end if RUBY_ENGINE == 'opal'

      def setup(&block)
        instance_exec(&block) if block_given?

        # make sure we include the default plugins with connect
        options[:plugins].each { |plug| Connect.plugin plug }

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

        Connect.options[:plugins].each { |plug| klass.plugin plug, :included }
      end

      # We need to wripte a plugins.rb file which has all the plugins required
      # by the server, so that the client can require them.  Opal doesn't handle
      # dynamically generated imports, which is the reason we make a single file.
      def write_plugins_file
        path = "#{Dir.pwd}/.connect/plugins.rb"
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w+') do |file|
          ConnectPlugins.plugins.each do |name, _|
            plugins_path = Connect.options[:plugins_path]

            if plugins_path && File.exist?("#{plugins_path}/#{name}.rb")
              path = "require('#{plugins_path}/#{name}')"
              path = "`#{path}`" if Connect.options[:hot_reload]
              file.puts path
            else
              file.puts "require('opal/connect/plugins/#{name}')"
            end
          end

          Connect.options[:plugin_requires].each do |require_path|
            path = "require('#{require_path}')"
            path = "`#{path}`" if Connect.options[:hot_reload]
            file.puts path
          end
        end
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
            plugins_path = Connect.options[:plugins_path]

            if plugins_path && File.exists?("#{plugins_path}/#{name}.rb")
              require "#{plugins_path}/#{name}"
            else
              require "opal/connect/plugins/#{name}"
            end

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
            def render(method, *options, &block)
              if hl = Connect.options[:hot_reload]
                hl = {} unless hl.is_a? Hash
                hl = { host: 'http://localhost', port: 8080 }.merge hl

                Connect.write_entry_file(self, method, *options)

                "#{public_send(method, *options, &block)}<script src='#{hl[:host]}:#{hl[:port]}/main.js'></script>"
              else
                js = Connect.build Connect.javascript(self, method, *options)

                "#{public_send(method, *options, &block)}<script>#{js}</script>"
              end
            end
          end
        end

        module ClassMethods
          def render(method, *args, &block)
            new.render(method, *args, &block)
          end

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
            included = (args.first == :included) ? args.shift : false

            raise ConnectError, "Cannot add a plugin to a frozen Connect class" if RUBY_ENGINE != 'opal' && frozen?
            if plugin.is_a?(Symbol)
              Connect.options[:plugins] << plugin unless Connect.options[:plugins].include? plugin
              plugin = ConnectPlugins.load_plugin(plugin)
            end
            plugin.load_dependencies(self, *args, &block) if !included && plugin.respond_to?(:load_dependencies)
            return unless plugin
            include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
            extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)
            unless included
              Connect.extend(plugin::ConnectClassMethods) if defined?(plugin::ConnectClassMethods)
              Connect.include(plugin::ConnectInstanceMethods) if defined?(plugin::ConnectInstanceMethods)
              Connect.instance_exec(plugin, &plugin::ConnectSetup) if defined?(plugin::ConnectSetup)
              unless RUBY_ENGINE == 'opal'
                Connect.options[:javascript] << plugin::ConnectJavascript if defined?(plugin::ConnectJavascript)
              end
            end
            plugin.configure(self, *args, &block) if !included && plugin.respond_to?(:configure)
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

              js         = []
              javascript = Connect.options[:javascript]

              if javascript.length
                javascript.uniq.each do |block|
                  js << klass.instance_exec(&block)
                end
              end

              %{
                #{js.join(';')}

                Document.ready? do
                  klass = #{klass.class.name}.new

                  if klass.respond_to?(:#{method})
                    klass.__send__(:#{method}, *JSON.parse(Base64.decode64('#{Base64.encode64 options.to_json}')))
                  end

                  Opal::Connect.start_events unless $connect_events_started
                end
              }
            end

            def write_entry_file(klass = false, method = false, *options)
              path = "#{Dir.pwd}/.connect/entry.js"

              required_files = Connect.files.uniq.map do |file|
                !Connect.options[:hot_reload] ? "require('#{file}')" : "`require('#{file}')`"
              end.join(';')

              client_options = Connect.options.hash.select do |key, _|
                CLIENT_OPTIONS.include? key.to_s
              end

              client_options = Base64.encode64 client_options.to_json
              templates      = Base64.encode64 Connect.templates.hash.to_json

              code = "Opal::Connect.options = JSON.parse(Base64.decode64('#{client_options}'));"
              code = "#{code} Opal::Connect.setup;"
              code = "#{code} Opal::Connect.templates = JSON.parse(Base64.decode64('#{templates}'));"
              code  = %{#{code} Opal::Connect.server_methods = JSON.parse(
                Base64.decode64('#{Base64.encode64 Connect.server_methods.to_json}')
              );}
              code = "#{code} #{Connect.options[:entry]}" if Connect.options[:entry]


              if !Connect.options[:hot_reload]
                code = "#{code} #{required_files}"
              else
                code << %{
                  `if (module.hot) {`
                    `module.hot.accept()`

                    if Opal::Connect.respond_to? :teardown_events
                      Opal::Connect.teardown_events
                      connect_events  = $connect_events[Opal::Connect]
                      $connect_events = Opal::Connect::ConnectCache.new

                      if connect_events
                        $connect_events[Opal::Connect] = connect_events
                      end

                      $connect_events_started = false
                    end

                    #{required_files}
                    #{Connect.javascript(klass, method, *options)}
                  `}`
                }
              end

              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, build(code))
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
