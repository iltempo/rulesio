require 'singleton'
require 'girl_friday'

module RulesIO
  class GirlFridayQueue < GirlFriday::WorkQueue

    include Singleton
  
    def initialize
      super(:rulesio, {:size => 1}.merge(RulesIO.queue_options)) do |msg|
        retries = 0
        begin
          RulesIO.post_payload_to_token msg[:payload], msg[:token]
        rescue Exception => e
          if (retries += 1) % 6 == 5
            RulesIO.logger.warn "RulesIO having trouble sending events; #{retries} attempts so far."
            RulesIO.logger.warn "#{e.inspect}: #{e.message}"
          end
          sleep [5, retries].max
          retry
        end
        RulesIO.logger.warn "RulesIO resuming service after #{retries} retries." unless retries == 0
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
