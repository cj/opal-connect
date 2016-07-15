require 'spec_helper'

Opal::Connect.plugin :store

class StoreFooTest
  include Opal::Connect

  def self.setup
    store[:array] ||= []
    store[:array] << 'one'
    store.set :foo, 'bar'
    if RUBY_ENGINE == 'opal'
      store[:client_foo] = 'bar'
    else
      store.set :server_foo, 'bar'
    end
  end

end

class StoreBarTest
  include Opal::Connect

  def self.setup
    store.set :foo, 'foo'
  end
end

describe 'plugin :store' do
  context 'class' do
    it 'should get foo and return bar' do
      if RUBY_ENGINE == 'opal'
        expect(StoreFooTest.store[:client_foo]).to eq 'bar'
        expect(StoreFooTest.store[:array].length).to eq 2
      else
        expect(StoreFooTest.store[:client_foo]).to eq nil
        expect(StoreFooTest.store[:array].length).to eq 1
      end
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
