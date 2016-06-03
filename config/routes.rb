Rails.application.routes.draw do
  ['usuarios','nimtest','empresas','ejercicios','divisas','paises'].each{|c|
    get c => "#{c}#index"
    get "#{c}/new" => "#{c}#new"
    get "#{c}/:id/edit" => "#{c}#edit"
    ['validar', 'validar_cell', 'list', 'grabar', 'borrar', 'fon_server'].each {|m|
      post "#{c}/#{m}" => "#{c}##{m}"
    }
  }

  root 'welcome#index'

  get 'histo/:modulo/:tabla/:id' => 'application#histo'
  get 'histo/:tabla/:id' => 'application#histo'
  post 'histo_list' => 'application#histo_list'

  post 'login' => 'welcome#login'
  post 'welcome/fon_server' => 'welcome#fon_server'
  get 'logout' => 'welcome#logout'
  get 'menu' => 'welcome#menu'

  get 'gi' => 'gi#gi'
  get 'gi/new' => 'gi#new'
  get 'gi/new/:modelo' => 'gi#new'
  get 'gi/edit/:modulo/:formato' => 'gi#edita'
  get 'gi/run/:modulo/:formato' => 'gi#edit'
  get 'gi/abrir' => 'gi#abrir'
  get 'gi/campos' => 'gi#campos'
  post 'gi/graba_fic' => 'gi#graba_fic'
  post 'gi/validar' => 'gi#validar'
  post 'gi/grabar' => 'gi#grabar'
  post 'gi/fon_server' => 'gi#fon_server'

  get 'application/auto' => 'application#auto'
  post 'application/destroy_vista' => 'application#destroy_vista'

  post 'pref_user' => 'usuarios#pref_user'
  post 'noticias' => 'application#noticias'

  get 'bus' => 'bus#bus'
  get 'bus/send' => 'bus#bus_send'
  post 'bus/list' => 'bus#list'
  post 'bus/fon_server' => 'bus#fon_server'
end
