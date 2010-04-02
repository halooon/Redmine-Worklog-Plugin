ActionController::Routing::Routes.draw do |map|
  map.resource :worklog, :controller => "worklog",
               :collection => {:load_activities => [:post]} 
end