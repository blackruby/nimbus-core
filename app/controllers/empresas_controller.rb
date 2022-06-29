unless Nimbus::Config[:excluir_empresas]

class EmpresasMod < Empresa
  @campos = {
    codigo: {tab: 'pre', gcols: 3, grid:{}},
    nombre: {tab: 'pre', grid:{}, span: true},
    nombre_comercial: {tab: 'pre', grid:{}, span: true},
    cif: {tab: 'pre', grid:{}, span: true},
    direccion: {tab: 'pre', gcols: 4, rol: :map},
    cod_postal: {tab: 'pre', label: 'c_postal', map: :direccion, span: true, inline: true, pw: 20},
    poblacion: {tab: 'pre', map: :direccion, span: true, inline: true, pw: 80, ml: 5},
    provincia: {tab: 'pre', map: :direccion, span: true},
    pais_id: {tab: 'pre', span: true, req: true},
    telefono: {tab: 'pre', gcols: 3, grid: {}},
    fax: {tab: 'pre', span: true},
    email: {tab: 'pre', rol: :email, span: true},
    web: {tab: 'pre', rol: :url, span: true},
    logo: {tab: 'pre', gcols: 2, img: {height: 68}},
    estilo: {tab: 'pre', nil: true, sel: {nil: 'nim_color_emp_nil', nim_color_emp_banda: 'nim_color_emp_banda', nim_color_emp_tl: 'nim_color_emp_tl', nim_color_emp_c: 'nim_color_emp_c'}, span: true, param: true},
    color: {tab: 'pre', manti: 20, attr: 'type="color"', span: true, param: true},
  }

  @grid = {
    gcols: [4,8],
    ew: :w,
    height: 200,
    scroll: true,
    cellEdit: false,
  }

  @hijos = [{url: 'ejercicios', tab: 'post'}]

  before_save :graba_param

  def ini_campos_ctrl
    self.campos.each {|c, v|
      self[c] = self.param[c] if v[:param]
    }
    self.estilo = :nil unless self.estilo
    self.color = '#000000' if self.color.to_s.empty?
    self.pais_id = Pais.where(codigo: 'ES').pluck(:id)[0] if self.id.nil?
  end

  def graba_param
    self.campos.each {|c, v|
      self.param[c] = self[c] if v[:param]
    }
  end

  include MantMod
end

class EmpresasController < ApplicationController
  def get_prm_prf
    prm = prf = nil
    @usu.pref[:permisos][:emp].each {|e|
      if e[0] == -1
        prm = e[1]
        prf = e[2]
        break
      end
    }
    return [prm, prf]
  end

  def before_envia_ficha
    status_botones(crear: false) unless @usu.admin or get_prm_prf[0]
  end

  def after_save
    if !@usu.admin and @fant[:id].nil?
      mf = get_prm_prf
      @usu.pref[:permisos][:emp] << [@fact.id, mf[0], mf[1]]
      @usu.save
      index_reload
    end
  end
end

end
