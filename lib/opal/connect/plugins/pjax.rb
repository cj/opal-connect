module Opal::Connect
  module ConnectPlugins
    module Pjax
      def self.load_dependencies(connect)
        connect.plugin :events
      end

      if RUBY_ENGINE == 'opal'
        `require('expose?$!expose?Pjax!pjax')`
        `require('expose?$!expose?NProgress!nprogress')`
        `require('nprogress/nprogress.css')`

        ConnectSetup = -> do
          on(:document, 'pjax:send')     { `NProgress.start(); NProgress.inc()` }
          on(:document, 'pjax:complete') { `NProgress.done()` }

          $pjax = Native(`new Pjax({elements: 'a', selectors: ['#k-menu', '.container']})`)
        end
      end

      if RUBY_ENGINE == 'opal'
        module InstanceMethods
          def pjax_load(url)
            $pjax.loadUrl(url, $pjax.options.to_n)
          end
        end
      else
        module InstanceMethods
          def render_pjax(method, *options, &block)
            js = Opal::Connect.build Opal::Connect.javascript(self, method, *options)
            content = dom.load! public_send(method, *options, &block)
            content.find('#pjax-inline-script').remove
            content.find('body > div').first.append "<script id='pjax-inline-script'>#{js}</script>"
            content.to_html
          end
        end

        module ClassMethods
          def render_pjax(method, *args, &block)
            new.render_pjax(method, *args, &block)
          end
        end
      end
    end

    register_plugin :pjax, Pjax
  end
end
