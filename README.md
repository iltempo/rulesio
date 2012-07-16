WhenAUser
=========

[WhenAUser.com](http://whenauser.com) is a rules engine as a service that uses events from your application to trigger calls to 3rd party SaaS APIs. This lets you eliminate business logic in your application, and use the WhenAUser web UI instead. This gem contains Rack middleware for connecting to WhenAUser. It generates two event streams, one for exceptions and the other for pageviews.

Usage Example
-------------

    config.middleware.use 'WhenAUser::Rack',
      :token => CHANNEL_TOKEN
    config.middleware.use 'WhenAUser::Exceptions',
      :token => ERROR_CHANNEL_TOKEN
    config.middleware.use 'WhenAUser::Pageviews',
      :ignore_if => lambda { |env| env['action_controller.instance'].is_a? SillyController }

This gem will automatically send events for all exceptions and all pageviews (except those that filtered out by the options). You can also manually send additional events. For example:

    WhenAUser.send_event(
      :_actor => current_user.unique_id, 
      :_timestamp => Time.now.to_f, 
      :_domain => 'account',
      :_name => 'upgrade',
      :user_email => current_user.email,
      :plan => plan.name )

Options
-------

WhenAUser::Rack accepts these options:

* `token` -- the token for a WhenAUser channel
* `webhook_url` -- defaults to 'http://whenauser.com/events'

WhenAUser::Exceptions accepts these options:

* `ignore_exceptions` -- an array of exception class names, defaults to ['ActiveRecord::RecordNotFound', 'AbstractController::ActionNotFound', 'ActionController::RoutingError']
* `ignore_crawlers` -- an array of strings to match against the user agent, includes a number of webcrawlers by default
* `ignore_if` -- this proc is passed env and an exception; if it returns true, the exception is not reported to WhenAUser
* `token` -- the token for a WhenAUser channel
* `custom_data` -- this proc is passed env, and should return a hash to be merged into each event

WhenAUser::Pageviews accepts these options:

* `ignore_crawlers` -- an array of strings to match against the user agent, includes a number of webcrawlers by default
* `ignore_if` -- this proc is passed env; if it returns true, the pageview is not reported to WhenAUser
* `custom_data` -- this proc is passed env, and should return a hash to be merged into each event

Use Cases
---------

### Example rule triggers

* whenever a `UserIsHavingAVeryBadDay` exception is raised
* the first time any exception occurs
* whenever a request takes more than 20 seconds to process
* whenever someone upgrades their account
* whenever someone does comment#create more than 10 times in a day
* whenever someone tagged 'active' doesn't login for a week

### Example rule actions

* send yourself an email or a mobile push message
* send a user an email or a mobile push message
* create a ticket in your ticketing system
* add a data point to a Librato graph
* tag a user in WhenAUser, or in your CRM
* segment a user in your email campaign tool
