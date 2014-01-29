class Contract < ActiveRecord::Base
  unloadable
  belongs_to :project 
  has_many   :time_entries
  validates_presence_of :title, :start_date, :end_date, :agreement_date, 
                        :purchase_amount, :hourly_rate, :project_id
  validates :title, :uniqueness => { :case_sensitive => false }
  #validates :start_date, :is_after_agreement_date => true
  validates :end_date, :is_after_start_date => true
  before_destroy { |contract| contract.time_entries.clear }

  def hours_purchased
    self.purchase_amount / self.hourly_rate
  end
  
  def hours_spent
    self.time_entries.sum { |time_entry| time_entry.hours }
  end

  def amount_spent
    self.time_entries.sum do |time_entry|
      amount = time_entry.cost
      if amount == 0
        amount = time_entry.hours * (Rate.amount_for(time_entry.user, project, time_entry.spent_on.strftime("%Y-%m-%d")) || self.hourly_rate)
	time_entry.cost = amount
        time_entry.save!
      end
      amount
    end
  end
  
  def amount_remaining
    self.purchase_amount - self.amount_spent
  end

  def hours_remaining
    (self.purchase_amount - self.amount_spent) / self.hourly_rate
  end

	def exceeds_remaining_hours_by?(hours=0)
			hours_over = hours - self.hours_remaining
			hours_over > 0 ? hours_over : 0
	end

  private
    
    def remove_contract_id_from_associated_time_entries
      self.time_entries.each do |time_entry|
        time_entry.contract_id = nil
        time_entry.save
      end
    end
end
