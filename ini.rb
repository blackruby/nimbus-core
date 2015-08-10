############# locales

['config/locales'].each {|r|
  d = 'modulos/local/' + r
  config.paths[r].unshift(d) if File.directory?(d)

  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/idiomas' or d.start_with? 'modulos/nimbus-core' or d.start_with? 'modulos/local'
    config.paths[r].unshift(d)
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
  d = 'modulos/idiomas/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# initializers

['config/initializers'].each {|r|
  d = 'modulos/local/' + r
  config.paths[r].unshift(d) if File.directory?(d)

  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core' or d.start_with? 'modulos/local'
    config.paths[r].unshift(d)
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r].unshift(d) if File.directory?(d)
}

############# Resto de carpetas con precedencia fifo

['app/models', 'app/controllers', 'app/views', 'app/assets', 'vendor/assets', 'db/migrate', 'lib/tasks'].each {|r|
  d = 'modulos/local/' + r
  config.paths[r] << d if File.directory?(d)

  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core' or d.start_with? 'modulos/local'
    config.paths[r] << d
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r] << d if File.directory?(d)
}

############# Resto de ficheros con precedencia fifo

['config/routes.rb'].each {|r|
  d = 'modulos/local/' + r
  config.paths[r] << d if File.exists?(d)

  Dir.glob('modulos/*/' + r).each {|d|
    next if d.start_with? 'modulos/nimbus-core' or d.start_with? 'modulos/local'
    config.paths[r] << d
  }

  d = 'modulos/nimbus-core/' + r
  config.paths[r] << d if File.exists?(d)
}
