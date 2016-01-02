class UsuariosMod < Usuario
  @campos = {
    codigo: {tab: 'pre', gcols: 4, grid: {}},
    nombre: {tab: 'pre', gcols: 4, grid: {}},
    admin: {tab: 'pre', gcols: 2, hr: true, grid: {}},
    timeout: {tab: 'pre', gcols: 4},
    locale: {tab: 'pre', gcols: 2, sel:{es: 'espanol', en: 'ingles'}, pref:true},
    password: {tab: 'pre', hr: true, gcols: 4},
    password_rep: {tab: 'pre', gcols: 4},
    empresa_def_id: {tab: 'pre', hr: true, gcols: 4},
    ejercicio_def_id: {tab: 'pre', gcols: 4},
  }

  @grid = {
    scroll: true,
  }

  after_initialize :ini_campos_ctrl
  before_save :graba_pref

  def ini_campos_ctrl
    self.class.campos.each {|c, v|
      self.method("#{c}=").call(self.pref[c]) if v[:pref]
    }
  end

  def graba_pref
    self.class.campos.each {|c, v|
      self.pref[c] = self.method(c).call if v[:pref]
    }
  end
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
    unless @usu.admin or @fact.id == @usu.id
      return '/public/401.html'
    else
      return nil
    end
  end

  def before_save
    if @fact.password and @fact.password != ''
      @fact.password_salt = BCrypt::Engine.generate_salt
      @fact.password_hash = BCrypt::Engine.hash_secret(@fact.password, @fact.password_salt)
      @fact.password_fec_mod = Time.now
    end

    cookies.permanent[:locale] = session[:locale] = @fact.pref[:locale] || I18n.default_locale
  end

  def vali_password_rep
    @fact.password != @fact.password_rep ? nt('errors.messages.pass_mismatch') : nil
  end

  def pref_user
    @usu.pref[params[:pref]] = params[:data]
    @usu.update_column(:pref, @usu.pref)
    render nothing: true;
  end
end
