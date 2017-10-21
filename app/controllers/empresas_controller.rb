unless Nimbus::Config[:excluir_empresas]

class EmpresasMod < Empresa
  @campos = {
    codigo: {tab: 'pre', gcols: 3, grid:{}},
    nombre: {tab: 'pre', grid:{}, span: true},
    nombre_comercial: {tab: 'pre', grid:{}, span: true},
    cif: {tab: 'pre', grid:{}, span: true},
    direccion: {tab: 'pre', gcols: 4, rol: :map},
    cod_postal: {tab: 'pre', map: :direccion, span: true},
    poblacion: {tab: 'pre', map: :direccion, span: true},
    provincia: {tab: 'pre', map: :direccion, span: true},
    telefono: {tab: 'pre', gcols: 3, grid: {}},
    fax: {tab: 'pre', span: true},
    email: {tab: 'pre', rol: :email, span: true},
    web: {tab: 'pre', rol: :url, span: true},
    logo: {tab: 'pre', gcols: 2, img: {height: 200}},
  }

  @grid = {
    gcols: [4,8],
    ew: :w,
    height: 200,
    scroll: true,
  }

  @hijos = [{url: 'ejercicios', tab: 'post'}]

  #def ini_campos_ctrl
  #end
end

class EmpresasMod < Empresa
  include MantMod
end

class EmpresasController < ApplicationController
=begin
  def ejercicio_en_menu
    if Ejercicio.where('empresa_id = ?', params[:eid]).count == 0
      @ajax << '$("#d-ejercicio").css("visibility", "hidden")'
    else
      @ajax << '$("#d-ejercicio").css("visibility", "visible");$("#ejercicio").focus();'
    end
  end
=end

  def grid_conf(grid)
    grid[:wh] = "id in (#{@usu.pref[:permisos][:emp].map{|e| e[0]}})".gsub('[', '').gsub(']', '') unless @usu.admin
  end

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

Nimbus.load_adds __FILE__

end
