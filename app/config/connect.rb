require 'opal-connect'

Opal::Connect.setup do
  options[:plugins]     = [ :server, :html, :dom, :events ]
  options[:livereload]  = true

  plugin :scope, App.new('')
  plugin :rspec, assets: -> { assets(:js) }
end

