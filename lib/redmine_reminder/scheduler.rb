module RedmineReminder
  class Scheduler
    def initialize(request_ip = nil)
      @settings = Setting.plugin_redmine_reminder || {}
      @executed_projects = Set.new
      @request_ip = request_ip
    end

    def enabled?
      @settings['plugin_enabled'] == '1' || @settings['plugin_enabled'] == true
    end

    def remind_before_days
      (@settings['remind_before_days'] || 3).to_i
    end

    def schedule_time
      @settings['schedule_time'] || '09:00'
    end

    def frequency_limit
      (@settings['frequency_limit'] || 7).to_i
    end

    def selected_project_ids
      projects = @settings['selected_projects'] || []
      projects.map(&:to_i)
    end

    def email_template
      @settings['email_template'].presence
    end

    def run
      return unless enabled?
      return unless check_ip_whitelist

      schedule_hour, schedule_minute = schedule_time_minutes
      now = Time.current

      unless now.hour == schedule_hour && now.min == schedule_minute
        Rails.logger.debug "RedmineReminder: Not scheduled time (current: #{now.strftime('%H:%M')}, scheduled: #{schedule_time})"
        return
      end

      process_all_projects
    end

    private

    def schedule_time_minutes
      parts = schedule_time.split(':')
      [parts[0].to_i, parts[1].to_i]
    end

    def process_all_projects
      project_ids = selected_project_ids

      if project_ids.empty?
        Project.active.includes(:members, :issues).find_each do |project|
          process_project(project)
        end
      else
        Project.where(id: project_ids)
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

      # 按 frequency_limit 分批发送，每批 N 个用户，等待 60 秒
      users_with_tasks = member_tasks.reject { |_user_id, tasks| tasks.empty? }
      total_users = users_with_tasks.size
      processed = 0

      while processed < total_users
        batch = users_with_tasks.drop(processed).take(frequency_limit)

        batch.each do |user_id, tasks|
          user = User.find_by(id: user_id)
          next unless user && user.active? && user.mail.present?

          send_reminder(user, tasks, project)
        end

        processed += batch.size
        Rails.logger.info "RedmineReminder: Sent #{batch.size} emails (total: #{processed}/#{total_users})"

        if processed < total_users
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
      reminder_threshold = remind_before_days.days
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
      template = email_template.presence || ReminderSetting.default_template

      begin
        mail_message = ReminderMailer.send_reminder_email(user, tasks, template)

        # 确保执行发送
        original_perform = ActionMailer::Base.perform_deliveries
        ActionMailer::Base.perform_deliveries = true

        result = mail_message.deliver_now

        # 恢复设置
        ActionMailer::Base.perform_deliveries = original_perform

        Rails.logger.info "RedmineReminder: Sent reminder to #{user.mail} (#{user.name}) for #{tasks.count} tasks in project #{project.name}"
        Rails.logger.debug "RedmineReminder: Email subject: #{mail_message.subject}"
      rescue Net::SMTPAuthenticationError => e
        Rails.logger.error "RedmineReminder: SMTP Authentication Failed for #{user.mail}: #{e.message}"
      rescue Net::SMTPFatalError => e
        Rails.logger.error "RedmineReminder: SMTP Fatal Error for #{user.mail}: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
        Rails.logger.error "RedmineReminder: Connection Failed for #{user.mail}: #{e.message}"
      rescue => e
        Rails.logger.error "RedmineReminder: Failed to send email to #{user.mail}: #{e.class} - #{e.message}"
      end
    end

    def issue_url(issue)
      "#{Setting.protocol}://#{Setting.host_name}/issues/#{issue.id}"
    end

    def check_ip_whitelist
      plugin_settings = Setting.plugin_redmine_reminder || {}
      whitelist = plugin_settings['ip_whitelist'].to_s.strip

      if whitelist.blank?
        return true
      end

      return true unless @request_ip.present?

      whitelist_ips = whitelist.split("\n").map(&:strip).reject(&:blank?)
      whitelist_ips.each do |entry|
        if entry.include?('/')
          return true if ip_in_cidr?(@request_ip, entry)
        else
          return true if @request_ip == entry
        end
      end

      Rails.logger.warn "RedmineReminder: IP #{@request_ip} not in whitelist, skipping reminder"
      false
    end

    def ip_in_cidr?(ip, cidr)
      return false unless ip.present? && cidr.include?('/')

      begin
        ip_parts = ip.split('.').map(&:to_i)
        return false unless ip_parts.length == 4

        mask_bits = cidr.split('/').last.to_i
        network_ip = cidr.split('/').first

        ip_int = ip_parts.reduce(0) { |sum, part| (sum << 8) + part }
        network_parts = network_ip.split('.').map(&:to_i)
        network_int = network_parts.reduce(0) { |sum, part| (sum << 8) + part }

        mask = (0xFFFFFFFF << (32 - mask_bits)) & 0xFFFFFFFF
        (ip_int & mask) == (network_int & mask)
      rescue
        false
      end
    end
  end
end
