unless Nimbus::Config[:excluir_empresas]

class Empresa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 5},
    nombre: {manti: 60},
    nombre_comercial: {manti: 60},
    cif: {manti: 10},
    direccion: {manti: 70},
    cod_postal: {manti: 15},
    poblacion: {manti: 50},
    provincia: {manti: 20},
    pais: {},
    telefono: {manti: 30},
    fax: {manti: 30},
    email: {manti: 70},
    web: {manti: 70},
    param: {},
  }

  belongs_to :pais, :class_name => 'Pais'

  serialize :param

  after_initialize :ini_campos

  def ini_campos
    self.param ||= {} if self.respond_to? :param
  end
end

class Empresa < ActiveRecord::Base
  include Modelo
end

class HEmpresa < Empresa
  include Historico
end

Nimbus.load_adds __FILE__

end
