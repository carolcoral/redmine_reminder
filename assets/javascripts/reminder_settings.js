$(document).ready(function() {
  initTimeInput();
  initProjectTree();
  initPreviewModal();
});

function initTimeInput() {
  var timeInput = document.getElementById('reminder_setting_schedule_time');
  if (timeInput && !timeInput.readOnly) {
    timeInput.addEventListener('input', function(e) {
      var value = this.value;
      var numbers = value.replace(/\D/g, '');
      if (numbers.length >= 2) {
        var hours = numbers.substring(0, 2);
        var minutes = numbers.substring(2, 4);
        if (parseInt(hours) > 23) hours = '23';
        if (parseInt(minutes) > 59) minutes = '59';
        this.value = hours + ':' + (minutes || '00');
      }
    });
  }
}

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
  var $parentRow = $('.project-row[data-project-id="' + projectId + '"]');

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
  $children.each(function() {
    var childId = $(this).data('project-id');
    // Reset toggle icon to collapsed
    $('.toggle-children.' + childId).removeClass('icon-expended').addClass('icon-collapsed');
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
  // Hide all except root projects (parent_id is null or empty)
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
