module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        require 'opal-rspec'

        unless RUBY_ENGINE == 'opal'
          require 'rspec'

          ::Opal.append_path options[:folder] || "#{Dir.pwd}/spec"
          connect_dir = "#{File.dirname(__FILE__)}/../"
          code        = File.read(File.expand_path('rspec.rb', connect_dir))
          version     = "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

          Opal::Connect.files[:rspec] = [code, version]
        end

        connect.options[:rspec] = options
      end

      module ConnectClassMethods
        def run_rspec
          Opal::Connect.write_entry_file
          code         = Opal::Connect.options[:rspec][:code]
          opal_code    = Opal::Connect.read_file 'output/opal.js'
          connect_code = Opal::Connect.read_file 'output/connect.js'
          rspec_code   = Opal::Connect.read_file('output/rspec.js')
            .gsub(/<script>/, '\<script\>')
            .gsub(/<\/script>/, '\</script\>')

          code = Class.new { include Opal::Connect }.instance_exec(&code) if code

          html! {
            html do
              head do
                meta charset: 'utf-8'
              end

              body {}

              script opal_code, type: "text/javascript"
              script connect_code, type: "text/javascript"
              div code if code
              script rspec_code, type: "text/javascript"
            end
          }
        end
      end
    end

    register_plugin :rspec, ConnectRSpec
  end
end
