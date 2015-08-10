class Empresa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 5},
    nombre: {manti: 60},
    cif: {manti: 10},
    direccion: {manti: 70},
    cod_postal: {manti: 15},
    poblacion: {manti: 35},
    provincia: {manti: 20},
    telefono: {manti: 30},
    fax: {manti: 30},
    email: {manti: 70},
    p_long: {manti: 2},
    p_mod_fiscal: {sel: {C: 'territorio_comun', A: 'alava', N: 'navarra'}},
    p_dec_cantidad: {manti: 1},
    p_dec_precio_r: {manti: 1},
    p_dec_precio_v: {manti: 1},
  }


  after_save :control_histo
  #after_initialize :ini_campos

  #def ini_campos
  #end
end

class Empresa < ActiveRecord::Base
  include Modelo
end

class HEmpresa < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
end