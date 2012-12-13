module RulesIO
  class Base
    # include Singleton
    attr_accessor :token, :buffer

    def initialize(token)
      RulesIO.instance = self
      puts "INSTANCE SET"
      @token = token
      @buffer = []
    end

    def send_event(event)
      @buffer << prepare_event(event)
    end
    
    def flush
      return if (events = @buffer).empty?
      @buffer = []
      RulesIO.queue.push(:payload => events, :token => @token)
    end

  private
    def prepare_event(event)
      event = event.with_indifferent_access

      event[:_actor] = event[:_actor].to_s
      event[:_timestamp] ||= Time.now.to_f

      event
    end
  end
end