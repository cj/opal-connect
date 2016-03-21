module Opal
  module Connect
    module ConnectPlugins
      module Scope
        module InstanceMethods
          def scope(new_scope = false)
            if new_scope
              @scope = new_scope

              self
            else
              @scope
            end
          end

          def method_missing(method, *args, &block)
            if scope.respond_to?(method, true)
              scope.send(method, *args, &block)
            else
              super
            end
          end
        end

        module ClassMethods
          def scope(scope, *args)
            new(*args).scope(scope)
          end
        end
      end

      register_plugin :scope, Scope
    end
  end
end
