$(document).ready(function() {
  initProjectTree();
  initPreviewModal();
});

function initProjectTree() {
  // Handle parent checkbox change - toggle all descendants recursively
  $(document).on('change', '.project-checkbox[data-has-children="true"]', function() {
    var projectId = $(this).data('project-id');
    var isChecked = $(this).prop('checked');
    toggleDescendants(projectId, isChecked);
  });
}

function toggleDescendants(parentId, isChecked) {
  // Find direct children by data-parent-id attribute
  var $children = $('.project-row[data-parent-id="' + parentId + '"]');
  $children.each(function() {
    var $checkbox = $(this).find('.project-checkbox');
    $checkbox.prop('checked', isChecked);
    // Recursively toggle this child's descendants
    var childProjectId = $checkbox.data('project-id');
    if (childProjectId) {
      toggleDescendants(childProjectId, isChecked);
    }
  });
}

function toggleProjectChildren(projectId) {
  var $toggle = $('.toggle-children.' + projectId);
  var $parentRow = $toggle.closest('.project-row');

  if ($toggle.hasClass('icon-collapsed')) {
    $toggle.removeClass('icon-collapsed').addClass('icon-expended');
    // Show direct children
    $('.project-row[data-parent-id="' + projectId + '"]').show();
  } else {
    $toggle.removeClass('icon-expended').addClass('icon-collapsed');
    // Hide all descendants recursively
    hideDescendants(projectId);
  }
}

function hideDescendants(parentId) {
  var $children = $('.project-row[data-parent-id="' + parentId + '"]');
  $children.hide();
  $children.find('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  $children.each(function() {
    var childId = $(this).data('project-id');
    // Recursively hide children
    hideDescendants(childId);
  });
}

function expandAllProjects() {
  $('.toggle-children').removeClass('icon-collapsed').addClass('icon-expended');
  $('.project-row').show();
}

function collapseAllProjects() {
  $('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  // Hide all except root projects (projects with no parent)
  $('.project-row[data-parent-id]').hide();
}

function initPreviewModal() {
  // Close modal when clicking outside
  $(document).on('click', '#preview-modal', function(e) {
    if (e.target === this) {
      $(this).hide();
    }
  });
}

function previewTemplate() {
  var template = $('#reminder_setting_email_template').val();

  $.ajax({
    url: '/reminders/preview_template',
    method: 'POST',
    data: { template: template },
    beforeSend: function(xhr) {
      var token = $('meta[name="csrf-token"]').attr('content');
      if (token) {
        xhr.setRequestHeader('X-CSRF-Token', token);
      }
    },
    success: function(response) {
      $('#preview-content').html(response);
      $('#preview-modal').show();
    },
    error: function(xhr) {
      alert('Preview failed');
    }
  });
}
