class Perfil < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 30, pk: 1},
    descripcion: {manti: 50},
    data: {},
  }

  serialize :data

  def ini_campos
    self.data ||= {} if self.respond_to? :data
  end
end

class Perfil < ActiveRecord::Base
  include Modelo
end
