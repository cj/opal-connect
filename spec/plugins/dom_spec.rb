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
            ul do
              li {}
            end
          end
        end
      end
    }

    dom.save!
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
      it 'should append to dom' do
        subject.dom.find('ul').append '<li></li>'
      end
    end
  end
end
