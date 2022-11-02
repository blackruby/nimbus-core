unless Nimbus::Config[:excluir_empresas]

class Empresa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 5, req: true},
    nombre: {manti: 60},
    nombre_comercial: {manti: 60},
    cif: {manti: 10},
    direccion: {manti: 70},
    cod_postal: {manti: 15},
    poblacion: {manti: 50},
    provincia: {manti: 20},
    pais: {},
    tipo_persona: {req: true, sel: {j: 'juridica', f: 'fisica'}},
    telefono: {manti: 30},
    fax: {manti: 30},
    email: {manti: 70},
    web: {manti: 70},
    param: {bus_hide: true},
  }

  belongs_to :pais, :class_name => 'Pais'

  serialize :param

  after_initialize :ini_campos

  def ini_campos
    self.tipo_persona ||= 'j' if self.respond_to? :tipo_persona
    self.param ||= {} if self.respond_to? :param
  end

  def self.bus_filter(h)
    "empresas.id IN (#{h[:usu].mis_empresas.join(',')})" unless h[:usu].admin
  end
end

end
