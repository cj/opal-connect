require "bundler/gem_tasks"

$:.unshift './lib'

require './app/config/boot'
require 'opal-connect'
require 'opal/connect/rake_task'

Opal::Connect::RakeTask.new('webpack')
