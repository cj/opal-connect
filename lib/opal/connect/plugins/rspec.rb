module Opal::Connect
  module ConnectPlugins
    module ConnectRSpec
      def self.configure(connect, options = {})
        unless RUBY_ENGINE == 'opal'
          require 'rspec'
          require 'opal-rspec'

          ::Opal.append_path options[:path] || "#{Dir.pwd}/spec"
          connect_dir = "#{File.dirname(__FILE__)}/../"
          code        = File.read(File.expand_path('rspec.rb', connect_dir))
          version     = "#{::RSpec::Version::STRING}#{Opal::RSpec::VERSION}"

          Opal::Connect.files[:rspec] = [code, version]
        end

        connect.options[:rspec] = options
      end
    end

    register_plugin :rspec, ConnectRSpec
  end
end
