class ReminderMailer < ActionMailer::Base
  layout nil

  # 设置默认发件人地址
  def default_options
    @from_address = mailer_from_address
    {
      from: @from_address,
      mime_version: '1.0',
      content_type: 'text/html; charset=UTF-8'
    }
  end

  def send_reminder_email(user, tasks, template)
    @user = user
    @tasks = tasks
    @template = template

    # 根据收件人语言偏好设置 I18n locale
    locale = user.language.presence&.to_sym || I18n.default_locale

    I18n.with_locale(locale) do
      @subject = I18n.t(:reminder_email_subject, app_title: Setting.app_title)
      @html_body = render_reminder_html
    end

    # 显式设置所有必要的邮件头
    headers = {
      to: user.mail,
      subject: @subject,
      from: mailer_from_address,
      date: Time.now,
      mime_version: '1.0',
      content_type: 'text/html; charset=UTF-8',
      'X-Mailer' => 'RedmineReminder-Plugin'
    }

    mail(headers) do |format|
      format.html { @html_body }
    end
  end

  private

  def mailer_from_address
    # 优先使用 SMTP 配置中的 from 地址
    smtp_from = ActionMailer::Base.smtp_settings[:from]
    return format_from_address(smtp_from) if smtp_from.present?

    # 尝试从 Redmine 设置获取
    mail_from = Setting.mail_from
    return format_from_address(mail_from) if mail_from.present?

    # 回退方案：使用应用标题作为域名
    format_from_address("redmine@#{Setting.host_name}")
  end

  def format_from_address(email_addr)
    display_name = Setting.app_title.presence || 'Redmine'
    if email_addr.include?('<')
      # Already includes display name, return as-is
      email_addr
    else
      %("#{display_name}" <#{email_addr}>)
    end
  end

  def render_reminder_html
    html = @template.dup

    # 替换用户相关占位符
    html.gsub!('{{user_name}}', sanitize_html(@user.name))
    html.gsub!('{{user_email}}', sanitize_html(@user.mail))

    # 替换项目相关占位符
    project_name = @tasks.first&.dig(:project_name) || Setting.app_title
    html.gsub!('{{project_name}}', sanitize_html(project_name))

    # 替换项目 URL
    redmine_url = "#{Setting.protocol}://#{Setting.host_name}"
    html.gsub!('{{project_url}}', redmine_url)

    # 替换任务相关的所有占位符
    @tasks.each do |task|
      html.gsub!("{{issue_id}}", sanitize_html(task[:issue_id].to_s))
      html.gsub!("{{issue_name}}", sanitize_html(task[:issue_name].to_s))
      html.gsub!("{{due_date}}", sanitize_html(task[:due_date].to_s))
      html.gsub!("{{status}}", sanitize_html(task[:status].to_s))
      html.gsub!("{{priority}}", sanitize_html(task[:priority].to_s))
      html.gsub!("{{tracker}}", sanitize_html(task[:tracker].to_s))
      html.gsub!("{{assigned_to}}", sanitize_html(task[:assigned_to].to_s))
      html.gsub!("{{description}}", sanitize_html(task[:description].to_s))
      html.gsub!("{{overdue_days}}", task[:overdue_days].to_s)
      html.gsub!("{{issue_url}}", task[:url].to_s)
    end

    # 处理任务循环块
    task_html = build_task_rows
    html.gsub!(/\{\{#each tasks\}\}.*\{\{\/each\}\}/m, task_html)

    # 确保 HTML 结构完整
    html = wrap_html_body(html)

    html
  end

  def build_task_rows
    return '' if @tasks.blank?

    rows = @tasks.map do |task|
      status_color = task[:is_overdue] ? '#c00' : '#e67e22'
      <<-HTML.strip
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; background: #f9f9f9;">#{task[:issue_id]}</td>
        <td style="padding: 12px; border: 1px solid #ddd;">
          <a href="#{task[:url]}" style="color: #337ab7; text-decoration: none;">#{task[:issue_name]}</a>
        </td>
        <td style="padding: 12px; border: 1px solid #ddd;">#{task[:due_date]}</td>
        <td style="padding: 12px; border: 1px solid #ddd;">
          <span style="color: #{status_color}; font-weight: bold;">#{task[:status]}</span>
        </td>
        <td style="padding: 12px; border: 1px solid #ddd;">#{task[:priority]}</td>
      </tr>
      HTML
    end.join("\n")

    <<-HTML.strip
    <table style="width: 100%; border-collapse: collapse; margin: 15px 0;">
      <thead>
        <tr style="background: #337ab7; color: white;">
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">#{I18n.t(:reminder_email_table_issue_id)}</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">#{I18n.t(:reminder_email_table_issue_name)}</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">#{I18n.t(:reminder_email_table_due_date)}</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">#{I18n.t(:reminder_email_table_status)}</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">#{I18n.t(:reminder_email_table_priority)}</th>
        </tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    HTML
  end

  def wrap_html_body(content)
    # 如果内容已经是完整的 HTML 文档，直接返回
    return content if content.include?('<html') || content.include?('<!DOCTYPE')

    <<-HTML.strip
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{@subject}</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
  <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
    #{content}
  </div>
  <div style="margin-top: 20px; padding-top: 15px; border-top: 1px solid #ddd; font-size: 12px; color: #666;">
    <p>#{I18n.t(:reminder_email_footer_auto_sent)}</p>
    <p>#{I18n.t(:reminder_email_footer_sent_time, time: Time.now.strftime('%Y-%m-%d %H:%M:%S %Z'))}</p>
  </div>
</body>
</html>
    HTML
  end

  def sanitize_html(text)
    return '' if text.nil?
    # HTML 转义但保留链接
    ERB::Util.html_escape(text.to_s)
  end
end
