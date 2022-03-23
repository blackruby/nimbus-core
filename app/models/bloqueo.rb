class Bloqueo < ActiveRecord::Base
  @propiedades = {
    controlador: {manti: 20, pk: 1},
    ctrlid: {pk: 2},
    clave: {manti: 20},
  }

  belongs_to :empre, :class_name => 'Empresa'
  belongs_to :created_by, :class_name => 'Usuario'
end
