unless Nimbus::Config[:excluir_usuarios]

class UsuariosMod < Usuario
  api = Nimbus::Config[:api] ? true : false
  @campos = {
    codigo: {tab: 'pre', gcols: 4, grid: {}},
    nombre: {tab: 'pre', gcols: 4, span: true, grid: {}},
    email: {tab: 'pre', gcols: 4, span: true, rol: :email},
    foto: {tab: 'pre', gcols: 2, img: {height: 120}},
    admin: {tab: 'general', gcols: 2, br: true, grid: {}},
    api: {tab: 'general', label: 'Usuario API', gcols: 2, visible: api, grid: {hidden: !api}},
    timeout: {tab: 'general', gcols: 4},
    locale: {tab: 'general', gcols: 2, sel:{es: 'espanol', en: 'ingles'}, pref: true},
    password: {tab: 'general', hr: true, gcols: 3, attr: 'autocomplete="new-password" type="password"'},
    d_vis: {tab: 'general', gcols: 1, type: :div},
    password_rep: {tab: 'general', gcols: 3, attr: 'autocomplete="new-password" type="password"'},
    num_dias_validez_pass: {tab: 'general', label: 'dias_validez', gcols: 2},
    fecha_baja: {tab: 'general', gcols: 3, grid: {}},
    ips: {tab: 'general', gcols: 12},
    #ldapservidor_id: {tab: 'general', gcols: 4},
    empresa_def_id: {tab: 'general', gcols: 4},
    ejercicio_def_id: {tab: 'general', gcols: 4},
    log_ej_actual: {tab: 'general', type: :boolean, gcols: 4, pref: true},
  }

  @grid = {
    gcols: 3,
    cellEdit: false,
    scroll: true,
  }

  before_save :graba_pref

  def ini_campos_ctrl
    self.campos.each {|c, v|
      self[c] = self.pref[c] if v[:pref]
    }
    self.locale = 'es' if self.locale.blank?
  end

  def graba_pref
    self.campos.each {|c, v|
      self.pref[c] = self[c] if v[:pref]
    }
  end
end

class UsuariosMod
  include MantMod
end

