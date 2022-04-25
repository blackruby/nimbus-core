unless Nimbus::Config[:excluir_usuarios]

class WelcomeController < ApplicationController
  require 'bcrypt'

  skip_before_action :ini_controller, only: [:index, :login, :cambia_pass, :api_login, :pass_olvido, :a2p]

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
  # L Conexión correcta pero rechazada por falta de licencias
  # D Desconexión
  # - Conexión errónea (no existe el usuario o la contraseña es errónea. Para saber si existe el usuario hay que mirar usuario_id)
  # * Intento de conexión en el periodo de bloqueo (La conexión no se produce aunque la contraseña sea válida)
  # B Intento de conexión de un usuario de baja
  # I Intento de conexión desde una IP no válida
  # P Pin erróneo en autentificación en 2 pasos (a2p)
  # M Método de acceso incorrecto (un usuario WEB a trvés de la API o viceversa)
  # X contraseña caducada en acceso vía API

  def log_acceso(uid, login, status, web)
    Acceso.create usuario_id: uid, login: login, fecha: @ahora, ip: "#{web ? '' : '*'}#{request.remote_ip}", status: status
  end
        
  def login_ok(usu)
    if Licencia.get_licencia(usu.id, session[:session_id])
      session[:uid] = usu.id
      session[:fec] = @ahora          #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)
      cookies.permanent[:locale] = session[:locale] = I18n.locale_available?(usu.pref[:locale]) ? usu.pref[:locale] : I18n.default_locale

      log_acceso usu.id, usu.codigo, 'C', true
      true
    else
      log_acceso usu.id, usu.codigo, 'L', true
      false
    end
  end

  def render_log_fin(pag)
    if pag == 'menu'
      flash[:login] = true
      redirect_to '/menu'
    elsif %w(cambia_pass nolic).include? pag
      render pag
    else
      redirect_to '/'
    end
  end

  def render_log(pag = '', usu = nil)
    if Nimbus::Config[:a2p]
      flash[:pag] = pag
      if pag != ''
        flash[:uid] = usu.id
        if usu.email.present?
          flash[:pin] = format('%04d', rand(10000))
          UsuariosMailer.send_pin(usu, flash[:pin]).deliver_now
        else
          logger.fatal "######## ERROR: a2p activado y usuario #{usu.codigo} sin e-mail"
        end
      end
      render 'a2p'
    else
      render_log_fin pag
    end
  end

  def a2p
    @assets_stylesheets = %w(welcome/index)

    @ahora = Nimbus.now
    pag = flash[:pag]
    if pag != ''
      usu = Usuario.find(flash[:uid])
      if params[:pin] == flash[:pin]
        @login = usu.codigo
        pag = 'nolic' unless login_ok(usu)
      else
        log_acceso usu.id, usu.codigo, 'P', true
        pag = ''
      end
    end
    render_log_fin pag
  end

  def login(web = true)
    @login = params[:usuario].to_s

    @assets_stylesheets = %w(welcome/index)
    @assets_javascripts = %w(welcome/bloqueo) unless Nimbus::Config[:a2p]

    @seg_blq = 300  # Nº de segundos que un usuario permanecerá bloqueado si introduce tres veces mal la contraseña.

    @ahora = Nimbus.now

    usu = Usuario.find_by codigo: @login

    if usu
      # Control de que el usuario accede por la vía correcta (web o API)
      if web && usu.api || !web && !usu.api
        log_acceso usu.id, @login, 'M', web
        if web
          #redirect_to '/'
          render_log
          return
        else
          return 'Acceso no autorizado.'
        end
      end

      # Control de que el usuario no esté de baja
      if usu.fecha_baja and usu.fecha_baja <= @ahora
        log_acceso usu.id, @login, 'B', web
        if web
          render_log
          return
        else
          return 'El usuario ha sido dado de baja.'
        end
      end

      # Control de acceso por IP
      usu.ips.strip!
      unless usu.ips.empty?
        bloqueo = true
        usu.ips.split(',').each {|ip|
          ip = ip.strip
          begin
            if IPAddr.new(ip).include?(request.remote_ip)
              bloqueo = false
              break
            end
          rescue
          end
        }
        if bloqueo
          log_acceso usu.id, @login, 'I', web
          if web
            render_log
            return
          else
            return 'IP no autorizada.'
          end
        end
      end
    end

    unless web && Nimbus::Config[:a2p]
      acs = Acceso.where('login=? AND fecha>?', @login, @ahora - @seg_blq).order('fecha desc').limit(3)
      nacs = acs.length
      if nacs > 2 and acs[0].status < 'A' and acs[1].status < 'A' and acs[2].status < 'A'
        log_acceso usu.try(:id), @login, '*', web
        @seg_blq -= (@ahora - acs[1].fecha).round
        if web
          render 'bloqueo'
          return
        else
          return 'Usuario bloqueado. Espere 5 minutos.'
        end
      end
    end

    if usu && usu.password_hash.present? && usu.password_hash == BCrypt::Engine.hash_secret(params[:password], usu.password_salt)
      if web && !Nimbus::Config[:a2p] && !login_ok(usu)
        render 'nolic'
        return
      end

      # Comprobar si el password ha expirado o password_fec_mod es nil (primer login) y solicitar uno nuevo o llevar al menú

      if usu.password_fec_mod.nil? or (usu.num_dias_validez_pass.to_i != 0 and (@ahora - usu.password_fec_mod)/86400 > usu.num_dias_validez_pass)
        if web
          render_log 'cambia_pass', usu
        else
          log_acceso usu.id, @login, 'X', web
          return 'Contraseña caducada. Solicite una nueva.'
        end
      else
        if web
          render_log 'menu', usu
        else
          log_acceso usu.id, @login, 'C', web
          return usu
        end
      end
    else
      log_acceso usu.try(:id), @login, '-', web

      if web
        session[:uid] = nil

        if !Nimbus::Config[:a2p] && nacs > 1 && acs[0].status < 'A' && acs[1].status < 'A'
          @seg_blq -= (@ahora - acs[1].fecha).round
          render 'bloqueo'
        else
          render_log
        end
      else
        return 'Error de autentificación.'
      end
    end
  end

  def cambia_pass
    @assets_stylesheets = %w(welcome/index)

    usu = Usuario.find_by id: session[:uid]

    unless usu
      redirect_to '/'
      return
    end

    @login = usu.codigo

    if params[:password] != params[:password2]
      @error = 'Las contraseñas no coinciden'
      render 'cambia_pass'
    elsif usu.password_hash == BCrypt::Engine.hash_secret(params[:password], usu.password_salt)
      @error = 'No puede usar la contraseña anterior'
      render 'cambia_pass'
    elsif (@error = Usuario.valida_password(params[:password]))
      render 'cambia_pass'
    else
      ahora = Time.now

      ps = BCrypt::Engine.generate_salt
      ph = BCrypt::Engine.hash_secret(params[:password], ps)
      usu.update_columns(password_salt: ps, password_hash: ph, password_fec_mod: ahora)

      session[:fec] = ahora + 1       #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)

      redirect_to '/menu'
    end
  end

  def logout
    @ahora = Nimbus.now

    session[:uid] = nil

    log_acceso @usu.id, @usu.codigo, 'D', true
    Licencia.destroy_by sid: session[:session_id] if Nimbus::Config[:licencias]

    head :no_content
  end

  def gen_menu(hm)
    hm.each {|k, v|
      next if k[0] == '~'
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

    @usu.update_columns(empresa_def_id: nil, ejercicio_def_id: nil) if @usu.empresa_def_id && !Empresa.exists?(@usu.empresa_def_id)
    @usu.update_columns(ejercicio_def_id: nil) if @usu.ejercicio_def_id && !Ejercicio.exists?(@usu.ejercicio_def_id)

    @v = Vista.new
    @v.data = {auto_comp: {ej: "empresa_id=#{@usu.empresa_def_id}", em: (@usu.admin ? '' : "id in (#{@usu.pref[:permisos][:emp].map{|e| e[0]}.join(',')})")}}
    @v.data[:eid] = @usu.empresa_def_id
    @v.save

    @menu = ''

    hmenu = Usuario.load_menu false, @usu

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

      @usu.update_columns(empresa_def_id: nil, ejercicio_def_id: nil) if ie == 0

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

    if @usu.num_dias_validez_pass.to_i != 0
      days_left = @usu.num_dias_validez_pass - ((Time.now - @usu.password_fec_mod)/86400).to_i
      if days_left <= 3
        @days_left = days_left
      end
    end

    # Calcular en qué ejercicio se va a entrar (sólo al iniciar sesión)
    if flash[:login] && @usu.empresa_def_id && @usu.pref[:log_ej_actual]
      jid = Ejercicio.where('empresa_id = ? AND ? BETWEEN fec_inicio AND fec_fin', @usu.empresa_def_id, Date.today).order('fec_inicio desc').limit(1).pluck(:id)[0] || @usu.ejercicio_def_id
      @usu.update_columns(ejercicio_def_id: jid) if jid != @usu.ejercicio_def_id
    end

    @ajax = ''

    # LLamar al método on_ini_sesion si existe. Este método hay que definirlo
    # en app/controllers/welcome_controller_add.rb de la gestión.
    on_ini_sesion if flash[:login] && self.respond_to?(:on_ini_sesion)
  end

  def cambio_emej
    sql_exe "UPDATE usuarios SET empresa_def_id=#{params[:eid].empty? ? 'NULL' : params[:eid]}, ejercicio_def_id=#{params[:jid].empty? ? 'NULL' : params[:jid]} where id=#{@usu.id}"
    @ajax << 'location.reload();'
  end

  def api_login
    res = login(false)
    if res.is_a? String
      # Error de autentificación
      render json: {st: res}
    else
      render json: {st: 'Ok', jwt: JWT.encode({uid: res.id, exp: (Time.now + (res.timeout.to_i == 0 ? 86400 : res.timeout*60)).to_i}, Rails.application.secrets.secret_key_base)}
    end
  end

  def pass_olvido
    return unless Nimbus::Config[:email_password]

    usu = Usuario.find_by codigo: params[:usu]
    if usu && usu.email.present?
      pass = ('@#$%&/+-*'.chars.shuffle[0,1] + (0..9).to_a.shuffle[0,2] + (('A'..'Z').to_a + ('a'..'z').to_a).shuffle[0,7]).shuffle.join
      UsuariosMailer.new_password(usu, pass).deliver_now
      ps = BCrypt::Engine.generate_salt
      ph = BCrypt::Engine.hash_secret(pass, ps)
      usu.update_columns(password_salt: ps, password_hash: ph, password_fec_mod: nil)
    end
  end
end

end
