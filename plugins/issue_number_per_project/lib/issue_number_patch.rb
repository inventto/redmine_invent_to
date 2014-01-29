module IssueNumberPatch
  def self.included(issue)
    issue.send(:include, InstanceMethods)
    issue.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      has_one :issue_number
      has_one :repository
      after_create :create_issue_number
      attr_accessor :number, :origin, :repository
    end
  end

  module InstanceMethods	

    def create_issue_number
      logger.warn "creating issue number for #{id} with number #{self.number}"
      p "creating issue number for #{id} with number #{self.number}"
      if not self.number or self.number.blank?
        issue_number = IssueNumber.new :issue => self
      else
        issue_number = IssueNumber.new :issue => self, :number => self.number, :origin => self.origin, :repository => self.repository
      end
      issue_number.save
    end
  end
end
