unless Nimbus::Config[:excluir_divisas]

class Divisa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 3, may: true},
    descripcion: {},
    decimales: {manti: 1},
  }

  #after_initialize :ini_campos

  #def ini_campos
  #end
end

class Divisa < ActiveRecord::Base
  include Modelo
end

class HDivisa < ActiveRecord::Base
  include Historico
end

Nimbus.load_adds __FILE__

end
