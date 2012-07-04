require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module Lograge
  class Railtie < Rails::Railtie
    config.whenauser = ActiveSupport::OrderedOptions.new

    initializer :whenauser do |app|
      WhenAUser.setup(app)
    end
  end
end