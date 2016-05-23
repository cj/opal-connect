require 'opal-rspec'

module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        opts = connect.options[:rspec] = { folder: "#{Dir.pwd}/spec"}.merge options

        unless RUBY_ENGINE == 'opal'
          require 'rspec'
          ::Opal.append_path opts[:folder]
          $:.unshift opts[:folder]
          version     = "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"
          code        = %{
            class IO
              def write(string)
                require 'console'
                $console.log(string)
              end
            end

            require 'opal/rspec'

            %x{
              var testsContext = require.context("spec", true, /_spec\.rb$/);
              testsContext.keys().forEach(testsContext);
              Opal.RSpec.$$scope.Core.Runner.$autorun();
            }
          }

          Opal::Connect.files[:rspec] = [code, version]
        end
      end

      module ConnectClassMethods
        def run_rspec
          read, write = IO.pipe

          pid = fork do
            read.close

            options = Opal::Connect.options[:rspec]

            Dir["#{options[:folder]}/**/*_spec.rb"].each { |file| load file }
            Opal::Connect.setup
            Opal::Connect.write_entry_file(self)

            code = Class.new { include Opal::Connect }.instance_exec(&options[:code])

            string = html! {
              html do
                head do
                  meta charset: 'utf-8'
                end

                body code

              end
            }

            Marshal.dump(string, write)
            exit!(0) # skips exit handlers.
          end

          write.close
          result = read.read
          Process.wait(pid)
          raise "child failed" if result.empty?
          Marshal.load(result)
        end
      end unless RUBY_ENGINE == 'opal'
    end

    register_plugin :rspec, ConnectRSpec
  end
end
