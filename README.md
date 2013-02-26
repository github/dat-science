# Dat Science!

A Ruby library for carefully refactoring critical paths. Science isn't
a feature flipper or an A/B testing tool, it's a pattern that helps
measure and validate large code changes without altering behavior.

## How do I do science?

```ruby
require "dat/science"

include Dat::Science

science "user-permissions" do |experiment|
  experiment.control   { model.check_user(user).valid? }
  experiment.candidate { user.can? :read, model }
end
```

Wrap a `control` block around the code's original behavior, and wrap
`candidate` around the new behavior. The `science` block will return
whatever the `control` block returns, but it does a bunch of stuff
behind the scenes:

* Decides whether or not to run `candidate`,
* Runs `candidate` before `control` 50% of the time,
* Measures the duration of both behaviors,
* Compares the results of both behaviors,
* Swallows any exceptions raised by the candidate behavior, and
* Publishes all this information for tracking and reporting.

## Making Science Useful

(Talk about subclassing `Dat::Science::Experiment` and setting
`Dat::Science.experiment`)

```ruby
require "dat/science"

module FooCorp
  class Experiment < Dat::Science::Experiment
    def enabled?
      # See "Ramping up Experiments" below.
    end

    def publish(name, payload)
      # See "Publishing Results" below.
    end
  end
end
```

```ruby
Dat::Science.experiment = FooCorp::Experiment
```

### Ramping up Experiments

```ruby
def enabled?
  rand(100) < 10
end
```

```ruby
def enabled?
  Flipper[name].enabled?
end
```

### Publishing Results

```ruby
def publish(name, payload)
  FooCorp.instrument "science.#{name}", payload
end
```

```ruby
{
  :candidate => {
    :duration  => 2.5,
    :exception => nil,
    :value     => 42
  },

  :control => {
    :duration  => 25.0,
    :exception => nil,
    :value     => 24
  },

  :first => :control
}
```

#### Adding Context

(using `e.context`)

## Hacking on Science

Be on a Unixy box. Make sure a modern Bundler is available.
`script/test` runs the unit tests. All development dependencies will
be installed automatically if they're not available. Dat science
happens primarily on Ruby 1.9.3 and 1.8.7, but science should be
universal.
