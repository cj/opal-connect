class IO
  def write(string)
    require 'console'
    $console.log(string)
  end
end

require 'opal/rspec'

if RUBY_ENGINE == 'opal'
  module Opal
    module Connect
      module ConnectPlugins
        module Dom
          module ClassMethods
            def dom(selector = false)
              d        = Opal::Connect::ConnectPlugins::Dom::Instance.new('html')
              selector = d.find('#rspec-iframe').dom.JS.contents
              Instance.new selector, cache, self
            end
          end

          module InstanceMethods
            def dom(selector = false)
              d        = Opal::Connect::ConnectPlugins::Dom::Instance.new('html')
              selector = d.find('#rspec-iframe').dom.JS.contents
              Instance.new selector, cache, self
            end
          end
        end
      end
    end
  end
end

module RSpecHelpers
  include Opal::Connect

  def dom
    Opal::Connect::ConnectPlugins::Dom::Instance.new('html')
  end
end

RSpec.configure do |config|
  config.extend RSpecHelpers
  config.include RSpecHelpers

  if RUBY_ENGINE == 'opal'
    config.before { dom.find('body').append html! { iframe id: 'rspec-iframe' } }
    config.after  { dom.find('#rspec-iframe').remove }
  end
end
