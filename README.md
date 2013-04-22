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

### Controlling comparison

By default the results of the `candidate` and `control` blocks are compared
with `==`. Use `comparator` to do something more fancy:

```ruby
science "loose-comparison" do |e|
  e.control    { "vmg" }
  e.candidate  { "VMG" }
  e.comparator { |a, b| a.downcase == b.downcase }
end
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

#### Keeping it clean

Sometimes the things you're comparing can be huge, and there's no good way
to do science against something simpler. Use a `cleaner` to publish a
simple version of a big nasty object graph:

```ruby
science "huge-results" do |e|
  e.control   { OldAndBusted.huge_results_for query }
  e.candidate { NewHotness.huge_results_for query }
  e.cleaner   { |result| result.count }
end
```

The results of the `control` and `candidate` blocks will be run through the
`cleaner`. You could get the same behavior by calling `count` in the blocks,
but the `cleaner` makes it easier to keep things in sync. The original
`control` result is still returned.

## What do I do with all these results?

Once you've started an experiment and published some results, you'll want to
analyze the mismatches from your experiment.  In `dat-science` you'll find
an analysis toolkit to help understand experiment results.

We designed the analysis tools to be run from your ruby console (`irb` or
`script/console` if you're doing science on a Rails app).  You create an analyzer
and then interactively fetch experiment results and study them to determine the
reason the control method's results differ from the candidate method's results.

### Your very own analyzer

The `Dat::Analysis` base class provides a number of tools for analysis.  Since
the process of retrieving your experiment results depends on how you used
`publish` in your experiment, you'll need to create a subclass of `Dat::Analysis`
which implements methods to handle reading and processing results.

You will need to define `read` and `count` to return the next published experiment
result, and the count of remaining published experiment results, respectively.
You can optionally define `cook` to do any decoding, un-marshalling, or whatever
other pre-processing you desire on the raw experiment result returned by `read`.


``` ruby
require 'dat/analysis'

module MyApp
  # Public: Perform dat analysis on a dat-science experiment.
  #
  # This is a subclass of Dat::Analysis which provides the concrete implementation
  # of the `#read`, `#count`, and `#cook` methods to interact with our Redis data
  # store, and decodes our science mismatch results from JSON.
  class Analysis < Dat::Analysis
    # Public: Read the next available science mismatch result.
    #
    # Returns the next raw science mismatch result from Redis.
    def read
      Redis.rpop "dat-science.#{experiment_name}.results"
    end

    # Public: Get the number of pending science mismatch results.
    #
    # Returns the number of pending science mismatch results from redis.
    def count
      Redis.llen "dat-science.#{experiment_name}.results"
    end

    # Public: "Cook" a raw science mismatch result.
    #
    # raw_result - a raw science mismatch result
    #
    # Returns nil if raw_result is nil.
    # Returns the JSON-parsed raw_result.
    def cook(raw_result)
      return nil unless raw_result
      JSON.parse(raw_result)
    end
  end
end

```

#### Instantiating the analyzer

This analyzer can be used with many experiments, so you'll need to instantiate an
analyzer instance for your current experiment:

``` ruby
irb> a = MyApp::Analysis.new('widget-permissions')
=> #<MyApp::Analysis:0x007fae4a0101f8 ...>
```

### Working with individual results

First, let's look at how you can work with single experiment mismatch results.
The `#result` method (also available as `#current`) will show you the most
recently fetched experiment result.  Before you've fetched any results, this
will be empty:

``` ruby
irb> a.result
=> nil
irb> a.current
=> nil
```

We can use the `#more?` predicate method to see if there are experiment results
pending, and `#count` to see just how many results are available:

``` ruby
irb> a.more?
=> true
irb> a.count
=> 103
```

Let's fetch a result:

