class ChangeDataTypeForComments < ActiveRecord::Migration
  def self.up
    change_table :time_entries do |t|
      t.change :comments, :text
    end
  end

  def self.down
    change_table :time_entries do |t| 
      t.change :comments, :string
    end 
  end
end
