$:.unshift Dir.pwd
$:.unshift './lib'

require 'bundler'
Bundler.setup :default, ENV.fetch('RACK_ENV') { 'development' }

require 'roda'
require 'rack/unreloader'
require 'rack-livereload'

class App < Roda; end

Unreloader = Rack::Unreloader.new(subclasses: %w'Roda Roda::RodaPlugins Opal::Connect Opal::Connect::CLIENT_OPTIONS'){App}

Unreloader.require './lib/opal/connect.rb'
Unreloader.require 'app/config/connect'
Unreloader.require 'app'
Unreloader.require 'app/components/**/*.rb'

Opal::Connect.setup
