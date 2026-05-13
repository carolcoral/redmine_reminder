$(document).ready(function() {
  initTimePicker();
  initProjectTree();
  initTemplatePreview();
});

function initTimePicker() {
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
  $(document).on('change', '.project-checkbox[data-has-children="true"]', function() {
    var projectId = $(this).val();
    var isChecked = $(this).prop('checked');

    $('[data-parent-id="' + projectId + '"]').find('.project-checkbox').prop('checked', isChecked);
  });
}

function toggleProjectChildren(projectId) {
  var $toggle = $('.toggle-children.' + projectId);
  var $children = $('[data-parent-id="' + projectId + '"]');

  if ($toggle.find('.icon').hasClass('icon-collapsed')) {
    $toggle.find('.icon').removeClass('icon-collapsed').addClass('icon-expended');
    $children.show();
  } else {
    $toggle.find('.icon').removeClass('icon-expended').addClass('icon-collapsed');
    $children.hide();
  }
}

function selectAllProjects() {
  $('.project-checkbox').prop('checked', true);
}

function deselectAllProjects() {
  $('.project-checkbox').prop('checked', false);
}

function initTemplatePreview() {
  // Preview functionality is handled by previewTemplate function
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
      $('#preview-modal .modal-body').html(response);
      $('#preview-modal').modal('show');
    },
    error: function(xhr) {
      alert('Preview failed: ' + (xhr.responseJSON && xhr.responseJSON.error || 'Unknown error'));
    }
  });
}
