module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        require 'opal-rspec'

        unless RUBY_ENGINE == 'opal'
          require 'rspec'

          ::Opal.append_path options[:folder] || "#{Dir.pwd}/spec"
          connect_dir = "#{File.dirname(__FILE__)}/../"
          code        = %{
            class IO
              def write(string)
                require 'console'
                $console.log(string)
              end
            end

            require 'opal/rspec'
          }
          File.read(File.expand_path('rspec.rb', connect_dir))
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

          rspec = Opal::Connect.build(%{
            require 'spec/plugins/dom_spec'
            `Opal.RSpec.$$scope.Core.Runner.$autorun()`
          })

          code = Class.new { include Opal::Connect }.instance_exec(&code) if code

          html! {
            html do
              head { meta charset: 'utf-8' }
              body {}

              script opal_code, type: "text/javascript"
              script connect_code, type: "text/javascript"
              div code if code
              script rspec_code, type: "text/javascript"
              script rspec, type: "text/javascript"
            end
          }
        end
      end
    end

    register_plugin :rspec, ConnectRSpec
  end
end
