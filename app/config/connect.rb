require 'opal-connect'

Opal.append_path Dir.pwd

Opal::Connect.setup do
  options[:plugins_path] = 'plugins'
  options[:plugins]      = [ :server, :html, :dom, :events, :scope ]

  options[:hot_reload] = {
    host: 'http://local.sh',
    port: 8080,
  }
end

