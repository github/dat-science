# Science!

A Ruby library for carefully refactoring critical paths. Science isn't a feature
flipper or an A/B testing tool, it's a pattern that helps measure and validate
large code changes without altering behavior.

## How do I do science?

Let's pretend you're changing the way you handle permissions in a large web app.
Tests can help guide your refactoring, but you really want to compare the
current and new behaviors live, under load.

```ruby
require "dat/science/experiment"

class MyApp::Widget
  def allows?(user)
    experiment = Dat::Science::Experiment.new "widget-permissions" do |e|
      e.control   { model.check_user(user).valid? } # old way
      e.candidate { user.can? :read, model } # new way
    end

    experiment.run
  end
end
```

Wrap a `control` block around the code's original behavior, and wrap `candidate`
around the new behavior. The `science` block will always return whatever the
`control` block returns, but it does a bunch of stuff behind the scenes:

* Decides whether or not to run `candidate`,
* Runs `candidate` before `control` 50% of the time,
* Measures the duration of both behaviors,
* Compares the results of both behaviors,
* Swallows any exceptions raised by the candidate behavior, and
* Publishes all this information for tracking and reporting.

If you'd like a bit less verbosity, `Dat::Science#science` is a little bit of
sugar that instantiates an experiment and automatically calls `run`:

```ruby
require "dat/science"

class MyApp::Widget
  include Dat::Science

  def allows?(user)
    science "widget-permissions" do |e|
      e.control   { model.check_user(user).valid? } # old way
      e.candidate { user.can? :read, model } # new way
    end
  end
end
```

## Making science useful

The examples above will run, but they're not particularly helpful. The
`candidate` block runs every time, and none of the results get
published. Let's fix that by creating an app-specific sublass of
`Dat::Science::Experiment`. This makes it easy to add custom behavior
for enabling/disabling/throttling experiments and publishing results.

```ruby
require "dat/science"

module MyApp
  class Experiment < Dat::Science::Experiment
    def enabled?
      # See "Ramping up experiments" below.
    end

    def publish(name, payload)
      # See "Publishing results" below.
    end
  end
end
```

After creating a subclass, tell `Dat::Science` to instantiate it any time the
`science` helper is called:

```ruby
Dat::Science.experiment = MyApp::Experiment
```

### Ramping up experiments

By default the `candidate` block of an experiment will run 100% of the time.
This is often a really bad idea when testing live. `Experiment#enabled?` can be
overridden to run all candidates, say, 10% of the time:

```ruby
def enabled?
  rand(100) < 10
end
```

Or, even better, use a feature flag library like [Flipper][]. Delegating the
decision makes it easy to define different rules for each experiment, and can
help keep all your entropy concerns in one place.

[Flipper]: https://github.com/jnunemaker/flipper

```ruby
def enabled?
  MyApp.flipper[name].enabled?
end
```

### Publishing results

By default the results of an experiment are discarded. This isn't very useful.
`Experiment#publish` can be overridden to publish results via any
instrumentation mechansim, which makes it easy to graph durations or
matches/mismatches and store results. The only two events published by an
experiment are `match` when the result of the control and candidate behaviors
are the same, and `mismatch` when they aren't.

```ruby
def publish(event, payload)
  MyApp.instrument "science.#{event}", payload
end
```

The published `payload` is a Symbol-keyed Hash:

```ruby
{
  :experiment => "widget-permissions",

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

The `:candidate` and `:control` Hashes have the same keys:

* `:duration` is the execution in ms, expressed as a float.
* `:exception` is a reference to any raised exception or `nil`.
* `:value` is the result of the block.

`:first` is either `:candidate` or `:control`, depending on which block was run
first during the experiment. `:experiment` is the name of the experiment.

#### Adding context

It's often useful to add more information to your results, and
`Experiment#context` makes it easy:

```ruby
science "widget-permissions" do |experiment|
  experiment.context :user => user

  experiment.control   { model.check_user(user).valid? } # old way
  experiment.candidate { user.can? :read, model } # new way
end
```

`context` takes a Symbol-keyed Hash of additional information to publish and
merges it with the default payload.

## Hacking on science

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs
the unit tests. All development dependencies will be installed automatically if
they're not available. Dat science happens primarily on Ruby 1.9.3 and 1.8.7,
but science should be universal.
