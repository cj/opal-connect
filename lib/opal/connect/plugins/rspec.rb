module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        connect.options[:rspec] = {
          folder: "spec",
          port: 3333,
          host: 'localhost',
          path: 'rspec',
          config: './config.ru',
          glob: '**/*_spec.rb'
        }.merge options

        connect.plugin :sprockets, append_paths: [connect.options[:rspec][:folder]]
      end

      module ConnectClassMethods
        def run_rspec
          read, write = IO.pipe

          pid = fork do
            read.close

            rspec_requires = []
            options        = Opal::Connect.options[:rspec]

            $:.unshift "./#{options[:folder]}"

            require 'rspec'
            require 'opal-rspec'

            Dir.glob("./#{options[:folder]}/#{options[:glob]}").each do |file|
              rspec_requires << "require '#{file.sub('./', '')}'"
            end

            Opal::Connect.write_file :rspec, %{
              require 'opal/connect/puts'
              require 'opal/rspec'
            }, "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

            File.write "#{Dir.pwd}/.connect/rspec_tests.rb", %{
              require 'opal/connect/rspec'

              RSpec.configure do |config|
                config.formatter = ::Opal::RSpec::BrowserFormatter
                config.formatter = ::RSpec::Core::Formatters::ProgressFormatter
              end

              #{rspec_requires.join(';')}

              RSpec::Core::Runner.autorun
            }

            Dir["#{options[:folder]}/**/*_spec.rb"].each { |file| load file }
            Opal::Connect.run
            Opal::Connect.write_entry_file 'rspec_entry'

            tmpl = html! {
              html do
                head { meta charset: 'utf-8' }
                body do
                  div javascript_include_tag 'rspec_entry'
                  div javascript_include_tag 'rspec.js'
                  div javascript_include_tag 'rspec_tests'
                end
              end
            }

            Marshal.dump(tmpl, write)
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
