unless Nimbus::Config[:excluir_perfiles]

class Perfil < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 30, pk: 1},
    descripcion: {manti: 50},
    data: {bus_hide: true},
  }

  serialize :data

  # Permisos especiales
  # Cada elemento que se añade al hash consta de su clave, que se usará como label
  # (traducida automáticamente con nt) y su valor, que en el caso de una opción de
  # menú sería su URL y en el caso de permisos especiales sería un tag libre
  # para poder luego acceder al valor del permiso a través del método
  # Usuario#permiso(tag, eid) siendo el tag el definido aquí y eid el id de la
  # empresa en la cual queremos testear el permiso.
  # Si la url (clave para acceder al permiso) es nil se considerará un título
  # dentro del árbol en el mantenimiento de perfiles.
  # Esta variable de clase se puede ampliar o modificar en módulos o gestiones.

  @@permisos_especiales = {'_permisos_especiales_' => nil, '_acc_hist_' => '_acc_hist_'}
  @@permisos_especiales['_osp_'] = '_osp_' if Nimbus::Config[:osp]

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

Nimbus.load_adds __FILE__

end
