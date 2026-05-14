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
  // Find direct children container by looking for the next sibling .project-children
  var $parentRow = $('.project-row[data-project-id="' + parentId + '"]');
  var $childrenContainer = $parentRow.next('.project-children');
  
  if ($childrenContainer.length === 0) {
    // Try finding children within the same parent container
    $childrenContainer = $parentRow.closest('.project-children').find('.project-row[data-project-id="' + parentId + '"]').next('.project-children');
  }
  
  $childrenContainer.find('.project-checkbox').prop('checked', isChecked);
  // Also recursively handle nested children
  $childrenContainer.find('.project-checkbox[data-has-children="true"]').each(function() {
    toggleDescendants($(this).data('project-id'), isChecked);
  });
}

function toggleProjectChildren(projectId) {
  var $toggle = $('.toggle-children[data-project-id="' + projectId + '"]');
  var $parentRow = $toggle.closest('.project-row');
  var $childrenContainer = $parentRow.next('.project-children');

  if ($childrenContainer.length > 0 && $childrenContainer.is(':hidden')) {
    $toggle.removeClass('icon-collapsed').addClass('icon-expended');
    $childrenContainer.show();
  } else if ($childrenContainer.length > 0) {
    $toggle.removeClass('icon-expended').addClass('icon-collapsed');
    hideAllDescendants($childrenContainer);
  }
}

function hideAllDescendants($container) {
  $container.hide();
  $container.find('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  $container.find('.project-children').each(function() {
    hideAllDescendants($(this));
  });
}

function expandAllProjects() {
  $('.toggle-children').removeClass('icon-collapsed').addClass('icon-expended');
  $('.projects-tree .project-children').show();
}

function collapseAllProjects() {
  $('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  $('.projects-tree > .project-children').find('.project-children').hide();
  $('.projects-tree > .project-children > .project-row + .project-children').hide();
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
