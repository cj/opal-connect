require 'opal'
require 'base64'
require "opal/connect/version"

if RUBY_ENGINE == 'opal'
  require 'opal/connect/puts'
else
  require 'oga'
  require 'opal/patch'
  Opal.append_path File.expand_path('../..', __FILE__).untaint
end

require 'opal-jquery'

module Opal
  module Connect
    CLIENT_OPTIONS = %w'url plugins'
    STUBS          = %w'opal native promise console base64 json'

    class << self
      attr_accessor :pids

      def options
        @_options ||= Connect::ConnectCache.new(
          url:            '/connect',
          plugins:        [],
          plugins_loaded: [],
          entry:          [],
          javascript:     [],
          requires:       [],
          setup_blocks:   {},
        )
      end

      def client_options
        Connect.options.hash.select { |key, _| CLIENT_OPTIONS.include? key.to_s }
      end

      def stubbed_files
        STUBS.concat(Opal::Config.stubbed_files.to_a)
      end

      def files
        @_files ||= { connect: ['require "opal-connect"', Connect::VERSION] }
      end

      def setup(&block)
        if RUBY_ENGINE != 'opal' && block_given?
          Opal.append_path Dir.pwd unless RUBY_ENGINE == 'opal'

          instance_exec(&block)

          # make sure we include the default plugins with connect
          options[:plugins].each do |plug|
            unless options[:plugins_loaded].include? plug
              options[:plugins_loaded] << plug
              Connect.plugin(plug)
            end
          end
        end

        unless block_given?
          unless RUBY_ENGINE == 'opal'
            write_entry_file

            opal_code  = Opal::Connect::STUBS.map { |stub| "require '#{stub}'" }.join(";")
            opal_stubs = Opal::Config.stubbed_files.to_a
            Opal::Connect.write_file(:opal, opal_code, Opal::VERSION, opal_stubs)

            Connect.files.each { |name, (code, version, stubs)| write_file name, code, version, stubs }
          end

          options[:setup_blocks].each do |klass, blocks|
            blocks.each { |b| klass.instance_exec(&b) }
          end

          options[:setup_blocks] = {}
        end
      end

      def included(klass)
        if RUBY_ENGINE != 'opal'
          file = caller[0][/[^:]*/].sub(Dir.pwd, '')[1..-1]
          included_files << file unless files.include?(file) || file[/^spec/]
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
        hash  = options || {}
        # make a copy of the hash passed so changes don't effect the one passed in.
        @hash = Hash[hash.map{|k,v| [k, (v.is_a?(Hash) ? ConnectCache.new(v) : v)]}]
      end

      # Make getting value from underlying hash thread safe.
      def [](key)
        if RUBY_ENGINE == 'opal'
          @hash[key]
        else
          @mutex.synchronize { @hash[key] }
        end
      end
      alias get []

      # Make setting value in underlying hash thread safe.
      def []=(key, value)
        if RUBY_ENGINE == 'opal'
          @hash[key] = value
        else
          @mutex.synchronize { @hash[key] = value }
        end
      end
      alias set []=

      def to_json
        @mutex.synchronize do
          json_hash = {}

          @hash.each do |k, v|
            json_hash[k] = v.kind_of?(ConnectCache) ? v.hash : v
          end

          json_hash.to_json
        end
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

      def self.javascript(&block)
        Connect.options[:javascript] << block
      end

      def self.entry(&block)
        Connect.options[:entry] << block
      end

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
              %{#{public_send(method, *options, &block)}
                <script>#{ Connect.build Connect.javascript(self, method, *options)}</script>}
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
              (Connect.options[:setup_blocks][self] ||= []) << @_setup_block
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
              Connect.options[:plugins_loaded] << plugin
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
            end

            plugin.configure(Connect, *args, &block) if !included && plugin.respond_to?(:configure)

            nil
          end

          if RUBY_ENGINE != 'opal'
            def included_files
              @_included_files ||= []
            end

            def builder(stubs = false)
              Opal::Builder.new(
                stubs: stubs || Connect.stubbed_files,
                compiler_options: { dynamic_require_severity: :ignore }
              )
            end

            def build(code, stubs = false)
              builder(stubs).build_str(code, '(inline)').to_s
            end

            def javascript(klass, method = false, *opts)
              js = []
              options[:javascript].uniq.each { |block| js << klass.instance_exec(&block) }

              %{
                #{js.join("\n")}

                Document.ready? do
                  klass = #{klass.class.name}.new
                  #{method ? "klass.__send__(:#{method}, *JSON.parse(Base64.decode64('#{Base64.encode64 opts.to_json}'))) if klass.respond_to?(:#{method})" : ''}
                end
              }
            end

            def write_entry_file
              klass          = Class.new { include Opal::Connect }
              path           = "#{Dir.pwd}/.connect"
              files          = Connect.included_files.dup.uniq.map { |file| "require '#{file}'" }.join("\n")
              entry          = []
              client_options = Base64.encode64 Connect.client_options.to_json
              plugins        = plugin_paths.dup.map { |plugin_path| plugin_path = "require '#{plugin_path}'" }.join("\n")

              Connect.options[:entry].uniq.each { |block| entry << klass.instance_exec(&block) }

              entry_code = %{
                require 'opal-connect'
                #{plugins}
                options = JSON.parse(Base64.decode64('#{client_options}'))
                options.each { |key, value| Opal::Connect.options[key] = value }
                #{files}
                # make sure we include the default plugins with connect
                Opal::Connect.options[:plugins].each { |plug| Opal::Connect.plugin plug }
                Opal::Connect.setup
                #{entry.join("\n")}
                #{javascript(klass)}
              }

              FileUtils.mkdir_p(path)
              File.write("#{path}/entry.rb", entry_code)
            end

            def write_file(name, code, current_version, stubs = false)
              path         = "#{Dir.pwd}/.connect"
              version_path = "#{path}/#{name}_version"
              version      = File.exist?(version_path) ? File.read(version_path) : false
              save_path    = "#{path}/#{name}.js"

              FileUtils.mkdir_p(path)

              if !File.exist?(save_path) || !version || (version && version != current_version)
                File.write version_path, current_version
                File.write(save_path, build(code, stubs))
              end
            end

            def read_file(file)
              File.read "#{Dir.pwd}/.connect/#{file}"
            end

            def plugin_paths
              plugins_path   = Connect.options[:plugins_path]
              plugins        = []

              ConnectPlugins.plugins.each do |name, _|
                if plugins_path && File.exist?("#{plugins_path}/#{name}.rb")
                  plugins << "#{plugins_path}/#{name}"
                else
                  plugins << "opal/connect/plugins/#{name}"
                end
              end

              Connect.options[:requires].each { |plugin_path| plugins << plugin_path }

              plugins
            end
          end
        end
      end
    end

    extend ConnectPlugins::Base::ClassMethods
    plugin ConnectPlugins::Base
  end
end
