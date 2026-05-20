class ReminderSetting < ActiveRecord::Base
  # Note: This model is not actively used for settings management.
  # Settings are stored via Setting.plugin_redmine_reminder (hash in settings table)
  # This model is kept for backward compatibility with the default_template method.

  def self.default_template
    <<~TEMPLATE
      <h2>任务临期/逾期提醒</h2>
      <p>您好，</p>
      <p>您有以下任务需要关注：</p>
      <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
        <thead>
          <tr style="background-color: #f5f5f5;">
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">任务编号</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">任务名称</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">预计完成日期</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">状态</th>
          </tr>
        </thead>
        <tbody>
          {{#each tasks}}
          <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">{{issue_id}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">{{issue_name}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">{{due_date}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">{{status}}</td>
          </tr>
          {{/each}}
        </tbody>
      </table>
      <p>点击查看详情：<a href="{{project_url}}">{{project_url}}</a></p>
      <p style="color: #666; font-size: 12px;">此邮件由系统自动发送，请勿回复。</p>
    TEMPLATE
  end
end
