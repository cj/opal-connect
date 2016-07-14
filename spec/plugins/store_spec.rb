require 'spec/spec_helper'

Opal::Connect.plugin :store

class StoreFooTest
  include Opal::Connect

  setup do
    store.set :foo, 'bar'
  end

  setup do
    store.set :server_foo, 'bar'
  end unless RUBY_ENGINE == 'opal'
end

class StoreBarTest
  include Opal::Connect

  setup do
    store.set :foo, 'foo'
  end
end

describe 'plugin :store' do
  context 'class' do
    it 'should get foo and return bar' do
      expect(StoreFooTest.store.get :foo).to eq 'bar'
      expect(StoreFooTest.store.get :server_foo).to eq 'bar'
      expect(StoreBarTest.store.get :foo).not_to eq 'bar'
      expect(StoreBarTest.store.get :server_foo).to eq nil
    end
  end

  context 'instance' do
    let(:store_foo) { StoreFooTest.new }

    it 'should containt the class stored vars' do
      expect(store_foo.store[:foo]).to eq 'bar'
      expect(store_foo.store.get :server_foo).to eq 'bar'
    end

    it "shouldn't update the class store" do
      store_foo.store.set :bar, 'foo'
      expect(StoreFooTest.store[:bar]).to eq nil
    end
  end
end
