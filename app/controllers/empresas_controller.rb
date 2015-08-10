class EmpresasMod < Empresa
  @campos = {
    codigo: {div: 'g1', grid:{}},
    nombre: {div: 'g1', grid:{}},
    cif: {div: 'g1', grid:{}},
    direccion: {div: 'g1'},
    cod_postal: {div: 'g1'},
    poblacion: {div: 'g1'},
    provincia: {div: 'g1'},
    telefono: {div: 'g1', grid: {}},
    fax: {div: 'g1'},
    email: {div: 'g1'},
    p_long: {div: 'g2'},
    p_mod_fiscal: {div: 'g2'},
    p_dec_cantidad: {div: 'g2'},
    p_dec_precio_r: {div: 'g2'},
    p_dec_precio_v: {div: 'g2'},
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
