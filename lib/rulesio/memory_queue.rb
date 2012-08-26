require 'girl_friday'

module RulesIO
  class MemoryQueue

    def self.push(hash)
      RulesIO.post_payload_to_token hash[:payload], RulesIO.token
    end

  end
end
