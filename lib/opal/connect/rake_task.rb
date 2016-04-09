module Opal
  module Connect
    class RakeTask
      include Rake::DSL if defined? Rake::DSL

      DEFAULT_OPTIONS = { port: 8080, host: '0.0.0.0' }

      def initialize(name = 'webpack', opts = {})
        options = DEFAULT_OPTIONS.merge opts

        namespace name do
          Opal::Connect.setup
          Opal::Config.dynamic_require_severity = 'ignore'

          builder = Opal::Builder.new
          build_str = '`require("expose?$!expose?jQuery!jquery")`; require "opal"; require "opal-jquery"; require "opal/connect"; require "opal-parser";'
          builder.build_str(build_str, '(inline)', { dynamic_require_severity: :ignore })
          File.write "#{Dir.pwd}/.connect/opal.js", builder.to_s

          desc "Start webpack"
          task :run do
            exec({"OPAL_LOAD_PATH" => Opal.paths.join(":")}, "webpack-dev-server --progress -d --host #{options[:host]} --port #{options[:port]} --compress --devtool eval --progress --colors --historyApiFallback true --hot --watch")
          end

          desc "Build webpack"
          task :build do
            exec({
              "OPAL_LOAD_PATH" => Opal.paths.join(":"),
              "RACK_ENV" => 'production'
            }, 'webpack --progress')
          end
        end
      end
    end
  end
end