``` ruby
irb> a.fetch
=> {"experiment"=>"widget-permissions", "user"=>{ ... } .... }
irb> a.result
=> {"experiment"=>"widget-permissions", "user"=>{ ... } .... }
irb> a.result.keys
=> ["experiment", "user", "timestamp", "candidate", "control", "first"]
irb> a.result['control']
=> {"duration"=>12.307, "exception"=>nil, "value"=>false}
irb> a.result['candidate']
=> {"duration"=>12.366999999999999, "exception"=>nil, "value"=>true}
irb> a.result['first']
=> "control"
irb> a.result['timestamp']
=> "2013-04-20T15:25:48-05:00"
irb> a.result['user']
=> {"login"=>"somed00d", ... }
```

Results will contain entries for the duration (in milliseconds), exceptions,
and values returned by both the candidate and control methods for the experiment;
the time when the result was recorded; whether the candidate or the control method
was run first; and an entry for every object saved via a `context` call during
the experiment.

Note that the `#result` method will continue to return the previously fetched
result, until we overwrite it with another `#fetch`, `#skip`, or `#analyze`
(see below).

#### Skipping results

Sometimes we make changes to the code we're running experiments against, and
sometimes those changes cause experiment results to be out of date -- if we've
fixed a bug we found via science, it's not much point in looking at results
generated while our code still had that bug.  To jump past a batch of results,
use `#skip`, giving it a block to test for the condition we want to skip
past:

``` ruby
irb> a.skip {|r| 5.minutes.ago < Time.parse(a.result['timestamp']) }
=> 43
irb> a.skip {|r| true }
=> nil
```

### Batch analysis of results

After sifting through a handful of results from an experiment, it usually
becomes obvious that a single behavior in our studied code is often responsible
for many results published in an experiment.  If a behavior difference  can be
easily fixed by improving the candidate code, and your production release cycle
is short, then you just update the candidate method and continuing running your
experiment.

It's often the case that the relevant code can't be changed that quickly.
Perhaps the assumptions made when writing the candidate code were wrong in a way
that requires deeper consideration and discussion with your team.  It could be
that the experiment results actually turn up bugs in the implementation of the
control method -- in which case there will likely be even more discussion
needed, and possibly a fairly long cycle to get production behaving properly.

That doesn't mean that analysis can't continue, but it could well be that a
majority of the experimental results to analyze are already examples of already
known behaviors.  In this case, it's useful to be able to identify these results
and skip over them, to find results which can't be accounted for by any
currently known  explanation.

The `#analyze` method, in conjunction with "matcher classes", makes this possible.

### `#analyze`

You can run `#analyze` to automate the fetching of pending results.  If a result
is identifiable by a matcher class, that result will skipped.  This process
continues until either an unidentifiable result is found, or there are no more
results available. When an unidentifiable result is found, a summary of the
identified results is output, and then the first unidentified result is
displayed in detail.

```
irb> a.analyze
..................................................................................................

Summary of identified results:

         StaffFunninessMatcher:     53
          ZOMGIssue5423Matcher:     45
                         TOTAL:     98

First unidentifiable result:

Experiment [widget-permissions]   first:  candidate @ 2013-04-19T18:55:23-05:00
Duration:  control (  0.01) | candidate (  1.36)

Control value:   [false]
Candidate value: [true]

            user => {
                                    id => 1234876
                                 login => "somed00d"
 [...]
                    }
=> 32
```

Note that the number of pending results is returned as the result of the
analysis.


### Matcher classes

The purpose of a matcher class is to identify a behavior which results in
mismatches in your experiment. For example, if permissions for staff users are
not implemented properly by your candidate code, you might create a matcher that
recognizes when the user involved is a staff user.

You create a matcher class by subclassing `Dat::Analysis::Matcher` and writing a
`#match?` method that returns true if the experiment result (available as
`result`) is an example of the behavior we know about:

``` ruby
class StaffFunninessMatcher < Dat::Analysis::Matcher
  # our staff role permissions are just soooo busted
  def match?
    User.find_by_login(result['user']['login']).staff?
  end
end
```

If you create a matcher class in the console, use `#add_matcher` to let your
analyzer know about it:

``` ruby
irb> a.add_matcher StaffFunninessMatcher
Loading matcher class [StaffFunninessMatcher]
=> [StaffFunninessMatcher]
```

Now, when you run `#analyze`, all the results with staff users recorded in the
`user` context will be tallied and skipped.

