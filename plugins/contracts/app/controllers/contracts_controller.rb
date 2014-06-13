class ContractsController < ApplicationController
  unloadable
  before_filter :find_project, :authorize, :only => [:index, :show, :new, :create, :edit, :update, :destroy,
                                                     :add_time_entries, :assoc_time_entries_with_contract]
  def index
    @project = Project.find(params[:project_id])
    @contracts = Contract.order("start_date ASC").where(:project_id => sub_projects_ids(@project))
    if not @project.name.include?('$')
      @contracts.delete_if{|c| c.project.name.include?('$')}
    end
    if params["active"] == "true"
      @contracts.delete_if{|c| c.end_date < Time.now and c.amount_remaining.to_i == 0}
    end

    if params["remaining"] == "true"
      @contracts.delete_if{|c| c.amount_remaining.to_i <= 0}
    end

    if params["pending"] == "true"
      @contracts.delete_if{|c| c.amount_remaining.to_i >= 0}
    end

    if not params["ignore"].nil?
      @contracts.delete_if{|c| c.title.include? params["ignore"]}
    end

    if params["user"]
      @contracts.delete_if{|c| not c or not c.title.include? params["user"]}
    end

=begin
    @total_purchased_dollars = @project.total_amount_purchased
    @total_purchased_hours   = @project.total_hours_purchased
    @total_remaining_dollars = @project.total_amount_remaining
    @total_remaining_hours   = @project.total_hours_remaining
