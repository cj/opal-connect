require 'spec/spec_helper'

describe 'components/example' do
  let(:example) { App::Components::Example.new }

  it 'should say cow when #moo is called' do
    expect(example.moo).to eq 'cow'
    expect(example.dom.find('body').text).to eq 'cow'
  end
end
