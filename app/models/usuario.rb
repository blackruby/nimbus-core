class Usuario < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 15},
    nombre: {},
    email: {},
    password_salt: {},
    password_hash: {},
    password_fec_mod: {},
    admin: {},
    timeout: {manti: 6, nil: true},
    empresa_def_id: {ro: :all},
    ejercicio_def_id: {ro: :all},
    pref: {},
  }

  belongs_to :empresa_def, :class_name => 'Empresa'
  belongs_to :ejercicio_def, :class_name => 'Ejercicio'

  after_save :control_histo
  #after_initialize :ini_campos

  #def ini_campos
  #end

  serialize :pref
end

class Usuario < ActiveRecord::Base
  include Modelo
end

class HUsuario < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
  serialize :pref
end