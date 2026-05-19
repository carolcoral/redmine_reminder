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
    Rails.logger.info "=========================================="

    # 验证 SMTP 配置
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
      Rails.logger.info "[RedmineReminder] Email Template Length: #{email_template.length} characters"

      # 生成邮件消息
      mail_message = ReminderMailer.send_reminder_email(
        User.current,
        test_tasks,
        email_template
      )

      # 详细的 SMTP 配置日志
      Rails.logger.info "[RedmineReminder] ====== SMTP CONFIGURATION ======"
      Rails.logger.info "[RedmineReminder] Delivery Method: #{mail_message.delivery_method.class.name}"
      Rails.logger.info "[RedmineReminder] SMTP Settings:"
      smtp_settings = ActionMailer::Base.smtp_settings
      Rails.logger.info "[RedmineReminder]   - Address: #{smtp_settings[:address]}"
      Rails.logger.info "[RedmineReminder]   - Port: #{smtp_settings[:port]}"
      Rails.logger.info "[RedmineReminder]   - Domain: #{smtp_settings[:domain]}"
      Rails.logger.info "[RedmineReminder]   - Authentication: #{smtp_settings[:authentication]}"
      Rails.logger.info "[RedmineReminder]   - Enable STARTTLS: #{smtp_settings[:enable_starttls_auto]}"
      Rails.logger.info "[RedmineReminder]   - From: #{smtp_settings[:from] || 'NOT SET'}"
      Rails.logger.info "[RedmineReminder]   - Raise Delivery Errors: #{ActionMailer::Base.raise_delivery_errors}"
      Rails.logger.info "[RedmineReminder]   - Perform Deliveries: #{ActionMailer::Base.perform_deliveries}"
      Rails.logger.info "[RedmineReminder] ====== MAIL MESSAGE DETAILS ======"
      Rails.logger.info "[RedmineReminder] From: #{mail_message.from.inspect}"
      Rails.logger.info "[RedmineReminder] To: #{mail_message.to.inspect}"
      Rails.logger.info "[RedmineReminder] Subject: #{mail_message.subject}"
      Rails.logger.info "[RedmineReminder] Message ID: #{mail_message.message_id}"
      Rails.logger.info "[RedmineReminder] Content Type: #{mail_message.content_type}"

      # 实际执行发送
      Rails.logger.info "[RedmineReminder] ====== SENDING EMAIL ======"

      # 确保 perform_deliveries 为 true
      original_perform = ActionMailer::Base.perform_deliveries
      ActionMailer::Base.perform_deliveries = true

      # 显式调用 deliver_now
      delivery_result = mail_message.deliver_now

      # 恢复原始设置
      ActionMailer::Base.perform_deliveries = original_perform

      Rails.logger.info "[RedmineReminder] Delivery Result: #{delivery_result.class}"
      Rails.logger.info "[RedmineReminder] Delivery Response: #{delivery_result.inspect}"

      # 验证发送是否真正执行
      if delivery_result
        # 检查是否有 delivery_handler
        if mail_message.delivery_handler
          Rails.logger.info "[RedmineReminder] Delivery handler: #{mail_message.delivery_handler}"
        end

        # 检查 deliveries 数组
        deliveries = mail_message.deliveries rescue []
        Rails.logger.info "[RedmineReminder] Deliveries array size: #{deliveries.size}"

        if deliveries.empty?
          Rails.logger.warn "[RedmineReminder] WARNING: Deliveries array is empty - email may not have been sent!"
        end
      end

      Rails.logger.info "[RedmineReminder] ====== TEST EMAIL SENT SUCCESSFULLY ======"
      Rails.logger.info "[RedmineReminder] Mailer Result Class: #{mail_message.class}"
      Rails.logger.info "[RedmineReminder] From: #{mail_message.from.inspect}"
      Rails.logger.info "[RedmineReminder] To: #{mail_message.to.inspect}"
      Rails.logger.info "[RedmineReminder] Subject: #{mail_message.subject}"
      Rails.logger.info "[RedmineReminder] Message ID: #{mail_message.message_id}"
      Rails.logger.info "[RedmineReminder] Test email sent successfully to #{User.current.mail}"
      Rails.logger.info "=========================================="

      flash[:notice] = l(:reminder_test_email_sent)

    rescue Net::SMTPAuthenticationError => e
      Rails.logger.error "[RedmineReminder] ====== SMTP AUTH ERROR ======"
      Rails.logger.error "[RedmineReminder] Error: #{e.class}: #{e.message}"
      Rails.logger.error "[RedmineReminder] This usually means:"
      Rails.logger.error "[RedmineReminder]   - Username or password is incorrect"
      Rails.logger.error "[RedmineReminder]   - SMTP server requires authentication"
      Rails.logger.error "[RedmineReminder]   - Account may be locked or disabled"
      Rails.logger.error "=========================================="
      flash[:error] = "#{l(:reminder_test_email_failed)}: SMTP认证失败 - 请检查用户名和密码 (#{e.message})"

    rescue Net::SMTPFatalError, Net::SMTPSyntaxError => e
      Rails.logger.error "[RedmineReminder] ====== SMTP FATAL ERROR ======"
      Rails.logger.error "[RedmineReminder] Error: #{e.class}: #{e.message}"
      Rails.logger.error "=========================================="
      flash[:error] = "#{l(:reminder_test_email_failed)}: SMTP错误 - #{e.message}"

    rescue Net::SMTPUnknownError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      Rails.logger.error "[RedmineReminder] ====== CONNECTION ERROR ======"
      Rails.logger.error "[RedmineReminder] Error: #{e.class}: #{e.message}"
      Rails.logger.error "[RedmineReminder] This usually means:"
      Rails.logger.error "[RedmineReminder]   - SMTP server address/port is incorrect"
      Rails.logger.error "[RedmineReminder]   - Firewall is blocking the connection"
      Rails.logger.error "[RedmineReminder]   - SMTP server is down"
      Rails.logger.error "=========================================="
      flash[:error] = "#{l(:reminder_test_email_failed)}: 连接失败 - 无法连接到邮件服务器 (#{e.message})"

    rescue => e
      Rails.logger.error "[RedmineReminder] ====== UNEXPECTED ERROR ======"
      Rails.logger.error "[RedmineReminder] Error Class: #{e.class}"
      Rails.logger.error "[RedmineReminder] Error Message: #{e.message}"
      Rails.logger.error "[RedmineReminder] Backtrace:"
      Rails.logger.error e.backtrace&.first(15)&.join("\n")
      Rails.logger.error "=========================================="

      flash[:error] = "#{l(:reminder_test_email_failed)}: #{e.message}"
    end

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

  def validate_smtp_settings!
    smtp = ActionMailer::Base.smtp_settings

    Rails.logger.info "[RedmineReminder] ====== SMTP VALIDATION ======"

    issues = []

    if smtp[:address].blank?
      issues << "SMTP服务器地址未配置"
    else
      Rails.logger.info "[RedmineReminder] SMTP Address: #{smtp[:address]}"
    end

    if smtp[:port].blank?
      issues << "SMTP端口未配置"
    else
      Rails.logger.info "[RedmineReminder] SMTP Port: #{smtp[:port]}"
    end

    if smtp[:user_name].blank?
      issues << "SMTP用户名未配置"
    else
      Rails.logger.info "[RedmineReminder] SMTP User: #{smtp[:user_name]}"
    end

    if smtp[:password].blank?
      issues << "SMTP密码未配置"
    else
      Rails.logger.info "[RedmineReminder] SMTP Password: [REDACTED]"
    end

    Rails.logger.info "[RedmineReminder] Authentication: #{smtp[:authentication] || 'none'}"
    Rails.logger.info "[RedmineReminder] Enable STARTTLS: #{smtp[:enable_starttls_auto] || false}"

    # 检查 from 地址
    from_addr = smtp[:from] || Setting.mail_from
    if from_addr.blank?
      issues << "发件人地址未配置 (mail_from)"
      Rails.logger.warn "[RedmineReminder] From address: NOT CONFIGURED"
    else
      Rails.logger.info "[RedmineReminder] From address: #{from_addr}"
    end

    # 检查收件人地址
    recipient = User.current.mail
    if recipient.blank?
      issues << "当前用户邮箱地址为空"
    else
      Rails.logger.info "[RedmineReminder] Recipient: #{recipient}"
    end

    Rails.logger.info "[RedmineReminder] ====== VALIDATION COMPLETE ======"

    unless issues.empty?
      issues_text = issues.join("; ")
      Rails.logger.error "[RedmineReminder] SMTP Configuration Issues: #{issues_text}"
      raise StandardError, "邮件配置不完整: #{issues_text}"
    end

    true
  end

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
