module RedmineReminder
  module ReminderSettingsHelper
    def render_project_tree(projects, selected_project_ids)
      project_by_id = {}
      projects.each { |p| project_by_id[p.id] = p }
      root_projects = projects.select { |p| p.parent_id.nil? }.sort_by(&:lft)

      if root_projects.any?
        root_projects.map do |root|
          render_project_tree_node(root, selected_project_ids, projects, project_by_id)
        end.join.html_safe
      else
        content_tag(:p, l(:reminder_settings_no_projects), class: 'no-projects')
      end
    end

    private

    def render_project_tree_node(project, selected_proj_ids, all_projects, project_by_id)
      children = all_projects.select { |p| p.parent_id == project.id }.sort_by(&:lft)
      has_kids = children.any?
      checkbox_id = "project_#{project.id}"
      depth = get_project_depth(project, project_by_id)

      toggle_html = if has_kids
        link_to_function('', '',
          class: "toggle-children icon icon-collapsed",
          onclick: "toggleProjectChildren(#{project.id}); return false;",
          data: { project_id: project.id })
      else
        content_tag(:span, '', class: 'spacer')
      end

      label_html = label_tag(checkbox_id, class: 'project-label') do
        check_box_tag('reminder_setting[selected_projects][]',
          project.id,
          selected_proj_ids.include?(project.id),
          id: checkbox_id,
          class: 'project-checkbox',
          data: { project_id: project.id, has_children: has_kids }) +
        ' ' + h(project.name)
      end

      row_html = content_tag(:div, toggle_html + label_html,
        class: 'project-row',
        style: "padding-left: #{depth * 20}px;",
        data: { project_id: project.id })

      if has_kids
        children_html = content_tag(:div,
          children.map { |child| render_project_tree_node(child, selected_proj_ids, all_projects, project_by_id) }.join.html_safe,
          class: 'project-children',
          style: 'display: none;',
          data: { parent_id: project.id })
        row_html + children_html
      else
        row_html
      end
    end

    def get_project_depth(project, project_by_id)
      depth = 0
      p = project
      while p.parent_id.present?
        depth += 1
        p = project_by_id[p.parent_id]
        break unless p
      end
      depth
    end
  end
end
