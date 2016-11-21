class Pais < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 2, pk: true},
    nombre: {manti: 30},
    tipo: {manti: 8, sel: {N: 'nacional', C: 'cee', R: 'resto'}},
    codigo_cr: {manti: 3},
  }

  after_save :control_histo
  after_initialize :ini_campos

  @auto_comp_data = {campos: ['codigo', 'nombre', 'codigo_cr']}

  def ini_campos
    self.tipo ||= 'R' if self.new_record?
  end
end

class Pais < ActiveRecord::Base
  include Modelo

end

class HPais < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
end
