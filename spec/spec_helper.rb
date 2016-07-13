unless RUBY_ENGINE == 'opal'
  file =  "#{Dir.pwd}/.connect/connect.js"
  File.delete(file) if File.exist?(file)
  require 'rspec'
  require './app/config/boot'
end

require 'opal/connect/rspec'
