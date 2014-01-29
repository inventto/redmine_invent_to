class AddRepositoryToIssueNumber < ActiveRecord::Migration
  def change
    change_column :issue_numbers, :repository_id, :integer
  end
end
