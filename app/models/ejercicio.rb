unless Nimbus::Config[:excluir_ejercicios]

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
    param: {},
  }

  belongs_to :empresa, :class_name => 'Empresa'
  belongs_to :ej_anterior, :class_name => 'Ejercicio'
  belongs_to :ej_siguiente, :class_name => 'Ejercicio'
  belongs_to :divisa, :class_name => 'Divisa'

  serialize :param

  after_save :control_histo
  after_initialize :ini_campos

  def ini_campos
    self.param ||= {} if self.respond_to? :param
  end

  def auto_comp_value(tipo)
    self.codigo.to_s + ' ' + self.descripcion
  end
end

class Ejercicio < ActiveRecord::Base
  include Modelo
end

class HEjercicio < ActiveRecord::Base
  include Historico
end

Nimbus.load_adds __FILE__

end
