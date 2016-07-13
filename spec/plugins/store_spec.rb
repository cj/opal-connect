require 'spec_helper'

Opal::Connect.plugin :store

class StoreTest
  include Opal::Connect

  setup do
    store.set :foo, 'bar'
  end

  setup do
    store.set :server_foo, 'bar'
  end unless RUBY_ENGINE == 'opal'

  setup do
    store.set :foo, 'bar'
  end
end

describe 'plugin :store' do
  context 'class' do
    it 'should get foo and return bar' do
      expect(StoreTest.store.get :foo).to eq 'bar'
      expect(StoreTest.store.get :server_foo).to eq 'bar'
    end
  end
end
