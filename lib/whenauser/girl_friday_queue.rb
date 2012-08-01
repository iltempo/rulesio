require 'girl_friday'

module WhenAUser
  class GirlFridayQueue < GirlFriday::WorkQueue

    include Singleton
  
    def initialize
      super(:whenauser, {:size => 1}.merge(WhenAUser.queue_options)) do |msg|
        WhenAUser.post_payload_to_token msg[:payload], WhenAUser.token
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
