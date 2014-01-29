class CreateIssueNumbers < ActiveRecord::Migration
  def change
    create_table :issue_numbers do |t|
      t.integer :issue_id
      t.integer :number
      t.string :origin, :default => 'default'
    end
  end
end
