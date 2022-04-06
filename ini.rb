# Lectura del hash de configuración
module ::Nimbus
  Config = {}
  %W(config/nimbus-core.yml config/nimbus.yml clientes/#{ENV['NIMBUS_CLI']}/config/nimbus.yml).each {|file|
    Config.merge! File.exist?(file) ? YAML.load(ERB.new(File.read(file)).result) : {}
  }

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
  ModulosCli = Modulos + ["clientes/#{ENV['NIMBUS_CLI']}"] 
  ModulosCliGlob = '{' + ModulosCli.join('/') + ',modulos/nimbus-core}'

  # Paths en función de si hay un cliente seleccionado
  Gestion = ENV['NIMBUS_CLI'] || Rails.app_class.to_s.split(':')[0].downcase
  GestionPath = ENV['NIMBUS_CLI'] ? "clientes/#{ENV['NIMBUS_CLI']}/" : ''
  BusPath = GestionPath + 'bus'
  GiPath = GestionPath + 'formatos'
  DataPath = GestionPath + 'data'
  LogPath = GestionPath + 'log'

end

modulos = ::Nimbus::Modulos[0..-2]
modulos_nc = modulos + ['modulos/nimbus-core']
modulos_cli = modulos_nc + ["clientes/#{ENV['NIMBUS_CLI']}"] 

############# locales

r = 'config/locales'
(modulos_nc + %w(modulos/idiomas)).each {|m|
  d = m + '/' + r
  config.paths[r].unshift(d) if Dir.exist?(d)
}
d = modulos_cli[-1] + '/' + r
config.paths[r] << d if Dir.exist?(d)

############# initializers

r = 'config/initializers'
modulos_nc.each {|m|
  d = m + '/' + r
  config.paths[r].unshift(d) if Dir.exist?(d)
}
d = modulos_cli[-1] + '/' + r
config.paths[r] << d if Dir.exist?(d)

############# Resto de carpetas con precedencia fifo

%w(app/models app/models_h app/controllers app/controllers_mod app/views app/assets vendor/assets lib/tasks).each {|r|
  modulos_cli.each {|m|
    d = m + '/' + r
    config.paths[r.split('_')[0]] << d if Dir.exist?(d)
  }
}
  
############# Seeds

r = 'db/seeds.rb'
config.paths[r] = ['modulos/nimbus-core/db/seeds.rb']

############# Rutas

r = 'config/routes.rb'
d = modulos_cli[-1] + '/' + r
config.paths[r].unshift(d) if File.exist?(d)
modulos_nc.each {|d| config.paths[r] << "#{d}/#{r}"}

############# carpetas de migraciones

r = 'db/migrate'
mods = modulos_nc.map{|m| m.split('/')[1]}
modulos_cli.each {|d|
  s = "#{d}/db/migrate"
  config.paths[r] << s if File.exist?(s)
  mods.each {|m|
    s = "#{d}/db/migrate_#{m}"
    config.paths[r] << s if File.exist?(s)
  }
}

############# Fichero de log
if ENV['NIMBUS_CLI']
  FileUtils.mkpath(Nimbus::LogPath)
  config.paths['log'] = "#{Nimbus::LogPath}/#{Rails.env}.log"
end

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
  Rails.autoloaders.main.on_unload(:ANY) {|cs|
    unless cs.include? '::'
      cte = cs.ends_with?('Controller') ? cs.sub('Controller', 'Mod') : 'H' + cs
      Object.__send__(:remove_const, cte) if Object.const_defined?(cte)
    end
  }

  # Han cambiado este default a true y en Nimbus tiene que ser false (se admiten campos references con valor nil)
  config.active_record.belongs_to_required_by_default = false
end

# Inicializar hash de orígenes (procedencias).

$nim_origenes = {}

nim_ext_conf = "#{rr}/modulos/nimbus-core/extconf/nimbus"
require nim_ext_conf unless Dir.glob("#{nim_ext_conf}*").empty?