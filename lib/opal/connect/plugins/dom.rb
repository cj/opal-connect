if RUBY_ENGINE == 'opal'
  `require("expose?$!expose?jQuery!jquery/dist/jquery.min.js")`;
else
  require 'oga'
end

require 'opal-jquery'

module Opal
  module Connect
    module ConnectPlugins
      # https://github.com/jeremyevans/roda/blob/master/lib/roda.rb#L16
      # A thread safe cache class, offering only #[] and #[]= methods,
      # each protected by a mutex.
      module Dom
        ConnectJavascript = -> do
          templates = Base64.encode64 Connect.templates.hash.to_json
          "Opal::Connect.templates = JSON.parse(Base64.decode64('#{templates}'));"
        end

        module ConnectClassMethods
          attr_accessor :templates

          def templates
            @templates ||= ConnectCache.new
          end

          if RUBY_ENGINE == 'opal'
            def templates=(tmpls)
              @templates = tmpls
            end
          end
        end

        module ClassMethods
          if RUBY_ENGINE != 'opal'
            def html_file(caller)
              path = "#{Dir.pwd}/.connect/html/#{caller[0][/[^:]*/].sub(Dir.pwd, '')[1..-1].sub('.rb', '.html')}"
              FileUtils.mkdir_p(File.dirname(path))
              path
            end
          end

          def cache
            @cache ||= (Connect.templates[self.name] ||= {})
          end

          def html(scope = false, &block)
            if !block_given?
              HTML::DSL.html(&scope).to_html
            else
              HTML::DSL.scope!(scope).html!(&block).to_html
            end
          end

          def dom(selector = false)
            if RUBY_ENGINE == 'opal'
              selector ||= 'html'
              Instance.new selector, cache, self
            else
              selector ||= false
              @dom ||= Instance.new selector, cache, self
            end
          end
        end

        module InstanceMethods
          def cache
            self.class.cache
          end

          def dom(selector = false)
            if RUBY_ENGINE == 'opal'
              selector ||= 'html'
              Instance.new selector, cache, self
            else
              selector ||= cache[:html]
              @dom ||= Instance.new selector, cache, self
            end
          end
          alias element dom
        end

        class Instance
          attr_reader :selector, :cache, :dom, :scope

          def initialize(selector, cache, scope)
            @selector = selector
            @cache    = cache
            @scope    = scope

            if selector.is_a?(String)
              if RUBY_ENGINE == 'opal'
                @dom = Element[selector]
              else
                # multi-line
                if selector["\n"] || selector['html']
                  @dom = Oga.parse_html(selector)
                else
                  @dom = cache[:html]
                  @dom = dom.css(selector) unless selector == 'html'
                end
              end
            else
              @dom = selector
            end
          end

          alias element dom

          def set html
            @dom = Instance.new(html, cache, scope)
            @dom.save!
            @dom
          end
          alias set! set

          def load html
            Instance.new(html, cache, scope)
          end
          alias load! load

          def save template_name = false, remove = true
            if template_name
              cache[:"#{template_name}"] = self.to_html
              dom.remove if remove
            else
              cache[:html] = self.to_html
            end
          end
          alias save! save

          def to_html
            if RUBY_ENGINE == 'opal'
              node.html
            else
              if node.respond_to?(:first)
                node.first.to_xml
              else
                node.to_xml
              end
            end
          end

          if RUBY_ENGINE == 'opal'
            def on(name, selector = false, &handler)
              if scope.respond_to?(:connect_events_started)
                wrapper = -> (e) do
                  scope.connect_events_started(e, name, selector)
                  scope.instance_exec(e, &handler)
                end

                node.on(name, selector, &wrapper)
              else
                node.on(name, selector, &handler)
              end
            end
          else
            def to_s
              if dom.respond_to?(:first)
                dom.first.to_xml
              else
                dom.to_xml
              end
            end

            def text(content)
              if node.respond_to?(:inner_text)
                node.inner_text = content
              else
                node.each { |n| n.inner_text = content }
              end

              self
            end

            def attr(key, value = false)
              if value
                if node.respond_to? :set
                  node.set(key, value)
                else
                  node.each { |n| n.set(key, value) }
                end

                self
              else
                if node.respond_to? :get
                  node.get(key)
                else
                  node.first.get(key)
                end
              end
            end

            def remove
              if node.respond_to? :remove
                node.remove
              else
                node.each { |n| n.remove }
              end

              self
            end
          end

          def tmpl(name)
            if cached_tmpl = cache[:"#{name}"]
              Instance.new(cached_tmpl, cache, scope)
            else
              puts "There is no template `#{name}`"
            end
          end

          def append(content = false, &block)
            # content becomes scope in this case
            content = HTML::DSL.scope!(content).html!(&block).to_html if block_given?

            if RUBY_ENGINE == 'opal'
              node.append(content)
            else
              if content.is_a? Dom::Instance
                content = content.node.children
              else
                content = Oga.parse_html(content).children
              end

              if node.is_a?(Oga::XML::NodeSet)
                node.each { |n| n.children = (n.children + content) }
              else
                node.children = (node.children + content)
              end
            end

            # self
          end

          def prepend(content = false, &block)
            # content becomes scope in this case
            content = HTML::DSL.scope!(content).html!(&block).to_html if block_given?

            if RUBY_ENGINE == 'opal'
              node.prepend(content)
            else
              if content.is_a? Dom::Instance
                content = content.children
              else
                content = Oga.parse_html(content).children
              end

              if node.is_a?(Oga::XML::NodeSet)
                node.each { |n| n.children = (content + n.children) }
              else
                node.children = (content + children)
              end
            end

            self
          end

          def html(content = false, &block)
            # content becomes scope in this case
            content = HTML::DSL.scope!(content).html!(&block).to_html if block_given?

            if RUBY_ENGINE == 'opal'
              node.html(content)
            else
              if content.is_a? Dom::Instance
                content = content.children
              else
                content = Oga.parse_html(content).children
              end

              if node.is_a?(Oga::XML::NodeSet)
                node.each { |n| n.children = content }
              else
                node.children = content
              end
            end

            self
          end

          def find(selector)
            new_node = if RUBY_ENGINE == 'opal'
              node.find(selector)
            else
              if node.is_a? Oga::XML::NodeSet
                node.first.css(selector)
              else
                node.css(selector)
              end
            end

            Instance.new(new_node, cache, scope)
          end

          def each
            node.each { |n| yield Instance.new(n, cache, scope) }
          end

          def node
            if self.dom.respond_to? :dom
              self.dom.dom
            else
              self.dom
            end
          end

          # This allows you to use all the oga or opal jquery methods if a
          # global one isn't set
          def method_missing(method, *args, &block)
            if RUBY_ENGINE == 'opal' && node.respond_to?(method, true)
              n = node.send(method, *args, &block)
            elsif RUBY_ENGINE != 'opal'
              if node.is_a?(Oga::XML::NodeSet) && node.first.respond_to?(method, true)
                n = node.first.send(method, *args, &block)
              elsif node.respond_to?(method, true)
                n = node.send(method, *args, &block)
              else
                super
              end
            else
              super
            end

            if RUBY_ENGINE == 'opal'
              n.is_a?(Element) ? Instance.new(n, cache, scope) : n
            else
              n.class.name['Oga::'] ? Instance.new(n, cache, scope) : n
            end
          end
        end
      end

      register_plugin(:dom, Dom)
    end
  end
end
