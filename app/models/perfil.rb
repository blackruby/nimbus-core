class Perfil < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 5, pk: 1},
    descripcion: {manti: 50},
    data: {},
  }

  serialize :data

  def ini_campos
    self.data ||= {}
  end
end

class Perfil < ActiveRecord::Base
  include Modelo
end
