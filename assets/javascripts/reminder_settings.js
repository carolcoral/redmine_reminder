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

function getRowDepth($row) {
  var padding = $row.css('padding-left');
  return parseInt(padding) || 0;
}

function getRowProjectId($row) {
  return $row.find('.project-checkbox').data('project-id');
}

function findChildRows($startRow) {
  var $children = [];
  var startDepth = getRowDepth($startRow);
  var $nextRow = $startRow.next();
  
  while ($nextRow.length > 0) {
    var nextDepth = getRowDepth($nextRow);
    if (nextDepth > startDepth) {
      $children.push($nextRow);
      $nextRow = $nextRow.next();
    } else {
      break;
    }
  }
  
  return $children;
}

function toggleDescendants(projectId, isChecked) {
  var $parentRow = $('.project-row').filter(function() {
    return $(this).find('.project-checkbox').data('project-id') == projectId;
  });
  
  var $children = findChildRows($parentRow);
  $children.forEach(function($child) {
    $child.find('.project-checkbox').prop('checked', isChecked);
    // Recursively handle nested children
    var $checkboxes = $child.find('.project-checkbox[data-has-children="true"]');
    $checkboxes.each(function() {
      toggleDescendants($(this).data('project-id'), isChecked);
    });
  });
}

function toggleProjectChildren(projectId) {
  var $parentRow = $('.project-row').filter(function() {
    return $(this).find('.project-checkbox').data('project-id') == projectId;
  });
  
  var $toggle = $parentRow.find('.toggle-children');
  var $children = findChildRows($parentRow);
  
  if ($toggle.hasClass('icon-collapsed')) {
    // Expand
    $toggle.removeClass('icon-collapsed').addClass('icon-expended');
    $children.forEach(function($child) {
      $child.show();
      // Update toggle icons for children with children
      var $childToggle = $child.find('.toggle-children');
      if ($childToggle.length > 0 && $child.find('.project-checkbox').data('has-children')) {
        // Keep as is (might need to check if it should be collapsed)
      }
    });
  } else {
    // Collapse
    $toggle.removeClass('icon-expended').addClass('icon-collapsed');
    // Hide all descendants recursively
    $children.forEach(function($child) {
      hideRowAndDescendants($child);
    });
  }
}

function hideRowAndDescendants($row) {
  $row.hide();
  var $childToggle = $row.find('.toggle-children');
  if ($childToggle.length > 0) {
    $childToggle.removeClass('icon-expended').addClass('icon-collapsed');
  }
  var $children = findChildRows($row);
  $children.forEach(function($child) {
    hideRowAndDescendants($child);
  });
}

function expandAllProjects() {
  $('.toggle-children').removeClass('icon-collapsed').addClass('icon-expended');
  $('.project-row').show();
}

function collapseAllProjects() {
  $('.toggle-children').removeClass('icon-expended').addClass('icon-collapsed');
  $('.project-row').each(function() {
    var padding = getRowDepth($(this));
    if (padding > 0) {
      $(this).hide();
    }
  });
}

function initPreviewModal() {
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
