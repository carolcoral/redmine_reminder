class ReminderSetting < ActiveRecord::Base
  validates :remind_before_days, :schedule_time, :frequency_limit, presence: true
  validates :remind_before_days, numericality: { only_integer: true, greater_than: 0 }
  validates :frequency_limit, numericality: { only_integer: true, greater_than: 0 }

  serialize :selected_projects, Array

  before_save :ensure_selected_projects_array
  before_validation :ensure_default_values

  def self.setting
    first_or_create!(
      remind_before_days: 7,
      schedule_time: '09:00',
      frequency_limit: 25,
      email_template: default_template,
      selected_projects: [],
      enabled: true
    )
  end

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

  def selected_project_ids
    return [] if selected_projects.blank?
    selected_projects.map(&:to_i)
  end

  def schedule_time_minutes
    return [0, 0] unless schedule_time.present?
    parts = schedule_time.split(':')
    [parts[0].to_i, parts[1].to_i]
  end

  private

  def ensure_selected_projects_array
    self.selected_projects = [] if selected_projects.nil?
    self.selected_projects = selected_projects.map(&:to_i).uniq
  end

  def ensure_default_values
    self.schedule_time = '09:00' if schedule_time.blank?
    self.remind_before_days = 7 if remind_before_days.blank?
    self.frequency_limit = 25 if frequency_limit.blank?
    self.email_template = self.class.default_template if email_template.blank?
    self.selected_projects ||= []
  end
end
