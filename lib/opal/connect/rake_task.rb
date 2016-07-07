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
      end

      def initialize_connect
        return unless defined? Opal.append_path

        Opal::Connect.write_entry_file(self)

        code  = Opal::Connect::STUBS.map { |stub| "require '#{stub}'" }.join(";")
        stubs = Opal::Config.stubbed_files.to_a
        Opal::Connect.write_file(:opal, code, Opal::VERSION, stubs)

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
