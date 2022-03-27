# Lectura del hash de configuración
module ::Nimbus
  file = 'config/nimbus-core.yml'
  Config = File.exist?(file) ? YAML.load(ERB.new(File.read(file)).result) : {}
  if ENV['NIMBUS_CLI']
    file = "config/clientes/#{ENV['NIMBUS_CLI']}.yml"
    Config.merge! File.exist?(file) ? YAML.load(ERB.new(File.read(file)).result) : {}
  end

  # Cálculo de los módulos 'puros' disponibles
  if Config[:modulos]
    Modulos = []
    Config[:modulos].each {|m|
      mod = "modulos/#{m}"
      Modulos << mod if m != 'idiomas' && m != 'nimbus-core' && Dir.exist?(mod)
    }
  else
    Modulos = Dir.glob('modulos/*').select{|m| m != 'modulos/idiomas' && m != 'modulos/nimbus-core'}
  end
  ModulosGlob = '{' + Modulos.join(',') + ',modulos/nimbus-core}'
  Modulos << '.'
end

modulos = ::Nimbus::Modulos[0..-2]
modulos_nc = modulos + ['modulos/nimbus-core']

############# locales

['config/locales'].each {|r|
  modulos.each {|d| config.paths[r].unshift("#{d}/#{r}")}

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
  d = 'modulos/idiomas/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# initializers

['config/initializers'].each {|r|
  modulos.each {|d| config.paths[r].unshift("#{d}/#{r}")}

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# Resto de carpetas con precedencia fifo

%w(app/models app/models_h app/controllers app/controllers_mod app/views app/assets vendor/assets lib/tasks).each {|r|
  modulos_nc.each {|d| config.paths[r.split('_')[0]] << "#{d}/#{r}"}
}

############# Resto de ficheros con precedencia fifo

['config/routes.rb'].each {|r|
  modulos.each {|d| config.paths[r] << "#{d}/#{r}"}

  d = 'modulos/nimbus-core/' + r
  config.paths[r] << d if File.exist?(d)
}

############# carpetas de migraciones

r = 'db/migrate'
mods = modulos_nc.map{|m| m.split('/')[1]}
modulos_nc.each {|d|
  s = "#{d}/db/migrate"
  config.paths[r] << s if File.exist?(s)
  mods.each {|m|
    s = "#{d}/db/migrate_#{m}"
    config.paths[r] << s if File.exist?(s)
  }
}

rr = Rails.root.to_s

if Rails.version >= '6' # Configuración específica para Rails 6 o superior (testeado en rails 7.0.2.2)
  # Por defecto se asumiría que esas clases serían Gi y NimbusPdf)
  Rails.autoloaders.main.inflector.inflect("gi" => "GI", "nimbus_pdf" => "NimbusPDF")
  # Evitar el eager loading de los ficheros _add. Así se cargan (load) exclusivamente
  # en Nimbus.const_loaded y no es necesario las comprobaciones antiguas en estos
  # ficheros para ver la existencia de sus clases respectivas y evitar dobles loads.
  Rails.autoloaders.main.ignore '**/*_add.rb'
  #Rails.autoloaders.main.on_load('/home/ruby/proyectos/nimbus/modulos/nimbus-core/app/controllers/paises_controller.rb') {
  Rails.autoloaders.main.on_load(:ANY) {|_cs, cl, fi| Nimbus.const_loaded(cl, fi) if fi.starts_with?(rr)}

  # Han cambiado este default a true y en Nimbus tiene que ser false (se admiten campos references con valor nil)
  config.active_record.belongs_to_required_by_default = false
end

# Inicializar hash de orígenes (procedencias).

$nim_origenes = {}

nim_ext_conf = "#{rr}/modulos/nimbus-core/extconf/nimbus"
require nim_ext_conf unless Dir.glob("#{nim_ext_conf}*").empty?