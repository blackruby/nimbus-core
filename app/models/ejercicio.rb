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
    param: {bus_hide: true},
  }

  belongs_to :empresa, :class_name => 'Empresa'
  belongs_to :ej_anterior, :class_name => 'Ejercicio'
  belongs_to :ej_siguiente, :class_name => 'Ejercicio'
  belongs_to :divisa, :class_name => 'Divisa'

  serialize :param

  @auto_comp_data    = {campos: %w(codigo descripcion), orden: 'fec_inicio desc'}

  after_initialize :ini_campos

  def ini_campos
    self.param ||= {} if self.respond_to? :param
  end

  def auto_comp_value(tipo)
    case tipo
      when :dbops
        format("%s %s (\e[1mEmpresa:\e[0m %s %s)", self.codigo, self.descripcion, self.empresa.codigo, self.empresa.nombre)
      else
        self.codigo.to_s + ' ' + self.descripcion
    end
  end

  def contiene_fecha?(fecha)
    fecha > self.fec_inicio && fecha < self.fec_fin ? true : false
  end

end

class Ejercicio
  include Modelo
end

class HEjercicio < Ejercicio
  include Historico
end

Nimbus.load_adds __FILE__

end
