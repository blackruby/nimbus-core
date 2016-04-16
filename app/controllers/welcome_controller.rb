class WelcomeController < ApplicationController
  require 'bcrypt'

  skip_before_action :ini_controller, only: [:index, :login]

  def index
    unless sesion_invalida
      redirect_to '/menu'
      return
    end
    I18n.locale = cookies[:locale] || session[:locale] || I18n.default_locale
  end

  def login
    usu = Usuario.find_by codigo: params[:usuario]
    if usu and usu.password_hash == BCrypt::Engine.hash_secret(params[:password], usu.password_salt)
      session[:uid] = usu.id
      session[:fec] = Time.now        #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)
      cookies.permanent[:locale] = session[:locale] = I18n.locale_available?(usu.pref[:locale]) ? usu.pref[:locale] : I18n.default_locale
      redirect_to '/menu'
    else
      session[:uid] = nil
      render 'index'
    end
  end

  def logout
    session[:uid] = nil
    render :nothing => true
  end

  def gen_menu(hm)
    hm.each {|k, v|
      if v.class == Hash
        @menu << "<li><span>#{nt(k)}</span><ul>"
        gen_menu(v)
        @menu << '</ul></li>'
      elsif k.starts_with? 'tag_'
        @menu << v
      else
        @menu << "<li class=menu-ref><a href=#{v}>#{nt(k)}</a></li>"
      end
    }
  end

  def menu
    @v = Vista.new
    @v.data = {auto_comp: {ej: "empresa_id=#{@usu.empresa_def_id}"}}
    @v.save

    @menu = ''
    hmenu = YAML.load(File.read('modulos/nimbus-core/menu.yml'))
    Dir.glob('modulos/*/menu.yml').each {|m|
      next if m == 'modulos/nimbus-core/menu.yml'
      hmenu.merge!(YAML.load(File.read(m)))
    }
    hmenu.deep_merge!(YAML.load(File.read('menu.yml'))) if File.exists?('menu.yml')
    gen_menu(hmenu)

    @panel = @usu.pref['panel']
  end

  def ejercicio_en_menu
    if Ejercicio.where('empresa_id = ?', params[:eid]).count == 0
      @ajax << '$("#d-ejercicio").css("visibility", "hidden")'
    else
      @ajax << '$("#d-ejercicio").css("visibility", "visible");$("#ejercicio").focus();'
    end

    @dat[:auto_comp][:ej] = "empresa_id=#{params[:eid]}"
  end
end
