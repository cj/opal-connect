module Opal
  module Connect
    class RakeTask
      include Rake::DSL if defined? Rake::DSL

      def initialize(name = 'webpack', opts = {})
        namespace name do
          return unless defined? Opal.append_path

          Opal::Connect.write_entry_file

          Opal.append_path Dir.pwd

          write_opal_file

          envs = ENV.to_h.merge({
            BUNDLE_BIN: true,
            CONNECT_STUBS: "#{Opal::Connect.stubbed_files.join(',')},opal-connect,opal-jquery,opal-rspec",
            OPAL_LOAD_PATH: Opal.paths.join(":"),
            OPAL_USE_BUNDLER: true
          }).inject({}) { |env, (k, v)| env[k.to_s] = v.to_s; env }

          desc "Start webpack"
          task :run do
            exec(envs, 'webpack --progress --watch')
          end

          desc "Build webpack"
          task :build do
            exec(envs, 'webpack --progress')
          end
        end
      end

      def write_opal_file
        file_path    = "#{Dir.pwd}/.connect"
        version_path = "#{file_path}/opal_version"
        version      = File.exist?(version_path) ? File.read(version_path) : false

        if !File.exist?("#{file_path}/opal.js") || !version || (version && version != Opal::VERSION)
          builder   = Opal::Builder.new({ stubs: Opal::Config.stubbed_files.to_a })
          build_str = Opal::Connect::STUBS.map { |stub| "require '#{stub}'" }.join(";")
          builder.build_str(build_str, '(inline)')
          File.write version_path, Opal::VERSION
          File.write "#{file_path}/opal.js", builder.to_s
        end
      end
    end
  end
end
