if RUBY_ENGINE != 'opal'
  require 'oga'
end

module Opal
  module Connect
    module ConnectPlugins
      # https://github.com/jeremyevans/roda/blob/master/lib/roda.rb#L16
      # A thread safe cache class, offering only #[] and #[]= methods,
      # each protected by a mutex.
      module Dom
        module ClassMethods
          if RUBY_ENGINE != 'opal'
            def html_file(caller)
              path = "#{Dir.pwd}/.connect/html/#{caller[0][/[^:]*/].sub(Dir.pwd, '')[1..-1].sub('.rb', '.html')}"
              FileUtils.mkdir_p(File.dirname(path))
              path
            end
          end

          def html(scope = false, &block)
            if !block_given?
              HTML::DSL.html(&scope).to_html
            else
              HTML::DSL.scope!(scope).html(&block).to_html
            end
          end

          def dom
            if RUBY_ENGINE == 'opal'
              @dom ||= Instance.new('html')
            else
              @dom ||= begin
                file_name = html_file(caller)
                Instance.new false, file_name
              end
            end
          end
        end

        module InstanceMethods
          def dom
            if RUBY_ENGINE == 'opal'
              @dom ||= Instance.new('html')
            else
              @dom ||= begin
                file_name = self.class.html_file(caller)
                Instance.new File.read(file_name), file_name
              end
            end
          end
        end

        class Instance
          attr_reader :selector, :file_name, :dom

          def initialize(selector, file_name = false)
            @selector   = selector
            @file_name  = file_name

            if selector.is_a?(String)
              if RUBY_ENGINE == 'opal'
                @dom = Element[selector]
              else
                # multi-line
                if selector["\n"]
                  @dom = Oga.parse_html(selector)
                else
                  @dom = Oga.parse_html(File.read(file_name))
                  @dom = dom.css(selector) unless selector == 'html'
                end
              end
            else
              @dom = selector
            end
          end

          if RUBY_ENGINE != 'opal'
            def set html
              @dom = Instance.new(html, file_name)
            end
            alias set! set

            def to_html
              if node.respond_to?(:first)
                node.first.to_xml
              else
                node.to_xml
              end
            end

            def to_s
              if dom.respond_to?(:first)
                dom.first.to_xml
              else
                dom.to_xml
              end
            end

            def save template_name = false, remove = true
              if template_name
                File.write("#{file_name}.#{template_name.to_s}.html", self.to_html)
                dom.remove if remove
              else
                File.write(file_name, self.to_html)
              end
            end
            alias save! save

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
              else
                if node.respond_to? :get
                  node.get(key)
                else
                  node.first.get(key)
                end
              end

              self
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
            if RUBY_ENGINE == 'opal'
              puts 'need to implement tmpl'
            else
              fn = "#{file_name}.#{name}.html"
              Instance.new(File.read(fn), fn)
            end
          end

          def append(content, &block)
            # content becomes scope in this case
            content = HTML::DSL.scope!(content).html(&block).to_html if block_given?

            if RUBY_ENGINE == 'opal'
              node.append(content)
            else
              if content.is_a? Dom::Instance
                content = content.children
              else
                content = Oga.parse_html(content).children
              end

              if node.is_a?(Oga::XML::NodeSet)
                node.each { |n| n.children = (n.children + content) }
              else
                node.children = (children + content)
              end
            end

            self
          end

          def prepend(content, &block)
            # content becomes scope in this case
            content = HTML::DSL.scope!(content).html(&block).to_html if block_given?

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
            content = HTML::DSL.scope!(content).html(&block).to_html if block_given?

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

            Instance.new(new_node, file_name)
          end

          def each
            node.each { |n| yield Instance.new(n, file_name) }
          end

          def node
            if self.is_a?(Dom::Instance)
              self.dom
            else
              dom
            end
          end

          # This allows you to use all the oga or opal jquery methods if a
          # global one isn't set
          def method_missing(method, *args, &block)
            if dom.respond_to?(method, true)
              dom.send(method, *args, &block)
            else
              super
            end
          end
        end
      end

      register_plugin(:dom, Dom)
    end
  end
end
