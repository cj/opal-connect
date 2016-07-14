require_relative 'config/connect'

class App < Roda
  route do |r|
    r.on Opal::Connect.sprockets[:maps_prefix_url] do
      r.run Opal::Connect.sprockets[:maps_app]
    end

    r.on Opal::Connect.sprockets[:prefix_url] do
      r.run Opal::Connect.sprockets[:server]
    end

    r.root do
      Components::Example.scope(self).render :display
    end

    r.on "rspec" do
      Opal::Connect.run_rspec
    end
  end
end
