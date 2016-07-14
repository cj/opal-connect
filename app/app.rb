require_relative 'config/connect'

class App < Roda
  opal = Opal::Server.new do |s|
    s.append_path '.connect'
    s.main = 'entry'
  end

  Sprockets   = opal.sprockets
  Prefix      = '/connect/assets'
  maps_prefix = '/__OPAL_SOURCE_MAPS__'
  maps_app    = Opal::SourceMapServer.new(Sprockets, maps_prefix)

  # Monkeypatch sourcemap header support into sprockets
  ::Opal::Sprockets::SourceMapHeaderPatch.inject!(maps_prefix)

  plugin :assets,
    path: '',
    css_dir: '',
    js_dir: '',
    group_subdirs: false,
    gzip: true,
    js_opts: { builder: Opal::Connect.builder },
    js: ['node_modules/jquery/dist/jquery.js']

  route do |r|
    r.assets

    r.on maps_prefix[1..-1] do
      r.run maps_app
    end

    r.on Prefix[1..-1] do
      r.run Sprockets
    end

    r.root do
      Components::Example.scope(self).render :display
    end

    r.on "rspec" do
      Opal::Connect.run_rspec
    end
  end
end
