class Pais < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 2, pk: true},
    nombre: {manti: 30},
    tipo: {manti: 8, sel: {N: 'nacional', C: 'cee', R: 'resto'}},
    codigo_cr: {manti: 3},
  }

  after_save :control_histo
  after_initialize :ini_campos

  def ini_campos
    self.tipo = 'R'
  end
end

class Pais < ActiveRecord::Base
  include Modelo

end

class HPais < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
end