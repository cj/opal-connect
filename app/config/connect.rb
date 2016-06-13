require 'opal-connect'

Opal::Connect.setup do
  options[:plugins]     = [ :server, :html, :dom, :events ]
  options[:livereload]  = true

  plugin :scope, App.new('')
  plugin :rspec, code: -> { assets([:js, :app]) + assets([:js, :rspec]) }
end

