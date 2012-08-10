WhenAUser
=========

[WhenAUser.com](http://whenauser.com) is a rules engine that reacts to things users do or experience in your software, and makes things happen in 3rd party SaaS APIs -- without your having to write any code. Rather than implementing the most rapidly evolving parts of your application's business logic in code, your team can use the WhenAUser web app to specify "when", "how", and "who", with rules like these:

* when a user gets a validation error twice for the same form, send an email to Frank
* when a premium customer hasn't logged in for a month, flag them in Highrise
* when a user gets a 500 response, create a ticket in Zendesk
* when a user invites ten friends, add them to the "well-connected" segment in MailChimp

This gem contains Rack middleware that automatically generates two event streams, one for exceptions and the other for pageviews, that can be used to trigger rules in WhenAUser. You can (and probably should) also send more specific events manually.

Setup
-----

In your Gemfile:

    gem 'whenauser'

###For Ruby on Rails

You should create two incoming channels (event streams) in WhenAUser, and configure their tokens in `config/whenauser.rb` (the available options are explained below). You may want to create additional channels to use in other environments, eg for staging.

    token 'CHANNEL_TOKEN'          # default channel (for user-centric events)
    middleware :pageviews          # automatically generate events for requests/pageviews
    middleware :exceptions do      # automatically generate events for exceptions
      token 'ERROR_CHANNEL_TOKEN'  # separate channel for error-centric events
    end
    
###As general-purpose Rack middleware, with or without Rails

    config.middleware.insert 0, 'WhenAUser::Rack', :token => 'CHANNEL_TOKEN'
    config.middleware.insert_after 'WhenAUser::Rack', 'WhenAUser::Pageviews'
    config.middleware.use 'WhenAUser::Exceptions', :token => 'ERROR_CHANNEL_TOKEN'

Using girl_friday for asynchronous communication and persistence
-----------------

By default this gem sends a batch of events to the WhenAUser service synchronously, at the end of each request to your application. This means that each request to your app will be slowed down by the time it takes to do that communication. While this is fine for development or for low-volume sites, for those who wish to avoid this delay WhenAUser supports the use of the [girl_friday](https://github.com/mperham/girl_friday) gem, which you can enable in your whenauser.rb file:

    queue WhenAUser::GirlFridayQueue

Using the GirlFridayQueue also ensures that events are not lost should the WhenAUser service be temporarily unavailable.

You can also pass options to girl_friday. To avoid losing events when your app server instances restart, you can tell girl_friday to use Redis. In order to use the Redis backend, you must use the [connection_pool](https://github.com/mperham/connection_pool) gem to share a set of Redis connections with other threads and the GirlFriday queue. If you are not already using Redis in your application, add

    gem 'connection_pool'
    gem 'redis'

to your Gemfile, and add something like this to `config/whenauser.rb`:

    require 'connection_pool'
    
    redis_pool = ConnectionPool.new(:size => 5, :timeout => 5) { ::Redis.new }
    queue WhenAUser::GirlFridayQueue, 
      :store => GirlFriday::Store::Redis, :store_config => { :pool => redis_pool }

See the [girl_friday wiki](https://github.com/mperham/girl_friday/wiki) for more information on how to use girl_friday.

Options
-------

WhenAUser::Rack accepts these options:

* `token` -- the token for a WhenAUser channel
* `webhook_url` -- defaults to 'http://whenauser.com/events'
* `middleware` -- takes the symbol for a middleware and a block, configuring it
* `queue` -- takes the class used for queuing (default: WhenAUser::MemoryQueue), and an optional hash
* `custom_data` -- this proc is passed env, and should return a hash to be merged into every event

The `exceptions` middleware accepts these options:

* `token` -- the token for a WhenAUser error channel
* `ignore_exceptions` -- an array of exception class names, defaults to ['ActiveRecord::RecordNotFound', 'AbstractController::ActionNotFound', 'ActionController::RoutingError']
* `ignore_crawlers` -- an array of strings to match against the user agent, includes a number of webcrawlers by default
* `ignore_if` -- this proc is passed env and an exception; if it returns true, the exception is not reported to WhenAUser
* `custom_data` -- this proc is passed env, and should return a hash to be merged into each automatically generated exception event

The `pageviews` middleware accepts these options:

* `ignore_crawlers` -- an array of strings to match against the user agent, includes a number of webcrawlers by default
* `ignore_if` -- this proc is passed env; if it returns true, the pageview is not reported to WhenAUser
* `custom_data` -- this proc is passed env, and should return a hash to be merged into each automatically generated event

The WhenAUser::Pageviews middleware uses the same token as WhenAUser::Rack.

Here's an example of how to skip sending any pageview events for all requests to the SillyController:

    middleware :pageviews do
      ignore_if lambda { |env| env['action_controller.instance'].is_a? SillyController }
    end

Or if you want to skip sending pageview events for requests from pingdom.com:

    middleware :pageviews do
      ignore_crawlers WhenAUser.default_ignored_crawlers + ['Pingdom.com_bot']
    end

Sending other events
--------------------

To manually send an event when a user upgrades to a "premium" account:

    WhenAUser.send_event(
      :_actor => current_user.unique_id,
      :_timestamp => Time.now.to_f,
      :_domain => 'account',
      :_name => 'upgrade',
      :user_email => current_user.email,
      :plan => 'premium' )

Use Cases
---------

### Example rule triggers

* whenever a `UserIsHavingAVeryBadDay` exception is raised
* the first time any particular exception occurs
* whenever a request takes more than 20 seconds to process
* whenever someone upgrades their account
* whenever someone does comment#create more than 10 times in a day
* whenever someone tagged 'active' doesn't login for a week

### Example rule actions

* send yourself an email or a mobile push message
* send a user an email or a mobile push message
* create a ticket in your ticketing system
* add a data point to a Librato or StatsMix graph
* tag a user in WhenAUser, or in your CRM
* segment a user in your email campaign tool

Compatibility
-------------

This gem can be used without Rails, but when used with Rails it depends on Rails 3 (we've tested with Rails 3.1 and 3.2). If you want to use girl_friday, you must use Ruby 1.9.2 or greater, JRuby, or Rubinius.