See "Maintaining a library of matchers and wrappers" below for a more durable
way to let your analyzers keep track of your helper classes.

#### Getting a summary of an identified result

The `#summary` method on the analyzer will return a readable version of the
current result.  This is usually a fairly voluminous output (it's what you saw
at the end of an `#analyze` run above), but if your matcher defines a
`#readable` method, the summary of an identified result can be a readable
string:


``` ruby
class StaffFunninessMatcher < Dat::Analysis::Matcher
  # our staff role permissions are just soooo busted
  def match?
    User.find_by_login(result['user']['login']).staff?
  end

  def readable
    "User [#{result['user']['login']}] is staff (see http://github.com/our/project/issues/123)"
  end
end
```

Which would look like:

``` ruby
irb> a.summary
=> "User [somed00d] is staff (see http://github.com/our/project/issues/123)"
```

### Adding methods to results (wrappers)

For many experiments there is information in the results which is used often
enough that you'll get tired of doing repetitive lookups in the results hash.
When this happens, you can create result wrapper classes for your experiment
which can add methods to every result returned. Simply subclass
`Dat::Analysis::Result` and define the instance methods you want:

``` ruby
class PermissionsWrapper < Dat::Analysis::Result
  def user
    User.find_by_login!(result['user']['login'])
  rescue
    "Could not find user, id=[#{result['actor']['id']}]"
  end

  def permission
    Permission.find_by_handle!(result['permission']['handle'])
  rescue
    "Could not find permission, handle=[#{result['permission']['handle']}]"
  end
  alias_method :perm, :permission
end
```

Then, add the wrapper to your analyzer:

``` ruby
irb> a.add_wrapper(PermissionsWrapper)
=> [PermissionsWrapper]
irb> a.result.user
=> #<User id: 1234876, login: "somed00d", ...>
```

These wrappers can also be used in your matchers classes:

``` ruby
class StaffFunninessMatcher < Dat::Analysis::Matcher
  # our staff role permissions are just soooo busted
  def match?
    result.user.staff?
  end

  def readable
    "User [#{result.user.login}] is staff (see http://github.com/our/project/issues/123)"
  end
end
```

#### Skipping class naming

Inventing new non-conflicting class names for matcher and wrapper classes is a
bit of a pain.  Often we just declare an anonymous class and skip the naming
altogether.  If you do this, you'll probably want to define a readable `.name`
method for your class, so that `#analyze` summaries are readable:

``` ruby
Class.new(Dat::Analysis::Matcher) do
  def self.name
    "Staff Permission Silliness"
  end

  def match?
    result.user.staff?
  end

  def readable
    "User [#{result.user.login}] is staff (see http://github.com/our/project/issues/123)"
  end
end

```

### Maintaining a library of matchers and result wrappers

Being able to add matchers and result wrappers to an analyzer during a console
session is a fast way to iteratively identify problems and work through a batch of
results.  Keeping those matchers around for the next session is usually in order.
Your `Dat::Analysis` subclass can define a `#path` instance method, which points
to the place on the filesystem where your matcher and wrapper classes live.  The
analyzer will look here, in a sub-directory named for your experiment, and load
any ruby files it finds there:

``` ruby
require 'dat/analysis'

module MyApp
  # Public: Perform dat analysis on a dat-science experiment.
  #
  # This is a subclass of Dat::Analysis which provides the concrete implementation
  # of the `#read`, `#count`, and `#cook` methods to interact with our Redis data
  # store, and decodes our science mismatch results from JSON.
  class Analysis < Dat::Analysis
    def path
      '/path/to/dat-science/experiments/'
    end
  end
end
```

In this example, the analyzer for the `widget-permissions` experiment will look
in `/path/to/dat-science/experiments/widget-permissions/` for matcher and
wrapper classes.

## Hacking on science

Be on a Unixy box. Make sure a modern Bundler is available. `script/test` runs
the unit tests. All development dependencies will be installed automatically if
they're not available. Dat science happens primarily on Ruby 1.9.3 and 1.8.7,
but science should be universal.

## Maintainers

[@jbarnette](https://github.com/jbarnette) and [@rick](https://github.com/rick)
