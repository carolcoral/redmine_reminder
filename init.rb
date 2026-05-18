Redmine::Plugin.register :redmine_reminder do
  name 'Redmine Reminder'
  author 'carolcoral'
  author_url 'https://github.com/carolcoral'
  description 'A plugin for sending reminder emails for upcoming and overdue tasks'
  version '1.0.0'
  url 'https://github.com/carolcoral/redmine_reminder'

  permission :manage_reminder_settings, {}

  settings default: {
    'enabled' => false,
    'remind_before_days' => 3,
    'schedule_time' => '09:00',
    'frequency_limit' => 7,
    'selected_projects' => []
  }, partial: 'settings/reminders', defaults: :reminders

  locales_for_plugin = Dir.glob(File.join(File.dirname(__FILE__), 'langs', '*.yml'))
  Rails.application.config.i18n.load_path += locales_for_plugin

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

require_relative 'app/helpers/redmine_reminder/reminder_settings_helper'
require_relative 'lib/redmine_reminder/scheduler'

class RedmineReminder::SchedulerJob
  def self.perform_now
    plugin_settings = Setting.plugin_redmine_reminder || {}
    return unless plugin_settings['plugin_enabled'] == '1' || plugin_settings['plugin_enabled'] == true
    RedmineReminder::Scheduler.new.run
  end
end
