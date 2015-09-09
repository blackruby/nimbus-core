class UsuariosMod < Usuario
  @campos = {
    codigo: {tab: 'pre', grid: {}},
    nombre: {tab: 'pre', grid: {}},
    admin: {tab: 'pre', grid: {}},
    timeout: {tab: 'pre'},
    locale: {tab: 'pre', sel:{es: 'espanol', en: 'ingles'}, pref:true},
    password: {tab: 'pre'},
    password_rep: {tab: 'pre'},
    empresa_def_id: {tab: 'pre'},
    ejercicio_def_id: {tab: 'pre'},
  }

  @grid = {
    scroll: true,
  }
end

class UsuariosMod < Usuario
  include MantMod
end

class UsuariosController < ApplicationController
  require 'bcrypt'

  def before_index
    @usu.admin
  end

  def before_new
    @usu.admin
  end

  def before_edit
    return '/public/401.html' unless @usu.admin or @fact.id == @usu.id

    unless @fact.pref.nil?
      UsuariosMod.campos.each{|c, v|
        @fact.method(c.to_s + '=').call(@fact.pref[c]) if v[:pref]
      }
    end

    return nil
  end

  def before_save
    if @fact.password and @fact.password != ''
      @fact.password_salt = BCrypt::Engine.generate_salt
      @fact.password_hash = BCrypt::Engine.hash_secret(@fact.password, @fact.password_salt)
      @fact.password_fec_mod = Time.now
    end

    h = {}
    UsuariosMod.campos.each{|c, v|
      val = @fact.method(c).call
      h[c] = val if v[:pref] and (v[:type] != :string or val != '')
    }
    @fact.pref = h

    cookies.permanent[:locale] = session[:locale] = @fact.pref[:locale] || I18n.default_locale
  end

  def vali_password_rep
    @fact.password != @fact.password_rep ? nt('errors.messages.pass_mismatch') : nil
  end
end
