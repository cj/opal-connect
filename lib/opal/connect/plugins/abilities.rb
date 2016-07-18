unless RUBY_ENGINE == 'opal'
  require 'yaml'
  Opal.use_gem 'ability_list'
end

require 'ability_list'

module Opal::Connect
  module ConnectPlugins
    javascript do
      if current_user.respond_to?(:id) && current_user.id
        abilities = Opal::Connect.options[:abilities][:list][current_user.role]
        "$current_user_abilities = Base64.decode64('#{Base64.encode64 abilities.to_json}')"
      else
        "$current_user_abilities = {}"
      end
    end

    module Abilities
      def self.load_dependencies(connect, *args)
        connect.plugin :current_user
      end

      def self.configure(connect, options = false)
        if options
          unless RUBY_ENGINE == 'opal'
            if file = options[:file]
              options[:list] = YAML.load_file file
            end
          end

          connect.options[:abilities] = options
        end
      end

      module InstanceMethods
        def load_abilities(user, scope)
          # make sure the user is logged in
          return unless user.respond_to?(:id) && user.id

          abilities = RUBY_ENGINE == 'opal' \
            ? $current_user_abilities \
            : Opal::Connect.options[:abilities][:list][user.role]

          Abilities.process abilities['can'], :can, scope, user
          Abilities.process abilities['cannot'], :can, scope, user
        end
      end

      def self.process(abilities, type, scope, user)
        (abilities || []).each do |ability|
          obj = get_object(ability['object'])

          if method = ability['method']
            scope.send type, ability['action'].to_sym, obj do |record|
              scope.send(method, record)
            end
          else
            scope.send type, ability['action'].to_sym, obj
          end
        end
      end

      def self.get_object(obj)
        if RUBY_ENGINE == 'opal'
          obj.to_sym
        else
          if obj[0,1] == obj[0,1].upcase
            Object.const_get(obj)
          else
            obj.to_sym
          end
        end
      end
    end

    register_plugin :abilities, Abilities
  end
end
