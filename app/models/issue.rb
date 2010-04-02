require_dependency 'issue'

module IssuePatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      before_validation {|issue| issue.subject.downcase! }
      validates_exclusion_of :subject,
                             :in => Issue.forbidden_names_array,
                             :message => "you provided is on the restricted subject list, sorry." 
    end
  end

  module ClassMethods

   def forbidden_names_array
    @forbidden_names = Setting.plugin_redmine_worklog['forbidden_names'] || []
     if @forbidden_names
       @forbidden_names = @forbidden_names.strip
       array_of_forbidden_names = []
       array_of_forbidden_names = @forbidden_names.split("|")
       return array_of_forbidden_names
   end
   end
  end

  module InstanceMethods

  end

end