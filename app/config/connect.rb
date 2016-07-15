require 'opal-connect'

Opal::Connect.setup do
  plugins :server, :html, :dom, :events

  plugin :scope, App.new('')
  plugin :rspec
  plugin :sprockets,
    jquery_path: 'node_modules/jquery/dist/jquery.js',
    debug: true
end
