module Opal
  module Connect
    module ConnectPlugins
      module Scope
        def self.configure(connect, options = false)
          return unless options

          connect.options[:scope] = options
        end

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
          def scope(new_scope = false, *args)
            if new_scope
              @_scope = new(*args).scope(new_scope || Connect.options[:scope])
            else
              @_scope ||= Connect.options[:scope]
            end
          end

          def method_missing(method, *args, &block)
            if scope && scope.respond_to?(method, true)
              scope.send(method, *args, &block)
            else
              super
            end
          end
        end
      end

      register_plugin :scope, Scope
    end
  end
end
