Rails.application.routes.draw do
  ['usuarios','nimtest','empresas','ejercicios','divisas','paises','perfiles','bloqueos'].each{|c|
    next if Nimbus::Config["excluir_#{c}".to_sym]
    get c => "#{c}#index"
    get "#{c}/new" => "#{c}#new"
    get "#{c}/:id/edit" => "#{c}#edit"
    ['validar', 'validar_cell', 'list', 'grabar', 'borrar', 'fon_server'].each {|m|
      post "#{c}/#{m}" => "#{c}##{m}"
    }
  }

  root 'welcome#index'

  unless Nimbus::Config[:excluir_historicos]
    get 'histo/:modulo/:tabla/:id' => 'application#histo'
    get 'histo/:tabla/:id' => 'application#histo'
    post 'histo_list' => 'application#histo_list'
  end

  unless Nimbus::Config[:excluir_usuarios]
    get 'login' => 'welcome#index'
    post 'login' => 'welcome#login'
    get 'cambia_pass' => 'welcome#index'
    post 'cambia_pass' => 'welcome#cambia_pass'
    post 'welcome/fon_server' => 'welcome#fon_server'
    get 'logout' => 'welcome#logout'
    get 'menu' => 'welcome#menu'
    post 'pref_user' => 'usuarios#pref_user'
  end

  unless Nimbus::Config[:excluir_gi]
    get 'gi' => 'gi#gi'
    get 'giv' => 'gi#giv'
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
  end

  get 'application/auto' => 'application#auto'
  get 'nim_download' => 'application#nim_download'
  get 'nim_send_file' => 'application#nim_send_file'
  get 'osp' => 'osp#index'
  post 'osp/fon_server' => 'osp#fon_server'
  post 'application/destroy_vista' => 'application#destroy_vista'

  post 'noticias' => 'application#noticias'

  unless Nimbus::Config[:excluir_bus]
    get 'bus' => 'bus#bus'
    get 'bus/send' => 'bus#bus_send'
    post 'bus/list' => 'bus#list'
    post 'bus/fon_server' => 'bus#fon_server'
  end

  get 'nimbus_help' => 'nimbus_help#index'
end
