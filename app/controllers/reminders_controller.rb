class RemindersController < ApplicationController
  before_action :require_admin

  def settings
    @setting = ReminderSetting.setting
    @projects = Project.where(status: Project::STATUS_ACTIVE).order(:lft)

    if request.post? || request.patch?
      @setting.assign_attributes(reminder_params)
      if @setting.save
        flash[:notice] = l(:notice_successful_update)
        redirect_to reminders_settings_path
      else
        flash[:error] = @setting.errors.full_messages.join(', ')
        Rails.logger.error "ReminderSetting save failed: #{@setting.errors.full_messages}"
      end
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

    flash[:notice] = l(:reminder_settings_template_reset)
    redirect_to action: :settings
  end

  private

  def reminder_params
    params_hash = params.fetch(:reminder_setting, {})

    permitted_params = params_hash.permit(
      :remind_before_days,
      :schedule_time,
      :frequency_limit,
      :email_template,
      :enabled,
      selected_projects: []
    ).to_h.deep_symbolize_keys

    permitted_params[:enabled] = permitted_params[:enabled] == '1' || permitted_params[:enabled] == true
    permitted_params[:selected_projects] = (permitted_params[:selected_projects] || []).reject(&:blank?).map(&:to_i)
    permitted_params[:remind_before_days] = permitted_params[:remind_before_days].to_i
    permitted_params[:frequency_limit] = permitted_params[:frequency_limit].to_i

    permitted_params
  end

  def require_admin
    require_admin_or_lesser_admin(:manage_reminder_settings)
  end
end
