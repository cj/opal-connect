unless RUBY_ENGINE == 'opal'
  require 'rspec'
  require './app/config/boot'
end

require 'opal/connect/rspec'
