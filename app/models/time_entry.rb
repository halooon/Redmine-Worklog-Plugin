require_dependency 'time_entry'

module TimeEntryPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      attr_accessor :from_time, :to_time
      before_create :extend_comment
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def validate_on_create
      errors.add(:from_time, "Log time entry can not override another time entry => #{from_time.strftime("%d.%m.%Y %H:%M")} - #{to_time.strftime("%d.%m.%Y %H:%M")} Issue: #{issue.subject} ") if issue and overlaps?(issue, user)
    end

    def overlaps?(issue, user)
      return false if self.from_time.nil? and self.to_time.nil?
      time_entries_for_user =  issue.time_entries.find(:all, :conditions => ["user_id=?", user.id])
      time_entries_for_user.each do |time_entry|
        from_time, to_time = time_entry.get_time_from_comment
        if from_time.kind_of?(Time) and to_time.kind_of?(Time)
        #TODO proper solution for timezones
         from_time = from_time.utc + 3600
         to_time = to_time.utc + 3600
         return true if (from_time..(to_time - 60)).overlaps?((self.from_time)..(self.to_time))
        end
      end

      false
    end

    def get_time_from_comment
      comment = self.comments.split("|")
      if comment.size > 1
        spent_on, from_time_to_time = comment.first.split
        from_time, to_time = from_time_to_time.split("-") if from_time_to_time
        return Time.parse("#{spent_on} #{from_time}"), Time.parse("#{spent_on} #{to_time}")
      end
      return nil, nil
    end

    def extend_comment
      if !from_time.blank? and !to_time.blank?
        self.comments = "#{spent_on} #{from_time.strftime("%H:%M")}-#{to_time.strftime("%H:%M")} | #{self.comments}"
      end
    end
  end
end


