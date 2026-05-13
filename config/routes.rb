Redmine::Application.routes.draw do
  match 'reminders/settings', :to => 'reminders#settings', :via => [:get, :post]
  match 'reminders/test_email', :to => 'reminders#test_email', :via => [:get, :post]
  match 'reminders/preview_template', :to => 'reminders#preview_template', :via => [:post]
  match 'reminders/reset_template', :to => 'reminders#reset_template', :via => [:post]
end
