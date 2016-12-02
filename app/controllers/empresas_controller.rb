class EmpresasMod < Empresa
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    nombre: {tab: 'pre', grid:{}},
    cif: {tab: 'pre', grid:{}},
    direccion: {tab: 'pre'},
    cod_postal: {tab: 'pre'},
    poblacion: {tab: 'pre'},
    provincia: {tab: 'pre'},
    telefono: {tab: 'pre', grid: {}},
    fax: {tab: 'pre'},
    email: {tab: 'pre'},
    web: {tab: 'pre'},
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
