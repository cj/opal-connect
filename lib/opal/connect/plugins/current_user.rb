require 'ostruct'

module Opal
  module Connect
    module ConnectPlugins
      module CurrentUser
        def self.load_dependencies(connect, *args)
          connect.plugin :scope
        end

        def self.configure(connect, options = false)
          if options
            unless RUBY_ENGINE == 'opal'
              Connect::CLIENT_OPTIONS << 'current_user'
              connect.options[:plugin_requires] << options[:class_path]
              require options[:class_path]
            end

            connect.options[:current_user] = options
          end
        end

        ConnectJavascript = -> do
          "$current_user = Base64.decode64('#{Base64.encode64 current_user.to_h.to_json}')"
        end

        module InstanceMethods
          def current_user
            @current_user ||= Object.const_get(Connect.options[:current_user][:class]).new(OpenStruct.new begin
              if RUBY_ENGINE == 'opal'
                $current_user || {}
              else
                scope.instance_exec(&Connect.options[:current_user][:authenticate]) || {}
              end
            end)
          end
        end
      end

      register_plugin :current_user, CurrentUser
    end
  end
end
