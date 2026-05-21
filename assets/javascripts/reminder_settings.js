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
  var $childrenContainer = $('.project-children[data-parent-id="' + parentId + '"]');
  if ($childrenContainer.length === 0) return;
  
  // Check/uncheck all checkboxes in this container
  $childrenContainer.find('.project-checkbox').prop('checked', isChecked);
  
  // Recursively handle nested children
  $childrenContainer.find('.project-checkbox[data-has-children="true"]').each(function() {
    toggleDescendants($(this).data('project-id'), isChecked);
  });
}

function toggleProjectChildren(projectId) {
  var $toggle = $('.toggle-children[data-project-id="' + projectId + '"]');
  var $childrenContainer = $('.project-children[data-parent-id="' + projectId + '"]');
  
  if ($childrenContainer.length === 0) return;
  
  if ($toggle.hasClass('icon-collapsed')) {
    // Expand
    $toggle.removeClass('icon-collapsed').addClass('icon-expended');
    $childrenContainer.show();
  } else {
    // Collapse
    $toggle.removeClass('icon-expended').addClass('icon-collapsed');
    $childrenContainer.hide();
    // Also collapse all nested children
    $childrenContainer.find('.project-children').hide();
    $childrenContainer.find('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  }
}

function expandAllProjects() {
  $('.toggle-children').removeClass('icon-collapsed').addClass('icon-expended');
  $('.project-children').show();
}

function collapseAllProjects() {
  $('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  $('.project-children').hide();
}

function initPreviewModal() {
  $(document).on('click', '#preview-modal', function(e) {
    if (e.target === this) {
      $(this).hide();
    }
  });
}

function previewTemplate() {
  var template = $('#settings_plugin_email_template').val();

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