=end
    @total_purchased_dollars = @contracts.sum { |contract| contract.purchase_amount }
    @total_purchased_hours   = @contracts.sum { |contract| contract.hours_purchased }
    @total_remaining_dollars = @contracts.sum { |contract| contract.amount_remaining }
    @total_remaining_hours   = @contracts.sum { |contract| contract.hours_remaining }
  end

  def sub_projects_ids project
    sub_projects = [project.id]
    project.children.each do |p|
      sub_projects += sub_projects_ids p
    end
    sub_projects.flatten
  end

  def all
    raise "FORBIDDEN" if not User.current
    if params["user"]
      @user = User.find_by_login params["user"]
    else
      @user = User.current
    end
    #@projects = @user.projects.select { |project| @user.roles_for_project(project).
    #                                                    first.permissions.
    #                                                    include?(:view_all_contracts_for_project) }
    @contracts = Contract.all.sort{|c1, c2| c1.start_date - c2.start_date}
    @contracts.flatten!
    begin
      if @user
        @contracts.delete_if{|c| not c or c.project.name.include?('$') or not c.title.include? @user.login}
      elsif params["user"]
        @contracts.delete_if{|c| not c or c.project.name.include?('$') or not c.title.include? params["user"]}
      end
    rescue
      puts "Ignorando"
    end
    if params["active"] == "true"
      @contracts.delete_if{|c| c.end_date < Time.now and c.amount_remaining.to_i == 0}
    end

    if params["remaining"] == "true"
      @contracts.delete_if{|c| c.amount_remaining.to_i <= 0}
    end

    if params["pending"] == "true"
      @contracts.delete_if{|c| c.amount_remaining.to_i >= 0}
    end

    if not params["ignore"].nil?
      @contracts.delete_if{|c| c.title.include? params["ignore"]}
    end

    @total_purchased_dollars = @contracts.sum { |contract| contract.purchase_amount }
    @total_purchased_hours   = @contracts.sum { |contract| contract.hours_purchased }
    @total_remaining_dollars = @contracts.sum { |contract| contract.amount_remaining }
    @total_remaining_hours   = @contracts.sum { |contract| contract.hours_remaining }

    render "index"
  end

  def new
    @contract = Contract.new
    @project = Project.find(params[:project_id])
    @project.contracts.empty? ? num = "001" : num = ("%03d" % (@project.contracts.last.id + 1))
    @new_title = @project.identifier + "_Dev_" + num
  end

  def create
    @contract = Contract.new(params[:contract])
    if @contract.save
      flash[:notice] = l(:text_contract_saved)
      redirect_to :action => "show", :id => @contract.id
    else
      flash[:error] = "* " + @contract.errors.full_messages.join("</br>* ")
      redirect_to :action => "new", :id => @contract.id
    end
  end

  def show
    @contract = Contract.find(params[:id])
    @time_entries = @contract.time_entries.order("spent_on DESC")
		@members= []
		@time_entries.each { |entry| @members.append(entry.user) unless @members.include?(entry.user) }
  end

  def edit
    @contract = Contract.find(params[:id])
    @projects = Project.all
  end

  def update
    @contract = Contract.find(params[:id])
    params[:contract].delete(:project_id)
    if @contract.update_attributes(params[:contract])
      flash[:notice] = l(:text_contract_updated)
      redirect_to :action => "show", :id => @contract.id
    else
      flash[:error] = "* " + @contract.errors.full_messages.join("</br>* ")
      redirect_to :action => "edit", :id => @contract.id
    end
  end

  def destroy
    @contract = Contract.find(params[:id])
    if @contract.destroy
      flash[:notice] = l(:text_contract_deleted)
      if !params[:project_id].nil?
        redirect_to :action => "index", :project_id => params[:project_id]
      else
        redirect_to :action => "all"
      end
    else
      redirect_to(:back)
    end
  end

  def add_time_entries
    @contract = Contract.find(params[:id])
    @project = @contract.project
    @time_entries = @contract.project.time_entries_for_all_descendant_projects.sort_by! { |entry| entry.spent_on }
  end

  def assoc_time_entries_with_contract
    @contract = Contract.find(params[:id])
    @project = @contract.project
    time_entries = params[:time_entries]
    if time_entries != nil
      time_entries.each do |time_entry|
        updated_time_entry = TimeEntry.find(time_entry.first)
        updated_time_entry.contract = @contract
        updated_time_entry.save
      end
    end
		flash[:error] = l(:text_hours_over_contract, :hours_over => l_hours(-1 * @contract.hours_remaining)) unless @contract.hours_remaining >= 0
    redirect_to "/projects/#{@contract.project.id}/contracts/#{@contract.id}"
  end

  def contabilizar_pagamentos
      valor = params[:valor]
      projeto_id = params[:project_id]
      contracts_id = params[:contract_id]
      contrato_id = Contract.find(contracts_id)

      [12,23].each do |activity|
          timeEntrie = TimeEntry.new :user => User.find(29), :activity => TimeEntryActivity.find(activity)
          timeEntrie.project_id = projeto_id
          timeEntrie.spent_on = Time.now
          timeEntrie.comments = "Pagamento"
          timeEntrie.hours = activity == 12 ? (-1 * valor.to_f) : valor
          timeEntrie.contract = contrato_id
          timeEntrie.save!
      end

      contrato = Contract.find(contracts_id)
      contrato.purchase_amount += valor.to_f
      contrato.description += "\r\n#{Time.now.strftime('%d/%m/%Y')} - R$ #{'%.2f' % valor}"
      contrato.save!

      #Contabilizando o valor no projeto contabil ou prestação de contas
      tipo = Project.find(projeto_id).custom_field_values.first
      if tipo
        timeEntry = TimeEntry.new :user => User.find(5)
        timeEntry.spent_on = Time.now
        timeEntry.comments = "Pagamento #{contrato.project.name}"
        timeEntry.hours = (-1 * valor.to_f)
        if tipo == 'contabil'
            timeEntry.activity = TimeEntryActivity.find(46)
            timeEntry.project_id = 48
            timeEntry.contract = Contract.find(93)
        else
            timeEntry.activity = TimeEntryActivity.find(46)
            timeEntry.project_id = 11
            timeEntry.contract = Contract.find(17)
        end
        timeEntry.save!
      end

      redirect_to "/projects/#{projeto_id}/contracts/#{contracts_id}"
  end

  def gerar_pagamentos(ano=nil, mes=nil)
      ano ||= Time.now.year
      mes ||= Time.now.month

      project_id = params[:project_id]
      contract_id = params[:contract_id]

      users = {
          4=>{:hora=>6.0, :ciee=>550}, #Lucão
          22=>{:hora=>8.0, :ciee=>550}, #Tafarel
          27=>{:hora=>7.5, :ciee=>0},   #Mitrut
          32=>{:hora=>7.5, :ciee=>550}  #Rafagnin
      }

      horas = {}
      time_entries = TimeEntry.on_project(Project.find(10), true).spent_between(Time.mktime(ano,mes-1,1), Time.mktime(ano,mes,1))
      time_entries.group_by{|t|t.user_id}.each{|a,c| horas[a] = c.sum{|k| k.hours}}

      users.each do |k,v|
          t = TimeEntry.new :user => User.find(5), :contract => Contract.find(81), :activity => TimeEntryActivity.find(47)
          t.project_id = 11
          t.spent_on = Time.mktime(ano, mes, 5)
          t.comments = "Pagamento #{User.find(k).name} #{mes-1}/#{ano}"
          t.hours = horas[k] * v[:hora] - v[:ciee]
          t.save!
      end

      if contract_id
        redirect_to "/projects/#{project_id}/contracts/#{contract_id}"
      else
        redirect_to "/projects/#{project_id}/contracts"
      end
  end

  def gerar_pagamentos_administrativo(ano=nil, mes=nil)
      ano ||= Time.now.year
      mes ||= Time.now.month
      project_id = params[:project_id]
      contract_id = params[:contract_id]

      {5 => 46, 10 => 47}.each do |k, c|
          ct = Contract.find(c)
          t = TimeEntry.new :user => User.find(5), :contract => Contract.find(81), :activity => TimeEntryActivity.find(50)
          t.project_id = 11
          t.spent_on = Time.mktime(ano, mes, 1)
          t.comments = "Administrativo #{User.find(k).name} #{mes -1}/#{ano}"
          t.hours = -ct.amount_remaining
          t.save!
          ct.description += "#{Time.now.strftime('%d/%m/%Y')} - R$#{- ct.amount_remaining}"
          ct.purchase_amount -= ct.amount_remaining
          ct.save!
      end

      if contract_id
        redirect_to "/projects/#{project_id}/contracts/#{contract_id}"
      else
        redirect_to "/projects/#{project_id}/contracts"
      end
  end

  private

  def find_project
    #@project variable must be set before calling the authorize filter
    @project = Project.find(params[:project_id])
  end

end
