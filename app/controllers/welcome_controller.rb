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

  def usu_menu(menu, path, prm, prf)
    menu.delete_if {|k, v|
      if k.starts_with? 'tag_'
        false
      else
        st = prf[path + k] || prm
        if v.class == Hash
          usu_menu(v, path + k + '/', st, prf)
          borrar = true
          v.each {|k1, v1|
            unless k1.starts_with?('tag_')
              borrar = false
              break
            end
          }
          unless borrar
            lk = v.keys.last
            v.delete(lk) if lk.starts_with?('tag_')
          end

          borrar
        else # Es una opción normal
          st == 'x'
        end
      end
    }
  end

  def menu
    @v = Vista.new
    @v.data = {auto_comp: {ej: "empresa_id=#{@usu.empresa_def_id}", em: "id in (#{@usu.pref[:permisos][:emp].map{|e| e[0]}.join(',')})"}}
    @v.data[:eid] = @usu.empresa_def_id
    @v.save

    @menu = ''

    #hmenu = self.class.load_menu
    hmenu = Usuario.load_menu

    if @usu.admin
      gen_menu(hmenu)
    else
      ie = 0
      @usu.pref[:permisos][:emp].each {|e|
        if e[0] == @usu.empresa_def_id
          ie = e[0]
          break
        end
      }

      if ie == 0
        @usu.empresa_def_id = nil
        @usu.ejercicio_def_id = nil
        @usu.save
      end

      prm = 'x'
      iprf = nil
      @usu.pref[:permisos][:emp].each {|e|
        if e[0] == ie
          prm = e[1]
          iprf = e[2]
          break
        end
      }

      if iprf
        prf = Perfil.find(iprf)
        if prf
          usu_menu(hmenu, '/', prm, prf.data)
          gen_menu(hmenu)
        end
      end
    end

    @panel = @usu.pref['panel']
  end

  # El siguiente método está obsoleto. Ahora al cambiar de empresa se recarga la página completa.
=begin
  def ejercicio_en_menu
    if Ejercicio.where('empresa_id = ?', params[:eid]).count == 0
      @ajax << '$("#d-ejercicio").css("visibility", "hidden")'
    else
      @ajax << '$("#d-ejercicio").css("visibility", "visible");$("#ejercicio").focus();'
    end

    @dat[:eid] = params[:eid]
    @dat[:auto_comp][:ej] = "empresa_id=#{params[:eid]}"
  end
=end
end
