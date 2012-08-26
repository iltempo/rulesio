module ActiveRecord
  module RulesIOExtension
    def save(*)
      result = super
      send_invalid_model_event if result == false
      result
    end

    def save!(*)
      begin
        super
      rescue ::ActiveRecord::RecordNotSaved
        send_invalid_model_event
        raise ::ActiveRecord::RecordNotSaved
      end
    end

    private
    def send_invalid_model_event
      event = {
        :_domain => 'invalid_model',
        :_name => self.class.name,
        :attributes => self.attributes,
        :errors => self.errors.full_messages.to_sentence
      }
      RulesIO.send_event event
    end
  end
end
