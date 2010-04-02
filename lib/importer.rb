class Importer

  class << self
    def load_activities_from_text(user, lines)
      result_hash = { :errors => [], :to_create => [], :updated => [] }
      lines_array = []
      lines.each do |line|
        unless line.strip.blank?
          params_hash = build_params_hash(line)
          params_hash[:user] = user
          params_hash[:project] = get_project(params_hash[:bucket_names])
          err = valid_line?(params_hash, lines_array)

          lines_array << params_hash
          unless err.empty?
            result_hash[:errors].push "Line <span class='line_desc'>#{line}</span> has following errors <ul class='line_errors'>#{err.map {|e| "<li>#{e}</li>"}}</ul>"
            next
          else
            try_to_get_issue(params_hash) ? result_hash[:updated].push(new_time_entry(params_hash)) : result_hash[:to_create].push(new_issue(params_hash))         
          end
        end
      end  
      result_hash
    end

    def insert_comment(params_hash)
      freaking_array = []
      freaking_array << params_hash[:from_time].strftime("%H:%M") << params_hash[:to_time].strftime("%H:%M") << params_hash[:desc].sub(/\A[\S]+\b/, '')
      freaking_array.join(" ")
    end


    def new_time_entry(params_hash)

      issue = params_hash[:issue]
      current_issue = issue.time_entries.build(:hours => params_hash[:spent_hours], :project_id => issue.project_id,
                               :user_id => issue.author_id, :comments => insert_comment(params_hash),
                               :spent_on => params_hash[:date], :from_time => params_hash[:from_time],
                               :to_time => params_hash[:to_time], :activity_id => TimeEntryActivity.find_by_name(params_hash[:activity]).id )
      current_issue.custom_values.build(:customized_type => "TimeEntry",
                                                   :custom_field_id => TimeEntryCustomField.find_by_name("Effort type").id,
                                                   :value => params_hash[:commitement_type])
      current_issue
    end

    def new_issue(params_hash)
      issue = Issue.new(:author_id => params_hash[:user].id, :subject => params_hash[:subject],
                        :description => params_hash[:desc], :project_id => params_hash[:project].id)
      issue.time_entries.build(:hours => params_hash[:spent_hours], :project_id => issue.project_id,
                               :user_id => issue.author_id, :comments => insert_comment(params_hash),
                               :spent_on => params_hash[:date], :from_time => params_hash[:from_time],
                               :to_time => params_hash[:to_time])
      issue
    end

    def get_project(bucket_names)
      if bucket_names and bucket_names.first
        parent = Project.find_by_identifier(bucket_names.first.downcase)
        if bucket_names.size == 1
          parent
        else
          Project.find_by_identifier_and_parent_id(bucket_names.last, parent.id) if !parent.nil?
        end
      end

    end

    def worklog_timewarps(params_hash, lines_array)
        return true if (params_hash[:from_time] > params_hash[:to_time])
        return false if lines_array.empty?
        lines_array.each do |array_line|
         return true if (params_hash[:from_time] - array_line[:to_time] < 0) 
          end
        false
    end

    def valid_line?(params_hash, lines_array)
      err = []
      err.push "Project name is empty" if params_hash[:bucket_names].blank?
      err.push "Project with this name does not exist" unless params_hash[:project]
      err.push "No issue's subject or id provided" if params_hash[:id].blank? and params_hash[:subject].blank?
      err.push "Have you just invented time warp machine? Please be sure to send blueprints to socjopata@gmail.com" if worklog_timewarps(params_hash, lines_array)
     # err.push "You're trying to create an issue with a restricted name" if attmepting_to_create_issue_with_reserved_name(params_hash)
      err
    end

    def set_activity(param)
      description_words = param.split.map(&:downcase)
      TimeEntryActivity.all.map{|tea| tea.name.downcase}.each do |activity_name|
        return activity_name.capitalize if description_words.detect{|an| an == activity_name}
      end
      "Other"
    end

    def set_spent_time_type(param)
       description_words = param.split.map(&:downcase)
       TimeEntryCustomField.find_by_name("Effort type").possible_values.map{|pv| pv.downcase}.each do |downcased|
           return downcased.capitalize if description_words.detect{|an| an == downcased}
         end
         "Regular"
       end

    def build_params_hash(line)
      result = {}

      line_data, desc = line.split("|")

      line_data = line_data.split
      result[:date] = Date.parse(line_data[0]) # .split(".").reverse.join("."))
      result[:from_time] = Time.parse("#{result[:date]} #{line_data[1]}") rescue (throw "Can not parse to date: #{result[:date]} #{line_data[1]}")
      result[:to_time] = Time.parse("#{result[:date]} #{line_data[2]}") rescue (throw "Can not parse to date: #{result[:date]} #{line_data[2]}")
      result[:spent_hours] = Float((result[:to_time] - result[:from_time]) / 3600)
      result[:tags] = line_data[4..-1].join(" ") unless line_data[4..-1].nil?
      #hash fix for ignoring bucket names
      #result[:bucket_names] = line_data[3].split("/") unless line_data[3].nil?
      id_or_name = desc.split.first
      result[:desc] = desc.blank? ? "" : desc.strip
      result[:activity] = set_activity(desc)
      result[:commitement_type] = set_spent_time_type(desc)
      unless id_or_name.blank?
        if id_or_name.to_i == 0
          (id_or_name.include? "#")? result[:id] = id_or_name.gsub!("#", "").strip : result[:subject] = id_or_name
        else
          result[:id] = id_or_name
        end
      end
       #if there are no buckets, we'll fill it using issue id or name. If there is no  issue id and name then the result should be nil and the validation will hold it
      result[:bucket_names].blank? ? result[:bucket_names] = bucket_names_fix(result[:id], result[:subject]) : result[:bucket_names]

