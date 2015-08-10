class Ejercicio < ActiveRecord::Base
  @propiedades = {
    empresa_id: {pk: 1, req: true},
    codigo: {pk: 2, req: true, manti: 5},
    descripcion: {manti: 30},
    ej_anterior_id: {},
    ej_siguiente_id: {},
    divisa_id: {},
    fec_inicio: {},
    fec_fin: {},
  }

  belongs_to :empresa, :class_name => 'Empresa'
  belongs_to :ej_anterior, :class_name => 'Ejercicio'
  belongs_to :ej_siguiente, :class_name => 'Ejercicio'
  belongs_to :divisa, :class_name => 'Divisa'

  after_save :control_histo
  #after_initialize :ini_campos

  #def ini_campos
  #end
end

class Ejercicio < ActiveRecord::Base
  include Modelo
end

class HEjercicio < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
end