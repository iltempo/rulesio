require 'girl_friday'

module RulesIO
  class MemoryQueue

    def self.push(hash)
      RulesIO.post_payload_to_token hash[:payload], hash[:token]
    end

  end
end
