module Opal
  module Connect
    module ConnectPlugins
      module Events
        $connect_events = ConnectCache.new if RUBY_ENGINE == 'opal'

        module ClassMethods
          if RUBY_ENGINE == 'opal'
            def connect_events
              $connect_events[self] ||= []
            end
          end

          attr_accessor :events_dom

          def events_dom(selector = false)
            if selector
              @events_dom = selector
            else
              @events_dom
            end
          end

          def on(name, selector = nil, method = nil, &handler)
            if RUBY_ENGINE == 'opal'
              return if $connect_events_started

              if name.to_s != 'document' && events_dom
                selector = "#{events_dom} #{selector}"
              end

              handler = proc { |evt| __send__(method, evt) } if method
              event   = [name, selector, handler]
              connect_events << event unless connect_events.include? event
            end
          end
        end

        if RUBY_ENGINE == 'opal'
          module ConnectClassMethods
            def teardown_events
              $connect_events.each do |klass, events|
                el = dom('html')

                events.each do |event|
                  name, selector, wrapper = event
                  if name.to_s != 'document'
                    el.off(name, selector, &wrapper)
                  else
                    Document.off(selector, &wrapper)
                  end
                end
              end
            end

            def start_events
              $connect_events_started = true
              $connect_events.each do |klass, events|
                el = dom('html')

                events.map! do |event|
                  name, selector, handler = event
                  wrapper = proc do |e|
                    # gives you access to this, like jquery
                    @this = dom(e.current_target)
                    instance_exec(e, &handler)
                  end

                  if name.to_s != 'document'
                    el.on(name, selector, &wrapper)
                  else
                    Document.on(selector, &wrapper)
                  end
                  [name, selector, wrapper]
                end
              end
            end
          end
        end
      end

      register_plugin(:events, Events)
    end
  end
end
