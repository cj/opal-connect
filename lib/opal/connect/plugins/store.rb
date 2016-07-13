module Opal
  module Connect
    module ConnectPlugins
      javascript do
        "$connect_store = Opal::Connect::ConnectCache.new(JSON.parse Base64.decode64('#{Base64.encode64 Connect.store_opts[:data].to_json}'))"
      end

      module Store
        def self.configure(connect, options = {})
          return unless options

          connect.options[:store] = {
            data: ConnectCache.new
          }.merge options
        end

        module ClassMethods
          def store_opts
            Connect.options[:store]
          end

          def store
            (RUBY_ENGINE == 'opal' ? $connect_store : store_opts[:data])[self.name] ||= ConnectCache.new
          end
        end

        module InstanceMethods
          def store
            @_connect_store ||= ConnectCache.new self.class.store.hash
          end
        end
      end

      register_plugin(:store, Store)
    end
  end
end
