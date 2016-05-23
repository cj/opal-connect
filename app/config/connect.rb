require 'opal-connect'

Opal::Connect.setup do
  options[:plugins]     = [ :server, :html, :dom, :events ]
  options[:livereload]  = true

  plugin :scope, App.new('')
  plugin :rspec, code: -> { assets([:js, :connect]) + assets([:js, :rspec]) }
end

