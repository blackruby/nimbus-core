Rails.application.routes.draw do
  ['usuarios','empresas','ejercicios','divisas','paises'].each{|c|
    get c => "#{c}#index"
    get "#{c}/new" => "#{c}#new"
    get "#{c}/:id/edit" => "#{c}#edit"
    ['validar', 'validar_cell', 'list', 'grabar', 'borrar', 'cancelar', 'fon_server'].each {|m|
      post "#{c}/#{m}" => "#{c}##{m}"
    }
  }

  root 'welcome#index'

  get 'histo/:modulo/:tabla/:id' => 'application#histo'
  get 'histo/:tabla/:id' => 'application#histo'
  post 'histo_list' => 'application#histo_list'
  post 'login' => 'welcome#login'
  get 'logout' => 'welcome#logout'
  get 'menu' => 'welcome#menu'
  get 'gi' => 'gi#gi'
  get 'gi/campos' => 'gi#campos'
  get 'gi/abrir/:file' => 'gi#abrir'
  get 'gi/edit/:file' => 'gi#edit'
  post 'gi/graba_fic' => 'gi#graba_fic'
  post 'gi/validar' => 'gi#validar'
  post 'gi/fon_server' => 'gi#fon_server'
  get 'application/auto' => 'application#auto'
  post 'savepanel' => 'application#savepanel'
  post 'noticias' => 'application#noticias'
end
