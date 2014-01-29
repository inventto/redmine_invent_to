class IssueNumber < ActiveRecord::Base
  unloadable
  attr_accessible :issue, :number, :origin, :repository 

  belongs_to :issue
  belongs_to :repository

  before_create :generate_sequence

  def generate_sequence
    if self.number.nil? or self.number.to_i == 0
    	issue_number = IssueNumber.joins(:issue).joins("JOIN projects ON issues.project_id=projects.id").where("issues.project_id = ? and (issue_numbers.repository_id is null or issue_numbers.repository_id = ?)", issue.project_id, issue.repository_id).order("issues.id")
        if issue_number.last
   	  self.number = issue_number.last.number + 1    		    
        else
          self.number = 1
        end
    end
  end
end
