module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        connect.options[:rspec] = { folder: "spec"}.merge options
      end

      module ConnectClassMethods
        def run_rspec
          read, write = IO.pipe

          pid = fork do
            read.close

            options = Opal::Connect.options[:rspec]

            ::Opal.append_path "./#{options[:folder]}"
            $:.unshift "./#{options[:folder]}"

            require 'rspec'
            require 'opal-rspec'
            rspec_requires = []
            version        = "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

            Dir.glob("./#{options[:folder]}/**/*_spec.rb").each { |file| rspec_requires << "require '#{file.sub('./', '')}'" }

            code = %{
              require 'opal/connect/puts'
              require 'opal/rspec'
            }

            Opal::Connect.write_file :rspec, code, version

            File.write "#{Dir.pwd}/.connect/rspec_tests.js", build(%{
              #{rspec_requires.join(';')}
              ::RSpec::Core::Runner.autorun
            })

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
