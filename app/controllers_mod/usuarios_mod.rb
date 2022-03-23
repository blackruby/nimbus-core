class UsuariosMod < Usuario
  api = Nimbus::Config[:api] ? true : false
  @campos = {
    codigo: {tab: 'pre', gcols: 4, grid: {}},
    nombre: {tab: 'pre', gcols: 4, span: true, grid: {}},
    email: {tab: 'pre', gcols: 4, span: true, rol: :email},
    foto: {tab: 'pre', gcols: 2, img: {height: 120}},
    admin: {tab: 'general', gcols: 2, br: true, grid: {}},
    api: {tab: 'general', label: 'Usuario API', gcols: 2, visible: api, grid: {hidden: !api}},
    audit: {tab: 'general', label: 'Auditar', gcols: 2, visible: Nimbus::Config[:audit], grid: {}},
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
