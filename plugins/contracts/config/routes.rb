# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
#
match "trainees_payments/index" => "trainees_payments#index", :via => :get
match "projects/:project_id/contracts(/:contract_id)/payment_administrative" => "contracts#gerar_pagamentos_administrativo"
match "projects/:project_id/contracts(/:contract_id)/payment_intern" => "contracts#gerar_pagamentos"
get "provisionamentos/index"
match 'provisionamentos/gerar' => 'provisionamentos#importar', :via => :post
match 'projects/:project_id/contracts/:contract_id/payment' => 'contracts#contabilizar_pagamentos', :via => :post
match 'contracts/all'                                       => 'contracts#all',     :via => :get
match 'contracts/:id'                                       => 'contracts#destroy', :via => :delete
match 'contracts/:id/edit'                                  => 'contracts#edit',    :via => :get
match 'projects/:project_id/contracts'                      => 'contracts#index',   :via => :get
match 'projects/:project_id/contracts/new'                  => 'contracts#new',     :via => :get
match 'projects/:project_id/contracts/:id/edit'             => 'contracts#edit',    :via => :get
match 'projects/:project_id/contracts/:id'                  => 'contracts#show',    :via => :get
match 'projects/:project_id/contracts'                      => 'contracts#create',  :via => :post
match 'projects/:project_id/contracts/:id'                  => 'contracts#update',  :via => :put
match 'projects/:project_id/contracts/:id'                  => 'contracts#destroy', :via => :delete
match 'projects/:project_id/contracts/:id/add_time_entries' => 'contracts#add_time_entries', :via => :get
match 'projects/:project_id/contracts/:id/assoc_time_entries_with_contract' =>
        'contracts#assoc_time_entries_with_contract',
        :via => :put


