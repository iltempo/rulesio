module WhenAUser
  module Helpers
    def from_crawler(ignore_array, agent)
      ignore_array.each do |crawler|
        return true if (agent =~ /\b(#{crawler})\b/i)
      end unless ignore_array.blank?
      false
    end

    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end

    def actor_for_exception(exception)
      backtrace = clean_backtrace(exception)
      fileline = backtrace.first.match(/^(.*:.*):/)[1] rescue @app.to_s
      "#{exception.class.to_s}:#{fileline}"
    end
  end
end
