require "bundler/gem_tasks"

$:.unshift './lib'

require './app/config/boot'
require 'opal-connect'
require 'opal/connect/rake_task'

Opal::Connect::RakeTask.new('webpack')

require 'opal/rspec/rake_task'
Opal::RSpec::RakeTask.new('opal:rspec') do |s|
  s.index_path = 'spec/index.html.erb'
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new('ruby:rspec')
