class RemindersController < ApplicationController
  before_action :require_admin

  def settings
    @setting = ReminderSetting.setting
    @projects = Project.where(status: Project::STATUS_ACTIVE).order(:lft)

    if request.post? || request.patch?
      save_settings
    end
  end

  def test_email
    @setting = ReminderSetting.setting
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

      ReminderMailer.send_reminder_email(
        User.current,
        test_tasks,
        @setting.email_template
      ).deliver_now

      flash[:notice] = l(:reminder_test_email_sent)
    rescue => e
      flash[:error] = "#{l(:reminder_test_email_failed)}: #{e.message}"
    end

    redirect_to action: :settings
  end

  def preview_template
    template = params[:template] || ReminderSetting.default_template

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
    @setting = ReminderSetting.setting
    @setting.email_template = ReminderSetting.default_template
    @setting.save
    sync_to_plugin_settings

    flash[:notice] = l(:reminder_settings_template_reset)
    redirect_to action: :settings
  end

  private

  def save_settings
    reminder_params = reminder_params_hash

    Setting.plugin_redmine_reminder = reminder_params
    sync_to_model_setting(reminder_params)

    flash[:notice] = l(:notice_successful_update)
    redirect_to reminders_settings_path
  rescue => e
    flash[:error] = e.message
    Rails.logger.error "Save settings failed: #{e.message}"
  end

  def sync_to_plugin_settings
    setting = ReminderSetting.setting
    Setting.plugin_redmine_reminder = {
      'enabled' => setting.enabled?,
      'remind_before_days' => setting.remind_before_days,
      'schedule_time' => setting.schedule_time,
      'frequency_limit' => setting.frequency_limit,
      'selected_projects' => setting.selected_projects,
      'email_template' => setting.email_template
    }
  end

  def sync_to_model_setting(params)
    setting = ReminderSetting.setting
    setting.assign_attributes(
      enabled: params['enabled'],
      remind_before_days: params['remind_before_days'],
      schedule_time: params['schedule_time'],
      frequency_limit: params['frequency_limit'],
      selected_projects: params['selected_projects'],
      email_template: params['email_template']
    )
    setting.save!
  end

  def reminder_params_hash
    params_hash = params.fetch(:reminder_setting, {})

    permitted_params = params_hash.permit(
      :remind_before_days,
      :schedule_time,
      :frequency_limit,
      :email_template,
      :enabled,
      selected_projects: []
    ).to_h

    permitted_params['enabled'] = permitted_params['enabled'] == '1' || permitted_params['enabled'] == true
    permitted_params['selected_projects'] = (permitted_params['selected_projects'] || []).reject(&:blank?).map(&:to_s)
    permitted_params['remind_before_days'] = permitted_params['remind_before_days'].to_i
    permitted_params['frequency_limit'] = permitted_params['frequency_limit'].to_i

    permitted_params
  end

end
