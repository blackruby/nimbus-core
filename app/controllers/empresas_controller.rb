class EmpresasMod < Empresa
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    nombre: {tab: 'pre', grid:{}},
    cif: {tab: 'general', grid:{}},
    direccion: {tab: 'general'},
    cod_postal: {tab: 'general'},
    poblacion: {tab: 'general'},
    provincia: {tab: 'general'},
    telefono: {tab: 'general', grid: {}},
    fax: {tab: 'general'},
    email: {tab: 'general'},
    p_long: {tab: 'parametros'},
    p_mod_fiscal: {tab: 'parametros'},
    p_dec_cantidad: {tab: 'parametros'},
    p_dec_precio_r: {tab: 'parametros'},
    p_dec_precio_v: {tab: 'parametros'},
  }

  @grid = {
    gcols: [4,8],
    ew: :w,
    height: 200,
    scroll: true,
  }

  @hijos = [{url: 'ejercicios', tab: 'ejercicios'}]

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
      render js: '$("#d-ejercicio").css("visibility", "hidden")'
    else
      render js: '$("#d-ejercicio").css("visibility", "visible");$("#ejercicio").focus();'
    end
  end
end
