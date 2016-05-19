require_relative 'config/connect'

class App < Roda
  plugin :assets,
    path: '.connect/output',
    css_dir: '',
    js_dir: '',
    group_subdirs: false,
    gzip: true,
    js: { connect: [ 'opal.js', 'connect.js' ] }

  # use Rack::LiveReload

  route do |r|
    r.assets

    r.root do
      Components::Example.scope(self).render :display
    end
  end
end
