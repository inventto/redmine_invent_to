module Contracts
  require_dependency 'time_entry'

  module TimeEntryPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do 
        unloadable
        belongs_to :contract
        safe_attributes 'contract_id'
        before_save :set_last_contract
      end
    end
    module InstanceMethods
      def set_last_contract
        if not self.contract and project.contracts.length > 0
          contracts = project.contracts.find :all, :conditions => ["title like '%#{user.login}%' and start_date < ? ", Time.now], :order => "start_date desc"
          if contracts and contracts.length > 0
            self.contract = contracts.first
          end
          if not self.contract
            contracts = project.contracts.find :all, :conditions => ["start_date < ? ", Time.now], :order => "start_date desc"
            self.contract = contracts.first
          end
        end
      end
    end
  end
  TimeEntry.send(:include, TimeEntryPatch)
end

