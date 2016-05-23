require_relative 'config/connect'

class App < Roda
  plugin :assets,
    path: '.connect/output',
    css_dir: '',
    js_dir: '',
    group_subdirs: false,
    gzip: true,
    js: {
      connect: [ 'opal.js', 'connect.js' ],
      rspec: 'rspec.js'
    }

  use Rack::LiveReload

  route do |r|
    r.assets

    r.root do
      Components::Example.scope(self).render :display
    end

    r.on "rspec" do
      Opal::Connect.run_rspec
    end
  end
end
