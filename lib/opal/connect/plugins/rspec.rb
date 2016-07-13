module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        connect.options[:rspec] = {
          folder: "spec",
          port: 3333,
          host: 'localhost',
          path: 'rspec',
          config: './config.ru'
        }.merge options
      end

      module ConnectClassMethods
        def run_rspec
          read, write = IO.pipe

          pid = fork do
            read.close

            rspec_requires = []
            options        = Opal::Connect.options[:rspec]

            Opal.append_path "./#{options[:folder]}"
            $:.unshift "./#{options[:folder]}"

            require 'rspec'
            require 'opal-rspec'

            Dir.glob("./#{options[:folder]}/**/*_spec.rb").each do |file|
              rspec_requires << "require '#{file.sub('./', '')}'"
            end

            Opal::Connect.write_file :rspec, %{
              require 'opal/connect/puts'
              require 'opal/rspec'
            }, "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

            File.write "#{Dir.pwd}/.connect/rspec_tests.js", build(%{
              #{rspec_requires.join(';')}
              RSpec.configure do |config|
                config.formatter = ::Opal::RSpec::BrowserFormatter
                config.formatter = ::RSpec::Core::Formatters::ProgressFormatter
              end
              RSpec::Core::Runner.autorun
            })

            Dir["#{options[:folder]}/**/*_spec.rb"].each { |file| load file }
            Opal::Connect.setup
            Opal::Connect.write_entry_file(self)

            string = html! {
              html do
                head { meta charset: 'utf-8' }
                body Class.new {
                  include Opal::Connect
                }.instance_exec(&options[:code])
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
