class App
  module Components
    class Example
      include Opal::Connect

      setup do
        dom.set! html! {
          html do
            head do
              meta charset: 'utf-8'
            end

            body do
              div 'Example'
            end
          end
        }

        dom.find('html').append assets([:js, :app])

        dom.save!
      end unless RUBY_ENGINE == 'opal'

      def display
        if RUBY_ENGINE == 'opal'
          dom.find('body').append 'cow'
        end

        dom
      end

      def moo
        dom.find('body').append 'cow'
        'cow'
      end
    end
  end
end
