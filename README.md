# Science!

A Ruby library for carefully refactoring critical paths. Science isn't a feature
flipper or an A/B testing tool, it's a pattern that helps measure and validate
large code changes without altering behavior.

## How do I do science?

Let's pretend you're changing the way you handle permissions in a large web app.
Tests can help guide your refactoring, but you really want to compare the
current and new behaviors live, under load.

```ruby
require "dat/science"

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
around the new behavior. `experiment.run` will always return whatever the
`control` block returns, but it does a bunch of stuff behind the scenes:

* Decides whether or not to run `candidate`,
* Runs `candidate` before `control` 50% of the time,
* Measures the duration of both behaviors,
* Compares the results of both behaviors,
* Swallows any exceptions raised by the candidate behavior, and
* Publishes all this information for tracking and reporting.

If you'd like a bit less verbosity, the `Dat::Science#science` helper
instantiates an experiment and calls `run`:

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
experiment are `:match` when the result of the control and candidate behaviors
are the same, and `:mismatch` when they aren't.

```ruby
def publish(event, payload)
  MyApp.instrument "science.#{event}", payload
end
```

The published `payload` is a Symbol-keyed Hash:

```ruby
{
  :experiment => "widget-permissions",
  :first      => :control,
  :timestamp  => <a-Time-instance>,

  :candidate => {
    :duration  => 2.5,
    :exception => nil,
    :value     => 42
  },

  :control => {
    :duration  => 25.0,
    :exception => nil,
    :value     => 24
  }
}
```

`:experiment` is the name of the experiment. `:first` is either `:candidate` or
`:control`, depending on which block was run first during the experiment.
`:timestamp` is the Time when the experiment started.

The `:candidate` and `:control` Hashes have the same keys:

* `:duration` is the execution in ms, expressed as a float.
* `:exception` is a reference to any raised exception or `nil`.
* `:value` is the result of the block.

#### Adding context

It's often useful to add more information to your results, and
`Experiment#context` makes it easy:

```ruby
science "widget-permissions" do |e|
  e.context :user => user

  e.control   { model.check_user(user).valid? } # old way
  e.candidate { user.can? :read, model } # new way
end
```

`context` takes a Symbol-keyed Hash of additional information to publish and
merges it with the default payload.

#### Transforming results

If the result of science is more verbose than you need, you can use a transform
operation to publish only the research you need. The transformation will
also be used for comparing results. The non-transformed control result will
still be returned.

If the transformation raises an exception, the non-transformed result will be
compared and published.

```ruby
science "widget-loading" do |e|
  e.control   { Widget.scope.scope.all }
  e.candidate { Widget.new_scope.all }
  e.transform { |result| result.map(&:id).sort }
end
```

## Hacking on science

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs
the unit tests. All development dependencies will be installed automatically if
they're not available. Dat science happens primarily on Ruby 1.9.3 and 1.8.7,
but science should be universal.

## Maintainers

[@jbarnette](https://github.com/jbarnette) and [@rick](https://github.com/rick)
