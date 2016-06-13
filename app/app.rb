require_relative 'config/connect'

class App < Roda
  plugin :assets,
    path: '',
    css_dir: '',
    js_dir: '',
    group_subdirs: false,
    gzip: true,
    js_opts: { builder: Opal::Connect.builder },
    js: {
      app: ['node_modules/jquery/dist/jquery.js', '.connect/opal.js', '.connect/connect.js', '.connect/entry.rb'],
      rspec: ['.connect/rspec.js', '.connect/rspec_tests.js']
    }

  # use Rack::LiveReload

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
