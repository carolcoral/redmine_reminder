require 'redmine_extensions'

Redmine::Plugin.register :redmine_reminder do
  name 'Reminder Plugin'
  author 'carolcoral'
  author_url 'https://github.com/carolcoral'
  description 'A plugin for sending reminder emails for upcoming and overdue tasks'
  version '1.0.0'
  url 'https://github.com/carolcoral/redmine_reminder'

  permission :manage_reminder_settings, {}

  menu :admin_menu, :reminder_settings,
       { controller: 'reminders', action: 'settings' },
       caption: :reminder_settings_title,
       before: :plugins

  Rails.application.config.after_initialize do
    if defined?(Redmine::Scheduler)
      Redmine::Scheduler.instance.register_job(
        '0 * * * * *',
        -> { RedmineReminder::SchedulerJob.perform_now }
      ) do |job|
        Rails.logger.info "RedmineReminder: Scheduled job registered"
      end
    end
  end
end

require 'redmine_reminder/scheduler'

class RedmineReminder::SchedulerJob
  def self.perform_now
    return unless ReminderSetting.setting.enabled?
    RedmineReminder::Scheduler.new.run
  end
end
