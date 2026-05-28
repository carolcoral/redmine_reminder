Redmine::Plugin.register :redmine_reminder do
  name 'Redmine Reminder'
  author 'carolcoral'
  author_url 'https://github.com/carolcoral'
  description 'A plugin for sending reminder emails for upcoming and overdue tasks'
  version '1.0.1'
  url 'https://github.com/carolcoral/redmine_reminder'

  permission :manage_reminder_settings, {}

  settings default: {
    'plugin_enabled' => '1',
    'remind_before_days' => 3,
    'schedule_time' => '09:00',
    'frequency_limit' => 7,
    'selected_projects' => [],
    'email_template' => nil,
    'ip_whitelist' => ''
  }, partial: 'settings/reminders'

  locales_for_plugin = Dir.glob(File.join(File.dirname(__FILE__), 'langs', '*.yml'))
  Rails.application.config.i18n.load_path += locales_for_plugin

  Rails.application.config.after_initialize do
    Thread.new do
      # 随机延迟启动（避免多 worker 同时触发）
      sleep rand(5..30)

      local_ip = begin
        Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? && !addr.ipv4_multicast? }&.ip_address
      rescue
        'unknown'
      end

      Rails.logger.info "[RedmineReminder] Scheduler thread started on container IP: #{local_ip}"

      loop do
        begin
          RedmineReminder::SchedulerJob.perform_now
        rescue => e
          Rails.logger.error "[RedmineReminder] Scheduler error: #{e.class} - #{e.message}"
        end

        sleep 60
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
