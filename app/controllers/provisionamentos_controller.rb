class ProvisionamentosController < ApplicationController
  def index
  end

  def importar
    ano ||= Time.now.year
    mes ||= Time.now.month + 1
    File.readlines('provisionamento.csv').each do |line|
      next if not line
      v = line.chomp.split(",")
      timeEntries = TimeEntry.new :user => User.find(5), :contract => Contract.find(v[2].to_i), :activity => TimeEntryActivity.find(v[3].to_i)
      timeEntries.user_id = 5
      timeEntries.project_id = (@project_id = v[1].to_i)
      timeEntries.spent_on = Time.mktime(ano, mes, v[0].to_i)
      timeEntries.comments = "#{v[4]} #{mes-1}/#{ano}"
      timeEntries.hours = v[5].to_f
      timeEntries.save!
    end

    redirect_to "/projects/#{@project_id}/contracts"
  end
end