#      #this takes care of empty subject if you input an entry like: ...blabla bla | #10003210320440230. Needed later for unique subject validation.
#      result[:bucket_names].blank? ? result[:subject] = id_or_name : result[:bucket_names]

      result
    end

    def bucket_names_fix(result_id, result_subject)
      result_id.blank? ? get_buckets_by_issue_name(result_subject) : get_buckets_by_issue_id(result_id)
    end

    def get_buckets_by_issue_id(issue_id)
      result = []
      result << Project.find(Issue.find(issue_id).project_id).parent.identifier rescue nil
      result << Project.find(Issue.find(issue_id).project_id).identifier rescue nil
    end

    def get_buckets_by_issue_name(issue_name)
      issue_name.strip! if issue_name
      result = []
      result << Project.find(Issue.find_by_subject(issue_name).project_id).parent.identifier rescue nil
      result << Project.find(Issue.find_by_subject(issue_name).project_id).identifier rescue nil
    end

    def try_to_get_issue(params_hash)
      if params_hash[:id] or params_hash[:subject]
        issue = params_hash[:id].blank? ? Issue.find_by_subject(params_hash[:subject]) : Issue.find_by_id(params_hash[:id])
        params_hash[:issue] = issue
        issue
      end
    end

    def log_time(user, issues, action)
    result = {}
    action=="create"? (result[:new_issues] = create_issues(user, issues)) : (result[:new_time_entries] = update_issues(user, issues))
    end

    def create_issues(user, new_issues)
      
      #TODO creating issues is NOT tested
      result = {:failed => [], :success => []}
      new_issues.each do |issue_params|
        issue_params[:from_time] = build_date_from_params("from", issue_params)
        issue_params[:to_time] = build_date_from_params("to", issue_params)
        time_entry_params = issue_params.delete(:time_entry)

        issue = Issue.new(issue_params)
        time_entry = issue.time_entries.build(time_entry_params)
        time_entry.project_id = issue.project_id
        time_entry.user_id = issue.author_id

        Issue.transaction do
          begin
            issue.save!
            issue.time_entries << time_entry
          rescue
            raise ActiveRecord::Rollback
          end
        end
        !issue.new_record? ? result[:success].push(issue) : result[:failed].push(issue)
      end
     result
    end

    def build_date_from_params(name, params)
      if name=="from"
      from = params[:comments].split.first
      result = "#{from} #{params[:spent_on]}".to_time 
      else
      to = params[:comments].split.first(2).last
      result = "#{to} #{params[:spent_on]}".to_time
      end
      result
    end

    def update_issues(user, new_time_entries)
      result = {:failed => [], :success => []}

      new_time_entries.each do |time_entry_params|
        next unless issue = Issue.find_by_id(time_entry_params[:issue_id])
        #lol / pacepalm
        c_type = time_entry_params.custom_values.first.customized_type
        c_field_id  = TimeEntryCustomField.find_by_name("Effort type").id
        c_value = time_entry_params.custom_values.first.value
        #shall we continue? >_>
        time_entry_params[:from_time] = build_date_from_params("from", time_entry_params)
        time_entry_params[:to_time] = build_date_from_params("to", time_entry_params)
        time_entry = issue.time_entries.build(:project => issue.project, :user => user,
                                              :hours => time_entry_params[:hours],
                                              :comments => time_entry_params[:comments],
                                              :spent_on => time_entry_params[:spent_on],
                                              :activity_id => time_entry_params[:activity_id],
                                              :from_time => time_entry_params[:from_time],
                                              :to_time => time_entry_params[:to_time])
        time_entry.custom_values.build(:customized_type => c_type,
                                       :custom_field_id => c_field_id,
                                       :value => c_value)
        time_entry.save ? result[:success].push(time_entry) : result[:failed].push(time_entry)
      end
      result
    end
  end


end
