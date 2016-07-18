# **Opal-Connect** *(OC)*
##### *Makes working with opal even easier!*

## Installation:

```ruby
gem install 'opal-connect'
```

## Usage:

```ruby
class FooBar
  include Opal::Connect
end
```

## Reason for being:

I wanted to write my entire app in a single code base,  I was tired of having one giant app in javascript and another in ruby.  That's when I found [Opal].  I didn't want to over complicate things by creating a framework **(this is not a framework!)** and lock you down to only using Opal Connect.  I also wanted to make Opal Connect as lightweight as possible. Think of this as a layer on-top of Opal that provides an easy way to use it with any preexisting framework, plus it provides a nice plugin architecture inspired by [Roda].


## Getting started:

In this example we'll use [Roda] as our framework of choice.  Roda does come with an [assets plugin](https://github.com/jeremyevans/roda/blob/master/lib/roda/plugins/assets.rb), but [Opal] ships with [Sprockets] so we'll just use that for now.  Plus we make it even easier to use than their [sprockets example](https://github.com/opal/opal/tree/master/examples), using the [OC sprockets plugin](https://github.com/cj/opal-connect/tree/master/lib/opal/connect/plugins/sprockets.rb).

```ruby
require 'roda'
require 'opal-connect' # this will require everything you need, including opal.

class App < Roda
  class OpalComponent
    include Opal::Connect # you can include this in a preexisting class

    def display
      'OpalComponent'
    end
  end

  # We'll set debug to true, that way when we have an error the debug console will use maps and map
  # the javascript error back to the ruby line of code!
  Opal::Connect.plugin :sprockets, debug: true

  route do |r|

    r.on Opal::Connect.sprockets[:maps_prefix_url] do
      r.run Opal::Connect.sprockets[:maps_app]
    end

    r.on Opal::Connect.sprockets[:prefix_url] do
      r.run Opal::Connect.sprockets[:server]
    end
    
    r.root do
      OpalComponent.render :display
    end
  end
```

That's it!  Start the server, visit the root URL and you'll see `OpalComponent` printed out.

## `Opal::Connect` class methods

- [Opal::Connect#options]
- [Opal::Connect#client_options]
- [Opal::Connect#stubbed_files]
- [Opal::Connect#files]
- [Opal::Connect#setup]
- [Opal::Connect#run]
- [Opal::Connect#write_files]
- [Opal::Connect#run_setup]
- [Opal::Connect#included]

## <a name="OpalConnect-class-options"></a>Opal::Connect#options
###### Configuration options for [OC]

| key | default | type | description |
|-----|---------|------|-------------|
| url | /connect| String| The url that will handle connect requests. |
| plugins | [] | Array | Stores an array of all plugins (ones added by [Opal::Connect#plugin]). |
| plugins_loaded | [] | Array | Stores an array of all plugins loaded. |
| entry | [] | Array | Stores all the entry blocks to be run when [Opal::Connect#write_entry_file] is called.
| javascript | [] | Array | Stores all the javascript blocks to execute when [Opal::Connect#render] is called. |
| classes | [] | Array | List of classes using [OC]. |
| run | false | Boolean | whether or not [OC] has been run yet. |
| stubbed_files | [] | Array | List of files to be stubbed by [Opal] using [Opal::Connect#stubbed_files] |


## <a name="OpalConnect-class-client_options"></a>Opal::Connect#client_options
##### Server options that are passed to the client options.

## <a name="OpalConnect-class-stubbed_files"></a>Opal::Connect#stubbed_files
##### Files that are stubbed in opal and will not get passed.

## <a name="OpalConnect-class-files"></a>Opal::Connect#files
##### Files to be compiled with [Opal] by [OC] and output to the `.connect/` folder in the root of your project.

## <a name="OpalConnect-class-setup"></a>Opal::Connect#setup
##### If you find yourself using a lot of plugins/options, you can use this setup block.

```ruby
Opal::Connect.setup do
  plugin :sprockets, debug: false
  plugin :rspec, glob: '**/*_feature_spec.rb'
end
```

## <a name="OpalConnect-class-run"></a>Opal::Connect#run
##### This will trigger [Opal::Connect#write_files], [Opal::Connect#write_entry_file] and [Opal::Connect#run_setups].

## <a name="OpalConnect-class-write_files"></a>Opal::Connect#write_files
##### This will write the opal file and any files contained in [Opal::Connect#files] to the `.connect/` folder.

## <a name="OpalConnect-class-run_setups"></a>Opal::Connect#run_setups
##### This will run all the `Opal::Connect#setup` blocks defined in your classes. **Not to be confused with `Opal::Connect#setup`**

## <a name="OpalConnect-class-included"></a>Opal::Connect#included
##### Called when you `include Opal::Connect` into your class.  It will register it with [OC] and add the plugins for that class to use

[Opal]: https://github.com/opal/opal "Opal"
[Roda]: https://github.com/jeremyevans/roda "Roda"
[Sprockets]: https://github.com/rails/sprockets "Sprockets"
[OC]: https://github.com/cj/opal-connect "OC"

[Opal::Connect#options]: #OpalConnect-class-options
[Opal::Connect#client_options]: #OpalConnect-class-client_options
[Opal::Connect#plugin]: #OpalConnect-class-plugin
[Opal::Connect#write_entry_file]: #OpalConnect-class-write_entry_file
[Opal::Connect#render]: #OpalConnect-class-render
[Opal::Connect#stubbed_files]: #OpalConnect-class-stubbed_files
[Opal::Connect#files]: #OpalConnect-class-files
[Opal::Connect#setup]: #OpalConnect-class-setup
[Opal::Connect#run]: #OpalConnect-class-run
[Opal::Connect#write_files]: #OpalConnect-class-write_files
[Opal::Connect#run_setup]: #OpalConnect-class-run_setup
[Opal::Connect#included]: #OpalConnect-class-included
