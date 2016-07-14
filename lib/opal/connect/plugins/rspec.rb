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

            Dir.glob("./#{options[:folder]}/#{options[:glob]}").each do |file|
              rspec_requires << "require '#{file.sub('./', '')}'"
            end

            Opal::Connect.write_file :rspec, %{
              require 'opal/connect/puts'
              require 'opal/rspec'
            }, "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

            File.write "#{Dir.pwd}/.connect/rspec_tests.rb", %{
              RSpec.configure do |config|
                config.formatter = ::Opal::RSpec::BrowserFormatter
                config.formatter = ::RSpec::Core::Formatters::ProgressFormatter
              end
              #{rspec_requires.join(';')}
              RSpec::Core::Runner.autorun
            }

            Dir["#{options[:folder]}/**/*_spec.rb"].each { |file| load file }
            Opal::Connect.setup
            Opal::Connect.write_entry_file(self)

            tmpl = html! {
              html do
                head { meta charset: 'utf-8' }
                body do
                  div Class.new { include Opal::Connect }.instance_exec(&options[:assets])
                  div ::Opal::Sprockets.javascript_include_tag('entry', sprockets: App::Sprockets, prefix: App::Prefix, debug: true)
                  script src: '/connect/assets/rspec.js'
                  div ::Opal::Sprockets.javascript_include_tag('rspec_tests', sprockets: App::Sprockets, prefix: App::Prefix, debug: true)
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
