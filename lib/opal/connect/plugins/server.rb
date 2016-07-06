module Opal
  module Connect
    module ConnectPlugins
      module Server
        ConnectJavascript = -> do
          %{Opal::Connect.server_methods = JSON.parse(
            Base64.decode64('#{Base64.encode64 Connect.server_methods.to_json}')
          );}
        end

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

          def server(method = false, *args, &block)
            if RUBY_ENGINE == 'opal'
              self.new.server(method, *args)
            else
              if method
                include method
              else
                method = Module.new(&block)
              end

              yield if block_given?

              method.public_instance_methods(false).each do |meth|
                connect_server_methods << meth unless connect_server_methods.include? meth
              end
            end
          end
        end

        module InstanceMethods
          def server(method, *args)
            if RUBY_ENGINE == 'opal'
              klass_name = self.class.name

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
              send(method, *args)
            end
          end
        end
      end

      register_plugin(:server, Server)
    end
  end
end
