class RemindersController < ApplicationController
  before_action :require_admin

  def settings
    if request.post? || request.patch?
      save_settings
    end
  end

  def test_email
    plugin_settings = Setting.plugin_redmine_reminder || {}
    
    Rails.logger.info "=========================================="
    Rails.logger.info "[RedmineReminder] ====== TEST EMAIL REQUEST ======"
    Rails.logger.info "[RedmineReminder] User: #{User.current.name} (#{User.current.mail})"
    Rails.logger.info "[RedmineReminder] Request IP: #{request.ip}"
    Rails.logger.info "[RedmineReminder] Request URL: #{request.url}"
    Rails.logger.info "[RedmineReminder] Request Method: #{request.method}"
    Rails.logger.info "[RedmineReminder] Current Settings: #{plugin_settings.inspect}"
    
    begin
      test_tasks = [
        {
          issue_id: '#TEST001',
          issue_name: '测试任务',
          due_date: Date.today.strftime('%Y-%m-%d'),
          status: '进行中',
          priority: '高',
          tracker: '功能',
          assigned_to: User.current.name,
          description: '这是一个测试任务描述',
          overdue_days: 2,
          is_overdue: true,
          project_name: Setting.app_title,
          url: "#{Setting.protocol}://#{Setting.host_name}/issues/1"
        }
      ]

      email_template = plugin_settings['email_template'].presence || ReminderSetting.default_template
      Rails.logger.info "[RedmineReminder] Email Template Length: #{email_template.length} characters"
      Rails.logger.info "[RedmineReminder] Email Template Preview: #{email_template.truncate(200)}"

      mailer_result = ReminderMailer.send_reminder_email(
        User.current,
        test_tasks,
        email_template
      ).deliver_now

      Rails.logger.info "[RedmineReminder] ====== TEST EMAIL RESPONSE ======"
      Rails.logger.info "[RedmineReminder] Mailer Result Class: #{mailer_result.class}"
      Rails.logger.info "[RedmineReminder] Mailer Result: #{mailer_result.inspect}"
      Rails.logger.info "[RedmineReminder] From: #{mailer_result.from}"
      Rails.logger.info "[RedmineReminder] To: #{mailer_result.to}"
      Rails.logger.info "[RedmineReminder] Subject: #{mailer_result.subject}"
      Rails.logger.info "[RedmineReminder] Message ID: #{mailer_result.message_id}"
      Rails.logger.info "[RedmineReminder] Test email sent successfully to #{User.current.mail}"
      Rails.logger.info "=========================================="
      
      flash[:notice] = l(:reminder_test_email_sent)
    rescue => e
      Rails.logger.error "[RedmineReminder] ====== TEST EMAIL ERROR ======"
      Rails.logger.error "[RedmineReminder] Error Class: #{e.class}"
      Rails.logger.error "[RedmineReminder] Error Message: #{e.message}"
      Rails.logger.error "[RedmineReminder] Backtrace:"
      Rails.logger.error e.backtrace&.first(10)&.join("\n")
      Rails.logger.error "=========================================="
      
      flash[:error] = "#{l(:reminder_test_email_failed)}: #{e.message}"
    end

    redirect_to action: :settings
  end

  def preview_template
    plugin_settings = Setting.plugin_redmine_reminder || {}
    template = params[:template].presence || plugin_settings['email_template'].presence || ReminderSetting.default_template

    test_tasks = [
      {
        issue_id: '#001',
        issue_name: '示例任务',
        due_date: Date.today.strftime('%Y-%m-%d'),
        status: '进行中',
        priority: '高',
        tracker: '功能',
        assigned_to: '张三',
        description: '任务描述内容',
        overdue_days: 3,
        is_overdue: true,
        project_name: Setting.app_title,
        url: "#{Setting.protocol}://#{Setting.host_name}/issues/1"
      }
    ]

    html = render_to_string(
      partial: 'reminders/template_preview',
      locals: { template: template, tasks: test_tasks, user: User.current }
    )

    render html: html
  end

  def reset_template
    current_settings = Setting.plugin_redmine_reminder || {}
    current_settings['email_template'] = ReminderSetting.default_template
    Setting.plugin_redmine_reminder = current_settings

    flash[:notice] = l(:reminder_settings_template_reset)
    redirect_to action: :settings
  end

  private

  def save_settings
    Rails.logger.info "[RedmineReminder] Save settings request started"
    Rails.logger.info "[RedmineReminder] Raw params: #{params.inspect}"
    
    reminder_params = reminder_params_hash
    Rails.logger.info "[RedmineReminder] Permitted params: #{reminder_params.inspect}"

    Setting.plugin_redmine_reminder = reminder_params
    Rails.logger.info "[RedmineReminder] Settings saved successfully: #{Setting.plugin_redmine_reminder.inspect}"

    flash[:notice] = l(:notice_successful_update)
    redirect_to reminders_settings_path
  rescue => e
    Rails.logger.error "[RedmineReminder] Save settings failed: #{e.class} - #{e.message}"
    Rails.logger.error "[RedmineReminder] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    flash[:error] = "#{e.class}: #{e.message}"
    redirect_to reminders_settings_path
  end

  def reminder_params_hash
    params_hash = params.fetch(:reminder_setting, {})
    Rails.logger.info "[RedmineReminder] Form params: #{params_hash.inspect}"

    permitted_params = params_hash.permit(
      :remind_before_days,
      :schedule_time,
      :frequency_limit,
      :email_template,
      :plugin_enabled,
      :ip_whitelist,
      selected_projects: []
    ).to_h

    Rails.logger.info "[RedmineReminder] After permit: #{permitted_params.inspect}"

    # Handle plugin_enabled - convert string '1'/'0' to boolean
    if permitted_params.key?('plugin_enabled')
      permitted_params['plugin_enabled'] = permitted_params['plugin_enabled'].to_s == '1'
    end

    permitted_params['selected_projects'] = (permitted_params['selected_projects'] || []).reject(&:blank?).map(&:to_s)
    permitted_params['remind_before_days'] = permitted_params['remind_before_days'].to_i
    permitted_params['frequency_limit'] = permitted_params['frequency_limit'].to_i

    Rails.logger.info "[RedmineReminder] Final params: #{permitted_params.inspect}"
    permitted_params
  end

end
