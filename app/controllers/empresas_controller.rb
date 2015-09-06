class EmpresasMod < Empresa
  @campos = {
    codigo: {div: 'general', grid:{}},
    nombre: {div: 'general', grid:{}},
    cif: {div: 'general', grid:{}},
    direccion: {div: 'general'},
    cod_postal: {div: 'general'},
    poblacion: {div: 'general'},
    provincia: {div: 'general'},
    telefono: {div: 'general', grid: {}},
    fax: {div: 'general'},
    email: {div: 'general'},
    p_long: {div: 'parametros'},
    p_mod_fiscal: {div: 'parametros'},
    p_dec_cantidad: {div: 'parametros'},
    p_dec_precio_r: {div: 'parametros'},
    p_dec_precio_v: {div: 'parametros'},
  }

  @hijos = ['ejercicios']

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class EmpresasMod < Empresa
  include MantMod
end

class EmpresasController < ApplicationController
end
