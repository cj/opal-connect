module Opal
  module Connect
    module ConnectPlugins
      module Server
        module ConnectClassMethods
          def server_methods
            @server_methods ||= ConnectCache.new
          end

          def server_methods=(methods)
            @server_methods = methods
          end
        end

        module ClassMethods
          def connect_server_methods
            Connect.server_methods[self.name] ||= []
          end

          def __server__(method = false, *args, &block)
            if RUBY_ENGINE == 'opal'
              klass_name = self.name

              if Connect.server_methods[klass_name].include? method
                promise = Promise.new

                payload = {
                  method: method,
                  args: args,
                  klass: klass_name
                }

                HTTP.post(Connect.options[:url], payload: payload) do |response|
                  if response.ok?
                    res = JSON.from_object(`response`)
                    promise.resolve res[:body], response
                  else
                    promise.reject response
                  end
                end

                promise
              else
                raise "#{method} is not a server method"
              end
            else
              method ||= Module.new(&block)

              yield if block_given?

              method.public_instance_methods(false).each do |meth|
                connect_server_methods << meth unless connect_server_methods.include? meth
              end
            end
          end
          alias server __server__
        end

        module InstanceMethods
          def __server__(method, *args)
            self.class.server(method, *args)
          end
          alias server __server__
        end
      end

      register_plugin(:server, Server)
    end
  end
end
