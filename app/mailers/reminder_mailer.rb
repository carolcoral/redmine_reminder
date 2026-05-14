class ReminderMailer < ActionMailer::Base
  layout nil

  def send_reminder_email(user, tasks, template)
    @user = user
    @tasks = tasks
    @template = template

    @subject = I18n.t(:reminder_email_subject, project_name: Setting.app_title)
    @html_body = render_reminder_html

    mail(to: user.mail, subject: @subject) do |format|
      format.html { @html_body }
    end
  end

  private

  def render_reminder_html
    html = @template.dup

    html.gsub!('{{user_name}}', @user.name)
    html.gsub!('{{user_email}}', @user.mail)

    project_name = @tasks.first&.dig(:project_name) || Setting.app_title
    html.gsub!('{{project_name}}', project_name)

    redmine_url = Setting.protocol + '://' + Setting.host_name
    html.gsub!('{{project_url}}', redmine_url)

    task_html = ''
    @tasks.each do |task|
      task_item = <<-HTML
        <tr>
          <td style="padding: 12px; border: 1px solid #ddd;">#{task[:issue_id]}</td>
          <td style="padding: 12px; border: 1px solid #ddd;">
            <a href="#{task[:url]}">#{task[:issue_name]}</a>
          </td>
          <td style="padding: 12px; border: 1px solid #ddd;">#{task[:due_date]}</td>
          <td style="padding: 12px; border: 1px solid #ddd;">
            <span style="color: #{task[:is_overdue] ? '#c00' : '#e67e22'};">
              #{task[:status]}
            </span>
          </td>
        </tr>
      HTML
      task_html << task_item
    end

    html.gsub!(/\{\{#each tasks\}\}.*\{\{\/each\}\}/m, task_html)

    html
  end
end
