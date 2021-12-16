home = File.expand_path(__FILE__).split('/')[0..-5].join('/')

key_size = rand(290..310)
key = []
key_size.times {|i| key[i] = rand(50..200)}

crypt = -> (fic) {
  puts fic

  ino = File.stat(fic).ino
  seed = ino % key_size

  buf = File.read(fic)

  buf.each_byte.with_index {|c, i|
    buf.setbyte(i, (c + key[seed]) % 256)  
    seed = (seed + 1) % key_size
  }

  File.write("#{home}/.nimbus/#{(ino + 123456789).to_s(16).upcase}", buf)
  File.write(fic, 'nimbus_source binding')
}

Dir.chdir("#{home}/modulos/nimbus-core/extconf")

off = rand(10..200)
key_str = key.map.with_index{|k, i|
  ko = k - off
  if ko > 127 then ko -= 256 elsif ko < -128 then ko += 256 end
  "k[#{i}]=#{ko};"
}.join
buf = File.read('proto/nimbus.c')
buf.sub!('/*-*/', %Q(
  ks = #{key_size};
  k = malloc(ks);
  #{key_str}
  for (i = 0; i < ks; i++) k[i] += #{off};
))
File.write('nimbus.c', buf)

require 'mkmf'
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

FileUtils.mkdir_p '.nimbus'

# Ficheros a encriptar
puts
puts 'Encriptando ficheros:'
puts
Dir.glob('config/initializers/nimbus.rb') {|f| crypt[f]}
Dir.glob('config/initializers/origenes.rb') {|f| crypt[f]}
Dir.glob('app/**/*.rb') {|f| crypt[f]}
Dir.glob('lib/**/*.rb') {|f| crypt[f]}
Dir.glob('formatos/**/*.rb') {|f| crypt[f]}
Dir.glob('modulos/**/*.rb') { |f|
  next if f == 'modulos/nimbus-core/ini.rb'
  crypt[f]
}

# Borrar repositorio
FileUtils.rm_rf '.git'

# Borrar assets
FileUtils.rm_rf %w(app/assets/images app/assets/javascripts app/assets/stylesheets vendor)
FileUtils.rm_rf Dir.glob('modulos/*/app/assets')
FileUtils.rm_rf Dir.glob('modulos/*/vendor')

puts
puts '*****************************'
puts 'Proceso finalizado con éxito.'
puts '*****************************'
puts