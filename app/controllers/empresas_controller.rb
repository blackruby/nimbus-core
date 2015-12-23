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

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class EmpresasMod < Empresa
  include MantMod
end

class EmpresasController < ApplicationController
  def ejercicio_en_menu
    if Ejercicio.where('empresa_id = ?', params[:eid]).count == 0
      @ajax << '$("#d-ejercicio").css("visibility", "hidden")'
    else
      @ajax << '$("#d-ejercicio").css("visibility", "visible");$("#ejercicio").focus();'
    end
  end
end
