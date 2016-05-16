require 'opal-connect'

Opal::Connect.setup do
  options[:plugins]     = [ :server, :html, :dom, :events, :scope ]
  options[:livereload]  = true
end

