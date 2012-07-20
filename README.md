WhenAUser
=========

[WhenAUser.com](http://whenauser.com) is a rules engine that reacts to things users do or experience in your software, and makes things happen in 3rd party SaaS APIs -- without your having to write any code. Rather than implementing the most rapidly evolving parts of your application's business logic in code, your team can use the WhenAUser web app to specify "when", "how", and "who", with rules like these:

* when a user gets a validation error twice for the same form, send an email to Frank
* when a premium customer hasn't logged in for a month, flag them in Highrise
* when a user gets a 500 response, create a ticket in Zendesk
* when a user invites ten friends, move them to the "well-connected" segment in MailChimp

This gem contains Rack middleware that automatically generates two event streams, one for exceptions and the other for pageviews, that can used to trigger rules in WhenAUser. You can (and probably should) also send more specific events manually.

Usage Example
-------------

    config.middleware.use 'WhenAUser::Rack',
      :token => CHANNEL_TOKEN
    config.middleware.use 'WhenAUser::Exceptions',
      :token => ERROR_CHANNEL_TOKEN
    config.middleware.use 'WhenAUser::Pageviews',
      :ignore_if => lambda { |env| env['action_controller.instance'].is_a? SillyController }

To manually send an event when a user upgrades to a "premium" account:

    WhenAUser.send_event(
      :_actor => current_user.unique_id, 
      :_timestamp => Time.now.to_f, 
      :_domain => 'account',
      :_name => 'upgrade',
      :user_email => current_user.email,
      :plan => 'premium' )

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
