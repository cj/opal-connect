require 'spec_helper'

class DomTest
  include Opal::Connect

  setup do
    dom.set! html! {
      html do
        head do
          meta charset: 'utf-8'
        end

        body do
          div do
            ul class: 'list' do
              li "Two\nLines"
              li {}
            end
          end
        end
      end
    }

    dom.find('li:first-child').save! :multiline_html
    dom.find('li:last-child').save! :inline_html, false
    dom.save! :html, false
  end unless RUBY_ENGINE == 'opal'
end

describe 'plugin :dom' do
  context 'ClassMethods' do
    subject { DomTest }

    it { is_expected.to respond_to :dom }
    it { is_expected.to respond_to :cache }
    it { is_expected.to respond_to :html }

    unless RUBY_ENGINE == 'opal'
      it { is_expected.to respond_to :html_file }
    end
  end

  context 'InstanceMethods' do
    subject { DomTest.new }

    it { is_expected.to respond_to :dom }
    it { is_expected.to respond_to :cache }
    it { is_expected.to respond_to :element }

    describe '#dom' do
      let(:dom) { RUBY_ENGINE == 'opal' ? subject.dom.tmpl(:html) : subject.dom }

      it '#append' do
        dom.find('ul').append '<li>appended</li>'
        expect(dom.find('ul li').length).to eq 2
        expect(dom.find('ul li:last-child').text).to eq 'appended'
      end

      it '#prepend' do
        dom.find('ul').prepend '<li>prepended</li>'
        expect(dom.find('ul li').length).to eq 2
        expect(dom.find('ul li:first-child').text).to eq 'prepended'
      end

      it '#remove' do
        dom.find('ul li').remove
        expect(dom.find('ul li').length).to eq 0
      end

      it '#attr' do
        ul = dom.find('ul')
        ul.attr('foo', 'bar')
        ul.attr('number', 1)

        expect(ul.attr('class')).to eq 'list'
        expect(ul.attr('foo')).to eq 'bar'
        expect(ul.attr('number')).to eq '1'
      end

      it 'should allow to use a 1 line html as template' do
        multiline_li = subject.dom.tmpl(:multiline_html)
        multiline_li.find('li').append '<span>works</span>'
        dom.find('ul').append multiline_li
        expect(dom.find('li').length).to eq 2
        expect(dom.find('li span').length).to eq 1

        inline_li = subject.dom.tmpl(:inline_html)
        inline_li.find('li').append '<span>bug here</span>'
        dom.find('ul').append inline_li
        expect(dom.find('li span').length).to eq 2
      end
    end
  end
end
