class RemindersController < ApplicationController
  before_action :require_admin

  def settings
    if request.post? || request.patch?
      save_settings
    end
  end

  def test_email
    plugin_settings = Setting.plugin_redmine_reminder || {}
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
      ReminderMailer.send_reminder_email(
        User.current,
        test_tasks,
        email_template
      ).deliver_now

      flash[:notice] = l(:reminder_test_email_sent)
    rescue => e
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
    reminder_params = reminder_params_hash

    Setting.plugin_redmine_reminder = reminder_params

    flash[:notice] = l(:notice_successful_update)
    redirect_to reminders_settings_path
  rescue => e
    flash[:error] = e.message
    Rails.logger.error "Save settings failed: #{e.message}"
  end

  def reminder_params_hash
    params_hash = params.fetch(:reminder_setting, {})

    permitted_params = params_hash.permit(
      :remind_before_days,
      :schedule_time,
      :frequency_limit,
      :email_template,
      :plugin_enabled,
      :ip_whitelist,
      selected_projects: []
    ).to_h

    permitted_params['plugin_enabled'] = permitted_params['plugin_enabled'] == '1' || permitted_params['plugin_enabled'] == true
    permitted_params['selected_projects'] = (permitted_params['selected_projects'] || []).reject(&:blank?).map(&:to_s)
    permitted_params['remind_before_days'] = permitted_params['remind_before_days'].to_i
    permitted_params['frequency_limit'] = permitted_params['frequency_limit'].to_i

    permitted_params
  end

end
