unless RUBY_ENGINE == 'opal'
  Opal.use_gem 'scrivener-opal'
end

require 'scrivener'

module Opal
  module Connect
    class Form < ::Scrivener; end

    module ConnectPlugins
      module Form
        FORM_EVENTS = %i`submit keydown keyup change`

        def self.load_dependencies(connect, *args)
          connect.plugin :events
        end

        module InstanceMethods
          def connect_event_instance_variables(_event, name, _selector)
            super

            # we only want to grab form params if we are submitting a form
            return unless FORM_EVENTS.include?(name)

            @params = {}

            # grab all of the form params!
            Native(@this.serialize_array).each do |item|
              @params[item[:name]] = item[:value]
            end
          end
        end
      end

      register_plugin :form, Form
    end
  end
end
