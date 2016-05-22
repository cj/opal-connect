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

  # use Rack::LiveReload

  route do |r|
    r.assets

    r.root do
      Components::Example.scope(self).render :display
    end

    r.on "rspec" do
      r.on "iframe" do
        Components::RSpec.scope(self).iframe
      end

      Components::RSpec.scope(self).render :display
    end
  end
end
