WhenAUser
=========

[WhenAUser.com](http://whenauser.com) is a rules engine as a service that uses events from your application to trigger calls to 3rd party SaaS APIs. This lets you eliminate business logic in your application, and use the WhenAUser web UI instead. This gem contains Rack middleware for connecting to WhenAUser. It generates two event streams, one for exceptions and the other for pageviews.

Usage
-----

    config.middleware.use 'WhenAUser::Rack',
      :token => 'miKTaOlW1xzvEDG-QF9ZrA'
    config.middleware.use 'WhenAUser::Exceptions',
      :token => 'T4Jk7141XQefcD35v1Wzwg'
    config.middleware.use 'WhenAUser::Pageviews',
      :ignore_if => lambda { |env| env['action_controller.instance'].is_a? SillyController }

