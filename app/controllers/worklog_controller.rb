class WorklogController < ApplicationController
  unloadable

  before_filter :check_rights
  include SortHelper
  include ApplicationHelper
  
  helper :sort  
  helper :issues
  helper :timelog
  
  def show
   latest_time_entries_for_user
  end
  
   #this method looks like... as it looks like because at first the requirement was to create or uppdate issues depending on their existence in the system. Creating was dropped later.
  def load_activities
    @lines = params[:lines]
 #  for better debugging
 #  load File.join(RAILS_ROOT, "vendor", "plugins", "redmine_worklog", "lib", "importer.rb")
 #  load File.join(RAILS_ROOT, "vendor", "plugins", "redmine_worklog", "app", "models", "time_entry.rb")
  unless params[:lines].blank?
      @load_result = Importer.load_activities_from_text(User.current, params[:lines])
      @lines_have_errors = true unless @load_result[:errors].blank?
      @issue_collection = @load_result[:to_create]
      @time_entry_collection = @load_result[:updated]
  end

  unless @time_entry_collection.blank?
    unless @lines_have_errors
    @issues_to_create = Importer.log_time(User.current, @issue_collection, "create")
    @issues_to_update = Importer.log_time(User.current, @time_entry_collection, "update")
    @issues_created = true if !@issues_to_create[:success].blank?
    @issues_have_errors = true if !@issues_to_create[:failed].blank?
    @time_entries_updated = true if !@issues_to_update[:success].blank?
    @time_entries_have_errors = true if !@issues_to_update[:failed].blank?
    (!@time_entries_have_errors and !@issues_have_errors)? @lines=nil : @lines
     end
  end
    latest_time_entries_for_user
    render :action => :show
  end

  private
  def check_rights
    @settings = Setting["plugin_redmine_worklog"]
    if @settings.blank? or @settings[:user_access_list].blank? or @settings[:user_access_list][User.current.id.to_s] != "1"
      flash[:error] = "You have no rights to be here"
      redirect_to "/"
    end
  end

  def latest_time_entries_for_user
  @latest_time_entry_activities = TimeEntry.find(:all, :conditions => ["user_id=?", User.current.id], :order => "created_on desc", :limit => 25)
  end

 
end
