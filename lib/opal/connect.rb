require 'opal'
require "opal/connect/version"

if RUBY_ENGINE == 'opal'
  require 'opal/connect/puts'
else
  require 'erb'
  Opal.append_path File.expand_path('../..', __FILE__).untaint
end

require 'base64'

module Opal
  module Connect
    CLIENT_OPTIONS = %w'url plugins' unless RUBY_ENGINE == 'opal'

    class << self
      attr_accessor :pids

      def options
        @_options ||= Connect::ConnectCache.new(
          livereload: false,
          url: '/connect',
          plugins: [],
          javascript: [],
          requires: [],
          setup_blocks: []
        )
      end

      def client_options
        Connect.options.hash.select { |key, _| CLIENT_OPTIONS.include? key.to_s }
      end

      def setup(&block)
        instance_exec(&block) if block_given?

        # make sure we include the default plugins with connect
        options[:plugins].each { |plug| Connect.plugin plug }

        options[:setup_blocks].each { |b| Class.new { include Opal::Connect }.new.instance_exec(&b) }
      end

      def included(klass)
        if RUBY_ENGINE != 'opal'
          file = caller[0][/[^:]*/].sub(Dir.pwd, '')[1..-1]
          files << file unless files.include?(file)
        end

        klass.extend ConnectPlugins::Base::ClassMethods

        Connect.options[:plugins].each { |plug| klass.plugin plug, :included }
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
        unless plugin = @plugins[name]
          unless RUBY_ENGINE == 'opal'
            plugins_path = Connect.options[:plugins_path]

            if plugins_path && File.exists?("#{plugins_path}/#{name}.rb")
              require "#{plugins_path}/#{name}"
            else
              require "opal/connect/plugins/#{name}"
            end

            raise ConnectError, "Plugin #{name} did not register itself correctly in Opal::Connect::ConnectPlugins" unless plugin = @plugins[name]
          end
        end

        plugin
      end

      # Register the given plugin with Opal::Connect, so that it can be loaded using #plugin
      # with a symbol.  Should be used by plugin files. Example:
      #
      #   Opal::Connect::ConnectPlugins.register_plugin(:plugin_name, PluginModule)
      def self.register_plugin(name, mod)
        @plugins[name] = mod
      end

      module Base
        module InstanceMethods
          if RUBY_ENGINE != 'opal'
            def render(method, *options, &block)
              code = Connect.javascript(self, method, *options)
              js   = Opal::Builder.new.build_str(code, '(inline)').to_s

              Connect.write_entry_file(self, method, *options) if Connect.options[:livereload]

              "#{public_send(method, *options, &block)}<script>#{js}</script>"
            end
          end
        end

        module ClassMethods
          def render(method, *args, &block)
            new.render(method, *args, &block)
          end

          def setup(&block)
            if block_given?
              @_setup_block = block
              Connect.options[:setup_blocks] << @_setup_block
            end

            @_setup_block
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
            extend(plugin::ClassMethods)     if defined?(plugin::ClassMethods)

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
            end

            def javascript(klass, method, *opts)
              return unless klass

              js = []
              options[:javascript].uniq.each { |block| js << klass.instance_exec(&block) }

              %{
                Document.ready? do
                  #{js.join(';')}

                  klass = #{klass.class.name}.new

                  if klass.respond_to?(:#{method})
                    klass.__send__(:#{method}, *JSON.parse(Base64.decode64('#{Base64.encode64 opts.to_json}')))
                  end

                  Opal::Connect.start_events unless $connect_events_started
                end
              }
            end

            def write_entry_file(klass = false, method = false, *options)
              path           = "#{Dir.pwd}/.connect/entry.rb"
              files          = Connect.files.uniq.map
              entry          = Connect.options[:entry]
              client_options = Base64.encode64 Connect.client_options.to_json
              entry_path     = "#{File.expand_path File.dirname(__FILE__)}/connect/entry.rb.erb"
              plugins_path   = Connect.options[:plugins_path]
              plugins        = []

              ConnectPlugins.plugins.each do |name, _|
                if plugins_path && File.exist?("#{plugins_path}/#{name}.rb")
                  plugins << "#{plugins_path}/#{name}"
                else
                  plugins << "opal/connect/plugins/#{name}"
                end
              end

              Connect.options[:requires].each { |path| plugins << path }

              code = ::ERB.new(File.read(entry_path)).result(binding)

              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, code)
            end
          end
        end
      end
    end

    extend ConnectPlugins::Base::ClassMethods
    plugin ConnectPlugins::Base
  end
end
