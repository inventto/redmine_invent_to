class TraineesPaymentsController < ApplicationController
  def index
    @ano ||= Time.now.year
    @mes ||= Time.now.month

    @users = {
      4=>{:hora=>6.0, :ciee=>550}, #Lucão
      22=>{:hora=>8.0, :ciee=>550}, #Tafarel
      27=>{:hora=>7.5, :ciee=>0},   #Mitrut
      32=>{:hora=>7.5, :ciee=>550}  #Rafagnin
    }

    @horas = {}
    time_entries = TimeEntry.on_project(Project.find(10), true).spent_between(Time.mktime(@ano,@mes-1,1), Time.mktime(@ano,@mes,1))
    time_entries.group_by{|t|t.user_id}.each{|a,c| @horas[a] = c.sum{|k| k.hours}}
  end


end
