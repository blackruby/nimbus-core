class WelcomeController < ApplicationController
  require 'bcrypt'

  skip_before_action :ini_controller, only: [:index, :login]

  def index
    unless sesion_invalida
      redirect_to '/menu'
      return
    end
    I18n.locale = cookies[:locale] || session[:locale] || I18n.default_locale
    @assets_stylesheets = %w(welcome/index)
  end

  # Los status posibles son:
  # ------------------------
  # C Conexión correcta
  # D Desconexión
  # - Conexión errónea (no existe el usuario o la contraseña es errónea. Para saber si existe el usuario hay que mirar usuario_id)
  # * Intento de conexión en el periodo de bloqueo (La conexión no se produce aunque la contraseña sea válida)

  def log_acceso(uid, login, status)
    Acceso.create usuario_id: uid, login: login, fecha: Time.now, ip: request.remote_ip, status: status
  end

  def login
    @assets_stylesheets = %w(welcome/index)
    @seg_blq = 300  # Nº de segundos que un usuario permanecerá bloqueado si introduce tres veces mal la contraseña.

    @login = params[:usuario]

    usu = Usuario.find_by codigo: @login

    acs = Acceso.where('login=? AND fecha>?', @login, Time.now - @seg_blq).order('fecha desc').limit(3)
    nacs = acs.length
    if nacs > 2 and acs[0].status < 'A' and acs[1].status < 'A' and acs[2].status < 'A'
      log_acceso usu.try(:id), @login, '*'
      render 'bloqueo'
      return
    end

    if usu and usu.password_hash == BCrypt::Engine.hash_secret(params[:password], usu.password_salt)
      session[:uid] = usu.id
      session[:fec] = Time.now        #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)
      cookies.permanent[:locale] = session[:locale] = I18n.locale_available?(usu.pref[:locale]) ? usu.pref[:locale] : I18n.default_locale

      log_acceso usu.id, @login, 'C'

      redirect_to '/menu'
    else
      session[:uid] = nil

      log_acceso usu.try(:id), @login, '-'

      if nacs > 1 and acs[0].status < 'A' and acs[1].status < 'A'
        render 'bloqueo'
      else
        redirect_to '/'
      end
    end
  end

  def logout
    session[:uid] = nil

    log_acceso @usu.id, @usu.codigo, 'D'

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
    @assets_stylesheets = %w(welcome/menu)
    @assets_javascripts = %w(menu)

    @v = Vista.new
    @v.data = {auto_comp: {ej: "empresa_id=#{@usu.empresa_def_id}", em: (@usu.admin ? '' : "id in (#{@usu.pref[:permisos][:emp].map{|e| e[0]}.join(',')})")}}
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
        if iprf != 0
          prf = Perfil.find(iprf)
          if prf
            usu_menu(hmenu, '/', prm, prf.data)
            gen_menu(hmenu)
          end
        else
          usu_menu(hmenu, '/', prm, {})
          gen_menu(hmenu)
        end
      end
    end

    @panel = @usu.pref['panel']
  end

  def cambio_emej
    sql_exe "UPDATE usuarios SET empresa_def_id=#{params[:eid].empty? ? 'NULL' : params[:eid]}, ejercicio_def_id=#{params[:jid].empty? ? 'NULL' : params[:jid]} where id=#{@usu.id}"
    @ajax << 'location.reload();'
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
