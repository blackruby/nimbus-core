require 'active_support'
require 'active_support/core_ext'
require 'mkmf'

home = File.expand_path(__FILE__).split('/')[0..-5].join('/')

key_size = rand(290..310)
key = []
key_size.times {|i| key[i] = rand(50..200)}

Dir.chdir(home)

files = {}
Dir.glob('**/*.rb') {|f| files[f] = {}}
files.delete('config/application.rb')
files.delete('config/boot.rb')
files.delete('config/environment.rb')
files.delete('modulos/nimbus-core/extconf/crypt.rb')
files['modulos/nimbus-core/ini.rb'][:ini] = "require '#{home}/modulos/nimbus-core/extconf/nimbus'\n"
names = (1..files.size).to_a.shuffle
files.each_with_index {|v, i| v[1][:fn] = names[i]}

Dir.chdir("#{home}/modulos/nimbus-core/extconf")

off = rand(10..200)

key_str = "static int lenh=#{home.size + 1};\n"
key_str << "static int ks=#{key_size},kof=#{off};\nstatic char k[]={"
key.map.with_index{|k, i|
  ko = k - off
  if ko > 127 then ko -= 256 elsif ko < -128 then ko += 256 end
  key_str << "#{ko},"
}
key_str[-1] = "};\n"

key_str << "static int nfls=#{files.size};\n"
key_str << "static int fls_n[]={#{files.values.map{|f| f[:fn]}.join(',')}};\n"
key_str << "static char fls[]={#{files.keys.map{|f| (f.split('').map{|l| 256 - l.ord} + [0]).join(',')}.join(',')}};"

File.write('nimbus.c', File.read('proto/nimbus.c').sub!('/*-*/', key_str))

create_header
create_makefile 'nimbus'
unless system('make')
  puts
  puts '****************************************'
  puts 'Se han producido errores de compilación.'
  puts 'Encriptación abortada.'
  puts '****************************************'
  puts
  exit(1)
end

FileUtils.rm_rf %w(Makefile nimbus.c nimbus.o extconf.h mkmf.log proto crypt crypt.rb)

Dir.chdir(home)

# Inyectar la configuración actual en el fuente ini.rb para evitar manipulaciones
cnf = {}
Dir.glob(%W(config/nimbus-core.yml config/nimbus.yml)) {|f|
  cnf.merge!(YAML.load(ERB.new(File.read(f)).result).deep_symbolize_keys)
}
cod = "Config=#{cnf.inspect};"
cnf = {}
Dir.glob('clientes/*/config/nimbus.yml') {|f|
  cnf[f.split('/')[1]] = YAML.load(ERB.new(File.read(f)).result).deep_symbolize_keys
}

cod << "cnf=#{cnf.inspect};cnf.default={};"
cod << "Config.merge!(cnf[ENV['NIMBUS_CLI']]);"
cod << %q(Dir.glob(%W(config/nimbus-core.yml config/nimbus.yml clientes/#{ENV['NIMBUS_CLI']}/config/nimbus.yml)){|f| Config.merge! YAML.load(ERB.new(File.read(f)).result).deep_symbolize_keys.delete_if{|k| k!=:db && k!=:puma}})
ini_rb = 'modulos/nimbus-core/ini.rb'
File.write(ini_rb, File.read(ini_rb).sub!(/##--IniConf.*##--FinConf/m, cod))
    
# Inyectar el tema CSS por defecto en el modelo Tema (tema.rb)
h = {}
File.readlines('modulos/nimbus-core/vendor/assets/stylesheets/_nimbus_theme.scss').each {|l|
  next unless l.strip!.to_s.starts_with?('--')
  l = l.split(':')
  h[l[0]] = l[1].strip.chomp.chop
}
tema = 'modulos/nimbus-core/app/models/tema.rb'
File.write(tema, File.read(tema).sub!(/##--IniDef.*##--FinDef/m, "h=#{h.inspect}"))

# Creación de la carpeta .nimbus (donde irán los fuentes encriptados)
FileUtils.mkdir_p '.nimbus'

# Ficheros a encriptar
puts
puts 'Encriptando ficheros:'
puts
files.each {|fic, hsh|
  puts fic

  seed = hsh[:fn] % key_size

  buf = File.read(fic)

  buf.each_byte.with_index {|c, i|
    buf.setbyte(i, (c + key[seed]) % 256)  
    seed = (seed + 1) % key_size
  }

  File.write(".nimbus/#{hsh[:fn]}", buf)

  File.write(fic, "#{hsh[:ini]}nimbus_source binding")
}

# Borrar repositorio y assets
FileUtils.rm_rf Dir.glob %w(**/.git **/app/assets **/vendor)

puts
puts '*****************************'
puts 'Proceso finalizado con éxito.'
puts '*****************************'
puts