require 'redmine'

require 'dispatcher'
Dir[File.join(File.dirname(__FILE__), "app", "models", "*")].each {|f| require f}

Dispatcher.to_prepare do
  Issue.send(:include, IssuePatch)
  TimeEntry.send(:include, TimeEntryPatch)
end

Redmine::Plugin.register :redmine_worklog do
  name 'Redmine Worklog plugin'
  author 'Mateusz Juraszek and Radosław Jędryszczak; Selleo'
  description 'Plugin introduces a quick way to update Redmine projects with worklogged efforts from custom Selleo spreadsheets'
  version '0.2.0'

  settings :default => {
    'user_access_list' => {}
  }, :partial => 'settings/redmineworklog_settings'

  menu :top_menu, :worklog, { :controller => 'worklog', :action => 'show'}, 
       :caption => "Worklog",
       :if => Proc.new{User.current.logged?}
end
