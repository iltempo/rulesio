require 'singleton'
require 'girl_friday'

module WhenAUser
  class GirlFridayQueue < GirlFriday::WorkQueue

    include Singleton
  
    def initialize
      super(:whenauser, {:size => 1}.merge(WhenAUser.queue_options)) do |msg|
        retries = 0
        begin
          WhenAUser.post_payload_to_token msg[:payload], WhenAUser.token
        rescue Exception => e
          if (retries += 1) % 6 == 5
            WhenAUser.logger.warn "WhenAUser having trouble sending events; #{retries} attempts so far."
          end
          sleep [5, retries].max
          retry
        end
        WhenAUser.logger.warn "WhenAUser resuming service after #{retries} retries." unless retries == 0
      end
    end

    def self.push *args
      instance.push *args
    end

    def self.status
      instance.status
    end

  end
end
