class App
  module Components
    class RSpec
      include Opal::Connect

      setup do
        dom.set! html! {
          html do
            head do
              meta charset: 'utf-8'
            end
          end
        }

        dom.find('html').append assets([:js, :connect])
        dom.find('html').append assets([:js, :rspec])

        dom.save!
      end unless RUBY_ENGINE == 'opal'

      def display
        if RUBY_ENGINE == 'opal'
          ::RSpec.configure do |config|
            config.formatter = ::Opal::RSpec::BrowserFormatter
          end

          %x{
            var testsContext = require.context("spec", true, /_spec\.rb$/);
            testsContext.keys().forEach(testsContext);
            Opal.RSpec.$$scope.Core.Runner.$autorun();
          }
        else
          dom
        end
      end

      def iframe
        html! {
          html do
            head do
              meta charset: 'utf-8'
            end

            body do
            end
          end
        }
      end unless RUBY_ENGINE == 'opal'
    end
  end
end
