require 'girl_friday'

module WhenAUser
  class MemoryQueue

    def self.push(hash)
      WhenAUser.post_payload_to_token hash[:payload], WhenAUser.token
    end

  end
end