class UsuariosController < ApplicationController
  require 'bcrypt'

  def before_index
    status_botones(crear: false) if !@usu.admin and @usu.pref[:permisos][:prf].empty?
    true
  end

  def after_index
    @view[:menu_l] << {label: 'Perfiles por Usuario', url: '/perfiles_x_usu'} if @usu.admin
  end

  def grid_conf(grid)
    #grid[:wh] = "id in (#{@usu.id},#{@usu.pref[:permisos][:usu]})".gsub('[', '').gsub(']', '') unless @usu.admin
    grid[:wh] = "usuarios.id in (#{@usu.id}#{@usu.pref[:permisos][:usu].empty? ? '' : ','}#{@usu.pref[:permisos][:usu].join(',')})" unless @usu.admin
  end

  def before_new
    @usu.admin or !@usu.pref[:permisos][:prf].empty?
  end

  def before_edit
    #return(@usu.admin || @fact.id == @usu.id || @usu.pref[:permisos][:usu].include?(@fact.id) ? nil : '/public/401.html')
    @usu.admin || @fact.id == @usu.id || @usu.pref[:permisos][:usu].include?(@fact.id)
  end

  def existe_dato(eid, dat)
    dat.each_with_index {|d, i| return(i) if d[:id] == eid}
    return false
  end

  def before_envia_ficha
    @assets_stylesheets = %w(usuarios)
    @assets_javascripts = %w(usuarios)

    unless @fact.admin || @fact.id.nil? || @fact.id == 0
      @tabs << 'empresas'
      @tabs << 'perfiles'
      @tabs << 'usuarios'

      emp_a = Empresa.all.pluck(:id, :codigo, :nombre).map {|e| {id: e[0], nom: e[1] + ' ' + e[2]}}
      prf_a = Perfil.all.pluck(:id, :codigo, :descripcion).map {|e| {id: e[0], nom: e[1] + ' ' + e[2]}}
      usu_a = Usuario.where('admin != true AND id != ? AND id != ?', @usu.id, @fact.id).pluck(:id, :codigo, :nombre).map {|e| {id: e[0], nom: e[1] + ' ' + e[2]}}

      emp_a << {id: 0, nom: 'Sin empresa'}
      emp_a << {id: -1, nom: 'Nuevas empresas'}

      prf_a << {id: 0, nom: 'Sin perfil'}

      emp = []
      prf = []
      usu = []

      # Empresas asociadas
      @fact.pref[:permisos][:emp].each {|e| # e es un array con tres elementos: el id de la empresa, el tipo de permiso (p, b, c, x) y el id del perfil
        iemp = existe_dato(e[0], emp_a)
        if iemp
          pfn = nil
          iprf = existe_dato(e[2], prf_a)
          if iprf
            if @usu.admin
              dsbl = false
            elsif @usu.pref[:permisos][:prf].include?(e[2])
              dsbl = false
            else
              dsbl = true
              pfn = prf_a[iprf][:nom]
            end
          else
            e[1] = 'x'
            e[2] = 0
            dsbl = false
          end

          if @usu.admin
            pm = 'pbcx';
          else
            if @usu.pref[:permisos][:emp].include?(e[0]) and @usu.id != @fact.id
              st = 'x'
              @usu.pref[:permisos][:emp].each {|eu|
                if eu[0] == e[0]
                  st = eu[1]
                  break
                end
              }
              if 'pbcx'.index(e[1]) < 'pbcx'.index(st)
                dsbl = true
                pm = 'pbcx'
              else
                pm = 'pbcx'['pbcx'.index(st)..-1]
              end
            else
              dsbl = true
              pm = 'pbcx'
            end
          end

          emp << {id: e[0], nom: emp_a[iemp][:nom], dsbl: dsbl, pm: pm.chars,  pf: e[2], pfn: pfn, st: e[1]}
        end
      }

      # Perfiles asociados
      @fact.pref[:permisos][:prf].each {|p|
        iprf = existe_dato(p, prf_a)
        if iprf
          prf << {id: p, nom: prf_a[iprf][:nom], st: true, dsbl: !@usu.admin && !@usu.pref[:permisos][:prf].include?(p) || @usu.id == @fact.id}
        end
      }

      # Usuarios asociados
      @fact.pref[:permisos][:usu].each {|u|
        iusu = existe_dato(u, usu_a)
        if iusu
          usu << {id: u, nom: usu_a[iusu][:nom], st: true, dsbl: !@usu.admin && !@usu.pref[:permisos][:usu].include?(u) || @usu.id == @fact.id}
        end
      }

      # Añadir resto de datos del usuario @usu
      if @usu.admin
        emp_a.each {|e|
          emp << {id: e[:id], nom: e[:nom], dsbl: false, pm: %w(p b c x), pf: 0, st: 'x'} unless existe_dato(e[:id], emp)
        }

        prf_a.each {|p|
          next if p[:id] == 0
          prf << {id: p[:id], nom: p[:nom], st: false, dsbl: false} unless existe_dato(p[:id], prf)
        }

        usu_a.each {|u|
          usu << {id: u[:id], nom: u[:nom], st: false, dsbl: false} unless existe_dato(u[:id], usu)
        }
      else
        @usu.pref[:permisos][:emp].each {|e|
          iemp = existe_dato(e[0], emp_a)
          emp << {id: e[0], nom: emp_a[iemp][:nom], dsbl: false, pm: 'pbcx'['pbcx'.index(e[1])..-1].chars, pf: 0, st: 'x'} if iemp and !existe_dato(e[0], emp)
        }

        @usu.pref[:permisos][:prf].each {|p|
          iprf = existe_dato(p, prf_a)
          prf << {id: p, nom: prf_a[iprf][:nom], st: false, dsbl: false} if iprf and !existe_dato(p, prf)
        }

        @usu.pref[:permisos][:usu].each {|u|
          iusu = existe_dato(u, usu_a)
          usu << {id: u, nom: usu_a[iusu][:nom], st: false, dsbl: false} if iusu and !existe_dato(u, usu)
        }
      end

      @ajax << "genDatos(#{emp.sort{|a, b| a[:nom] <=> b[:nom]}.to_json}, #{prf.sort{|a, b| a[:nom] <=> b[:nom]}.to_json}, #{usu.sort{|a, b| a[:nom] <=> b[:nom]}.to_json}, #{@usu.admin});"
    end

    if @fact.codigo == 'admin'
      disable(:admin)
      status_botones borrar: false
    end

    unless @usu.admin
      disable(:admin)
      disable(:api)
      status_botones(borrar: false) if @usu.id == @fact.id
    end

    unless @usu.admin or @usu.id != @fact.id
      disable(:fecha_baja)
      disable(:num_dias_validez_pass)
      disable(:ips)
      disable(:ldapservidor_id)
    end
  end

  def before_save
    if @fact.password and @fact.password != ''
      ahora = Time.now

      @fact.password_salt = BCrypt::Engine.generate_salt
      @fact.password_hash = BCrypt::Engine.hash_secret(@fact.password, @fact.password_salt)
      # dejar la fecha de modificación del password en nil si el usuario es nuevo o le cambia la contraseña otro usuario (admin)
      # Para tener un criterio para forzar el cambio de password en el siguiente login del usuario.
      @fact.password_fec_mod = (@fact.id and @fact.id == @usu.id) ? ahora : nil

      session[:fec] = ahora + 1       #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)
    end

    unless @fact.admin
      @fact.pref[:permisos][:emp] = params[:emp] ? params[:emp].to_unsafe_h.map {|k, v| [k.to_i, v[0], v[1].to_i]} : []
      @fact.pref[:permisos][:prf] = params[:prf] ? params[:prf].map {|p| p.to_i} : []
      @fact.pref[:permisos][:usu] = params[:usu] ? params[:usu].map {|u| u.to_i} : []
      Usuario.calcula_permisos(@fact)
    end

    #cookies.permanent[:locale] = session[:locale] = @fact.pref[:locale] || I18n.default_locale
    cookies.permanent[:locale] = session[:locale] = (@fact.present? ? @fact.locale.to_sym : I18n.default_locale)
  end

  def after_save
    if !@usu.admin and @fant[:id].nil?
      @usu.pref[:permisos][:usu] << @fact.id
      @usu.save
      index_reload
    end
  end

  def vali_password
     @fact.password.empty? ? nil : Usuario.valida_password(@fact.password)
  end

  def vali_password_rep
    @fact.password != @fact.password_rep ? nt('pass_mismatch') : nil
  end

  def on_admin
    if @fact.admin
      disable_tab :empresas
      disable_tab :perfiles
      disable_tab :usuarios
    else
      enable_tab :empresas
      enable_tab :perfiles
      enable_tab :usuarios
    end
  end

  def vali_ips
    err = ''
    @fact.ips.strip.split(',').each {|ip|
      ip = ip.strip
      begin
        IPAddr.new(ip)
      rescue
        err << "IP: '<b>#{ip}</b>' Sintaxis incorrecta.<br>"
      end
    }
    if err.empty?
      return nil
    else
      err << '<br>Sintaxis: xxx.xxx.xxx.xxx[/xx][, ...]'
      return err
    end
  end

  def pref_user
    @usu.pref[params[:pref]] = params[:data]
    @usu.update_column(:pref, @usu.pref)
    #render nothing: true
    head :no_content
  end
end

Nimbus.load_adds __FILE__

end
