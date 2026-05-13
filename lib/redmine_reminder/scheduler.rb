module RedmineReminder
  class Scheduler
    def initialize
      @setting = ReminderSetting.setting
      @executed_projects = Set.new
    end

    def run
      return unless @setting.enabled?

      schedule_hour, schedule_minute = @setting.schedule_time_minutes
      now = Time.current

      unless now.hour == schedule_hour && now.min == schedule_minute
        Rails.logger.debug "RedmineReminder: Not scheduled time (current: #{now.strftime('%H:%M')}, scheduled: #{@setting.schedule_time})"
        return
      end

      process_all_projects
    end

    private

    def process_all_projects
      selected_project_ids = @setting.selected_project_ids

      if selected_project_ids.empty?
        Project.active.includes(:members, :issues).find_each do |project|
          process_project(project)
        end
      else
        Project.where(id: selected_project_ids)
              .active
              .includes(:members, :issues)
              .find_each do |project|
          process_project(project)
        end
      end
    end

    def process_project(project)
      return if @executed_projects.include?(project.id)

      Rails.logger.info "RedmineReminder: Processing project #{project.name}"

      project_members = get_all_project_members(project)
      member_tasks = build_member_tasks(project, project_members)

      return if member_tasks.empty?

      batches = member_tasks.each_slice(@setting.frequency_limit).to_a

      batches.each_with_index do |batch, index|
        batch.each do |user_id, tasks|
          next if tasks.empty?

          user = User.find_by(id: user_id)
          next unless user && user.active? && user.mail.present?

          send_reminder(user, tasks, project)
        end

        unless index == batches.size - 1
          sleep 60
        end
      end

      @executed_projects.add(project.id)

      Rails.logger.info "RedmineReminder: Completed processing project #{project.name}"
    end

    def get_all_project_members(project)
      members = {}

      project.members.includes(:user, :roles).where("users.status = ?", User::STATUS_ACTIVE).find_each do |member|
        next if member.user.nil? || !member.user.active?
        next unless member.user.mail.present?

        members[member.user.id] ||= []
        members[member.user.id] << member
      end

      project.descendants.active.find_each do |child|
        child.members.includes(:user, :roles).where("users.status = ?", User::STATUS_ACTIVE).find_each do |member|
          next if member.user.nil? || !member.user.active?
          next unless member.user.mail.present?

          members[member.user.id] ||= []
          members[member.user.id] << member unless members[member.user.id].include?(member)
        end
      end

      members
    end

    def build_member_tasks(project, member_tasks)
      result = {}
      reminder_threshold = @setting.remind_before_days.days
      today = Date.today
      completed_statuses = IssueStatus.where(is_closed: true).pluck(:id)
      project_and_descendants_ids = [project.id] + project.descendants.pluck(:id)

      member_tasks.each do |user_id, _memberships|
        result[user_id] = []

        user = User.find_by(id: user_id)
        next unless user

        user.issues
            .where(project_id: project_and_descendants_ids)
            .where.not(status_id: completed_statuses)
            .where("due_date IS NOT NULL")
            .includes(:project, :status, :priority, :tracker, :assigned_to)
            .find_each do |issue|
          due_date = issue.due_date.to_date
          threshold_date = due_date - reminder_threshold

          if threshold_date <= today
            is_overdue = due_date < today
            overdue_days = (today - due_date).to_i

            result[user_id] << {
              issue_id: "##{issue.id}",
              issue_name: issue.subject,
              due_date: due_date.strftime('%Y-%m-%d'),
              status: issue.status.name,
              priority: issue.priority.name,
              tracker: issue.tracker.name,
              assigned_to: issue.assigned_to&.name || '',
              description: issue.description.to_s.truncate(200),
              overdue_days: overdue_days,
              is_overdue: is_overdue,
              project_name: issue.project.name,
              url: issue_url(issue)
            }
          end
        end
      end

      result
    end

    def send_reminder(user, tasks, project)
      template = @setting.email_template.presence || ReminderSetting.default_template

      begin
        ReminderMailer.send_reminder_email(user, tasks, template).deliver_now
        Rails.logger.info "RedmineReminder: Sent reminder to #{user.mail} for #{tasks.count} tasks"
      rescue => e
        Rails.logger.error "RedmineReminder: Failed to send email to #{user.mail}: #{e.message}"
      end
    end

    def issue_url(issue)
      "#{Setting.protocol}://#{Setting.host_name}/issues/#{issue.id}"
    end
  end
end
