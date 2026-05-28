class RemindersController < ApplicationController
  before_action :require_admin
  before_action :log_request

  def test_email
    plugin_settings = Setting.plugin_redmine_reminder || {}
    local_ip = RedmineReminder::Scheduler.local_ip

    Rails.logger.info "[RedmineReminder] ====== Test email START ======"
    Rails.logger.info "[RedmineReminder] Request from #{request.ip}, container IP: #{local_ip}, user: #{User.current.name} (#{User.current.mail})"

    unless RedmineReminder::Scheduler.ip_whitelisted?
      Rails.logger.warn "[RedmineReminder] Test email BLOCKED - container IP #{local_ip} not in whitelist"
      flash[:error] = l(:reminder_test_email_ip_denied)
      redirect_to '/settings/plugin/redmine_reminder'
      return
    end

    validate_smtp_settings!

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
          description: '这是一个测试任务描述，用于验证邮件发送功能是否正常工作。',
          overdue_days: 2,
          is_overdue: true,
          project_name: Setting.app_title,
          url: "#{Setting.protocol}://#{Setting.host_name}/issues/1"
        }
      ]

      email_template = plugin_settings['email_template'].presence || ReminderSetting.default_template

      mail_message = ReminderMailer.send_reminder_email(
        User.current,
        test_tasks,
        email_template
      )

      smtp_settings = ActionMailer::Base.smtp_settings
      Rails.logger.info "[RedmineReminder] SMTP: #{smtp_settings[:address]}:#{smtp_settings[:port]} auth=#{smtp_settings[:authentication] || 'none'} from=#{smtp_settings[:from] || Setting.mail_from || 'N/A'}"

      original_perform = ActionMailer::Base.perform_deliveries
      ActionMailer::Base.perform_deliveries = true

      delivery_result = mail_message.deliver_now

      ActionMailer::Base.perform_deliveries = original_perform

      if delivery_result
        deliveries = mail_message.deliveries rescue []
        if deliveries.empty?
          Rails.logger.warn "[RedmineReminder] WARNING: Deliveries array is empty - email may not have been sent!"
        else
          Rails.logger.info "[RedmineReminder] Delivery result: #{deliveries.inspect}"
        end
      else
        Rails.logger.warn "[RedmineReminder] WARNING: deliver_now returned falsy value: #{delivery_result.inspect}"
      end

      Rails.logger.info "[RedmineReminder] Test email sent successfully to #{User.current.mail}"
      flash[:notice] = l(:reminder_test_email_sent)

    rescue Net::SMTPAuthenticationError => e
      Rails.logger.error "[RedmineReminder] SMTP Auth Error: #{e.message}"
      flash[:error] = "#{l(:reminder_test_email_failed)}: SMTP认证失败 - 请检查用户名和密码 (#{e.message})"

    rescue Net::SMTPFatalError, Net::SMTPSyntaxError => e
      Rails.logger.error "[RedmineReminder] SMTP Fatal Error: #{e.message}"
      flash[:error] = "#{l(:reminder_test_email_failed)}: SMTP错误 - #{e.message}"

    rescue Net::SMTPUnknownError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      Rails.logger.error "[RedmineReminder] Connection Error: #{e.message}"
      flash[:error] = "#{l(:reminder_test_email_failed)}: 连接失败 - 无法连接到邮件服务器 (#{e.message})"

    rescue => e
      Rails.logger.error "[RedmineReminder] Unexpected Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace&.first(10)&.join("\n")
      flash[:error] = "#{l(:reminder_test_email_failed)}: #{e.message}"
    end

    Rails.logger.info "[RedmineReminder] ====== Test email END ======"
    redirect_to '/settings/plugin/redmine_reminder'
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
    redirect_to '/settings/plugin/redmine_reminder'
  end

  private

  def log_request
    local_ip = RedmineReminder::Scheduler.local_ip rescue 'unknown'
    Rails.logger.info "[RedmineReminder] >>> Incoming #{request.method} #{request.fullpath} | request.ip=#{request.ip} | container.ip=#{local_ip} | action=#{action_name} | user=#{User.current&.login}"
  end

  def validate_smtp_settings!
    smtp = ActionMailer::Base.smtp_settings

    issues = []

    if smtp[:address].blank?
      issues << "SMTP服务器地址未配置"
    end

    if smtp[:port].blank?
      issues << "SMTP端口未配置"
    end

    if smtp[:user_name].blank?
      issues << "SMTP用户名未配置"
    end

    if smtp[:password].blank?
      issues << "SMTP密码未配置"
    end

    from_addr = smtp[:from] || Setting.mail_from
    if from_addr.blank?
      issues << "发件人地址未配置 (mail_from)"
      Rails.logger.warn "[RedmineReminder] From address: NOT CONFIGURED"
    end

    recipient = User.current.mail
    if recipient.blank?
      issues << "当前用户邮箱地址为空"
    end

    unless issues.empty?
      issues_text = issues.join("; ")
      Rails.logger.error "[RedmineReminder] SMTP Configuration Issues: #{issues_text}"
      raise StandardError, "邮件配置不完整: #{issues_text}"
    end

    true
  end

  def save_settings
    reminder_params = reminder_params_hash
    Setting.plugin_redmine_reminder = reminder_params

    flash[:notice] = l(:notice_successful_update)
    redirect_to reminders_settings_path
  rescue => e
    Rails.logger.error "[RedmineReminder] Save settings failed: #{e.class} - #{e.message}"
    flash[:error] = "#{e.class}: #{e.message}"
    redirect_to reminders_settings_path
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

    permitted_params['selected_projects'] = (permitted_params['selected_projects'] || []).reject(&:blank?).map(&:to_s)
    permitted_params['remind_before_days'] = permitted_params['remind_before_days'].to_i
    permitted_params['frequency_limit'] = permitted_params['frequency_limit'].to_i

    permitted_params
  end

end
