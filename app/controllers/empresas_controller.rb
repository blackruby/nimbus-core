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
    height: 200,
    scroll: true,
  }

  @hijos = [{id: 'ejercicios', tab: 'ejercicios'}]

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class EmpresasMod < Empresa
  include MantMod
end

class EmpresasController < ApplicationController
end
