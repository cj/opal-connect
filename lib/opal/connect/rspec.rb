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
else
  Opal::Connect.run 'rspec_entry'
end

module RSpecHelpers
  include Opal::Connect::ConnectPlugins::HTML::InstanceMethods

  def rspec_dom
    Opal::Connect::ConnectPlugins::Dom::Instance.new('html')
  end
end

RSpec.configure do |config|
  config.extend RSpecHelpers
  config.include RSpecHelpers
  config.before(:suite) { Opal::Connect.run_setups }

  if RUBY_ENGINE == 'opal'
    config.before { rspec_dom.find('body').append html! { iframe id: 'rspec-iframe' } }
    config.after  { rspec_dom.find('#rspec-iframe').remove }
  end
end
