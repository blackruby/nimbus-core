unless Nimbus::Config[:excluir_perfiles]

class Perfil < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 30, pk: 1},
    descripcion: {manti: 50},
    data: {},
  }

  serialize :data

  # Permisos especiales
  # Si la url (clave para acceder al permiso) es nil se considerará un título
  # dentro del árbol en el mantenimiento de perfiles.
  # Esta variable de clase se puede ampliar (<<) o modificar en módulos o gestiones.

  @@permisos_especiales = {'_permisos_especiales_' => nil, '_acc_hist_' => '_acc_hist_'}

  def self.permisos_especiales
    @@permisos_especiales
  end

  def ini_campos
    self.data ||= {} if self.respond_to? :data
  end
end

class Perfil
  include Modelo
end

end
