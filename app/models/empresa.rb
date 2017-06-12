unless Nimbus::Config[:excluir_empresas]

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
    web: {manti: 70},
    param: {},
  }

  serialize :param

  after_save :control_histo
  after_initialize :ini_campos

  def ini_campos
    self.param ||= {} if self.respond_to? :param
  end
end

class Empresa < ActiveRecord::Base
  include Modelo
end

class HEmpresa < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
end

Nimbus.load_adds __FILE__

end
