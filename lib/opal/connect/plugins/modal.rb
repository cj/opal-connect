module Opal::Connect
  module ConnectPlugins
    module Modal
      if RUBY_ENGINE == 'opal'
        # `require('expose?RModal!rmodal/dist/rmodal.min.js')`
        # `require('rmodal/dist/rmodal.css')`
        # `require('rmodal/dist/rmodal-no-bootstrap.css')`

        module InstanceMethods
          def modal(msg = '', options = {})
            style = (options[:style] || {}).map { |k, v| "#{k}: #{v}" }.join(';')

            dom.find('body').append do
              div id: 'modal', class: "modal #{options[:class]}" do
                div class: 'modal-dialog', style: style do
                  div class: 'modal-content' do
                    if header = options[:header]
                      div header, class: 'modal-header'
                    end
                    div msg, class: 'modal-body'

                    div class: 'modal-footer' do
                      if btn = options[:button]
                        button btn, class: 'close btn btn-primary'
                      end
                      button 'Close', class: 'close btn btn'
                    end
                  end
                end
              end
            end

            modal_content = dom.find('#modal .modal-content')
            modal = Native `new RModal(document.getElementById('modal'), {})`
            modal.open

            modal_content.find('.close.btn').on :click do
              modal.close
              dom.find('#modal').remove
            end

            # remove the modal if they click on the background
            dom.find('#modal').on(:click) do
              unless modal_content.is(':hover')
                modal.close
                dom.find('#modal').remove
              end
            end

            modal
          end
        end
      end
    end

    register_plugin :modal, Modal
  end
end
