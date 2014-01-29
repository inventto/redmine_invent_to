#ActionController::Routing::Routes.draw do |map|
  match 'rates/create'                                       => 'rates#create'
  match 'rates/edit'                                       => 'rates#edit'
  match 'rates'                                       => 'rates#index'
  match 'rate_caches' => 'rate_caches#update'
  #connect 'rate_caches', :conditions => {:method => :put}, :controller => 'rate_caches', :action => 'update'
#end
