############# locales

['config/locales'].each {|r|
  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/idiomas' or d.start_with? 'modulos/nimbus-core'
    config.paths[r].unshift(d)
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
  d = 'modulos/idiomas/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# initializers

['config/initializers'].each {|r|
  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core'
    config.paths[r].unshift(d)
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# Resto de carpetas con precedencia fifo

['app/models', 'app/controllers', 'app/views', 'app/assets', 'vendor/assets', 'lib/tasks'].each {|r|
  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core'
    config.paths[r] << d
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r] << d if File.directory?(d)
}

############# Resto de ficheros con precedencia fifo

['config/routes.rb'].each {|r|
  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core'
    config.paths[r] << d
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r] << d if File.exists?(d)
}
############# carpetas de migraciones

r = 'db/migrate'
mods = Dir.glob('modulos/*').map{|m| m.split('/')[1]}

Dir.glob('modulos/*/db').each {|d|
  s = "#{d}/migrate"
  config.paths[r] << s if File.exists?(s)
  mods.each {|m|
    s = "#{d}/migrate_#{m}"
    config.paths[r] << s if File.exists?(s)
  }
}

# Inicializar hash de orígenes (procedencias).

$nim_origenes = {}
