class CreateReminderSettings < ActiveRecord::Migration[5.2]
  def change
    unless table_exists?(:reminder_settings)
      create_table :reminder_settings do |t|
        t.integer :remind_before_days, default: 7, null: false
        t.string :schedule_time, default: '09:00', null: false
        t.integer :frequency_limit, default: 25, null: false
        t.text :email_template
        t.text :selected_projects
        t.boolean :enabled, default: true
        t.timestamps
      end
    end
  end
end
