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

    @subject = I18n.t(:reminder_email_subject, project_name: Setting.app_title)
    @html_body = render_reminder_html

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

    Rails.logger.info "[RedmineReminder] Mailer Config:"
    Rails.logger.info "[RedmineReminder]   From: #{headers[:from]}"
    Rails.logger.info "[RedmineReminder]   To: #{headers[:to]}"
    Rails.logger.info "[RedmineReminder]   Subject: #{headers[:subject]}"

    mail(headers) do |format|
      format.html { render_reminder_html }
    end
  end

  private

  def mailer_from_address
    # 优先使用 Redmine 配置的 email_delivery from 地址
    if ActionMailer::Base.smtp_settings[:from].present?
      ActionMailer::Base.smtp_settings[:from]
    elsif Setting.emails_footer.present?
      # 从页脚提取发件地址
      Setting.emails_footer.match(/<([^>]+)>/)[1] rescue Setting.emails_from
    else
      Setting.emails_from || "redmine@#{Setting.host_name}"
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

    Rails.logger.debug "[RedmineReminder] Rendered HTML length: #{html.length} chars"

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
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">ID</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">任务</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">截止日期</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">状态</th>
          <th style="padding: 12px; border: 1px solid #ddd; text-align: left;">优先级</th>
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
    <p>此邮件由 Redmine 提醒插件自动发送，请勿直接回复。</p>
    <p>发送时间: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}</p>
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
