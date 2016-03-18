module Opal
  module Connect
    module ConnectPlugins
      module Events
        module ClassMethods
          if RUBY_ENGINE == 'opal'
            def connect_events
              $connect_events[self] ||= []
            end
          end

          def connect_el el = false
            @connect_el = el if el
            @connect_el
          end

          def connect_on(name, selector = nil, method = nil, &handler)
            if RUBY_ENGINE == 'opal'
              handler = proc { |evt| __send__(method, evt) } if method
              event = [name, selector, handler]
              connect_events << event unless connect_events.include? event
            end
          end
        end

        if RUBY_ENGINE == 'opal'
          module ConnectClassMethods
            $connect_events = ConnectCache.new unless $connect_events

            def events_teardown
              if $connect_events
                $connect_events.each do |klass, events|
                  el = Dom[klass.connect_el || 'body']

                  events.each do |event|
                    name, selector, wrapper = event
                    el.off(name, selector, &wrapper)
                  end
                end

                $connect_events = ConnectCache.new
              end
            end

            def events_start
              $connect_events.each do |klass, events|
                el = Dom[klass.connect_el || 'body']

                events.map! do |event|
                  name, selector, handler = event
                  wrapper = proc do |e|
                    # gives you access to this, like jquery
                    @this = Dom[e.target]
                    instance_exec(e, &handler)
                  end

                  el.on(name, selector, &wrapper)
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
