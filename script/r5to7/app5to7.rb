#!/usr/local/bin/ruby

require 'active_support/inflector'

class NilClass
  def empty?
    true
  end
end

if !Dir.exist? 'app'
  puts 'Debe situarse en el directorio raíz del proyecto o de un módulo.'
  exit
end

if Dir.exist? 'app/models_h'
  puts 'Ya está hecha la conversión. No se hará nada.'
  exit
end

Dir.mkdir 'app/models_h'

def trata_adds(f)
  buf = File.read(f).strip
  return if buf[0..5] == '=begin'
  buf.sub!(/\s+end\s*\Z/, "\n")
  vali = false
  tab = 0
  dest = ''
  buf.each_line {|l|
    if !vali && l.lstrip[0..5] == 'class '
      vali = true
      tab = l.index 'c'
    end
    if vali
      dest << (l[[tab, l.index(/\S/).to_i].min..-1].rstrip + "\n")
    end
  }
  File.write(f, dest) if vali
end

# Modelos

puts 'Modelos'
puts '-------'
Dir.glob(['app/models/**/*.rb']).each {|f|
  puts f

  if f.end_with? '_add.rb'
    trata_adds f
    next
  end

  fa = f.split '/'
  modulo = (fa[-2] == 'models' ? '' : fa[-2].camelize + '::')
  modelo = fa[-1][0..-4].camelize
  mod = modulo + modelo
  modh = modulo + 'H' + modelo

  buf = File.read(f)

  next if !buf.match(/\s*class\s+#{mod}\s*<\s*ActiveRecord::Base\s+/)

  #buf.sub!(/\s*class\s+#{mod}\s+include\s+Modelo\s+end/, '')
  #buf.sub!(/\s*include\s+Modelo/, '')
  if buf.sub!(/\s*class\s+#{modh}\s*<\s*#{mod}\s+include\s+Historico\s+end/, '') || buf.sub!(/\s*class\s+#{modh}\s*<\s*ActiveRecord::Base\s+include\s+Historico\s+end/, '')
    if modulo.present?
      dir = "app/models_h/#{fa[2]}"
      Dir.mkdir(dir) unless Dir.exist?(dir)
    end
    File.write "app/models_h/#{fa[2..-2].join('/')}/h_#{fa[-1]}", "class #{modh} < #{mod}\nend\n"
  end
  buf.sub!(/\s*Nimbus.load_adds\s+__FILE__/, '')

  File.write f, buf.strip + "\n"
}

# Controladores

puts
puts 'Controladores'
puts '-------------'

Dir.glob(['app/controllers/**/*_controller*.rb']).each {|f|
  puts f

  if f.end_with? '_add.rb'
    trata_adds f
    next
  end

  buf = File.read(f)
  File.write(f, buf.strip + "\n") if buf.sub!(/\s*Nimbus.load_adds\s+__FILE__/, '')

=begin
  fa = f.split('/')
  modulo = (fa[-2] == 'controllers' ? '' : fa[-2].camelize + '::')
  modelo = fa[-1][0..-15].camelize + 'Mod'
  mmod = modulo + modelo

  ctr = []
  ctr_mod = []
  mod = false
  buf.each_line {|l|
    next if l.match?(/\s*Nimbus.load_adds\s+__FILE__/)
    l.rstrip!
    mod = true if l.match?(/^class\s+#{mmod}/)
    x = mod ? ctr_mod : ctr
    x << l unless x[-1].empty? && l.empty?
    mod = false if l.rstrip == 'end'
  }

  File.write f, ctr.join("\n").strip + "\n" unless ctr.empty?
  if ctr_mod.present?
    if modulo.present?
      dir = "app/controllers_mod/#{fa[2]}"
      Dir.mkdir(dir) unless Dir.exist?(dir)
    end
    File.write "app/controllers_mod/#{fa[2..-2].join('/')}/#{fa[-1][0..-15]}_mod.rb", ctr_mod.join("\n").sub(/\s*class\s+#{mmod}\s+include\s+MantMod\s+end/, '').sub(/\s*include\s+MantMod/, '').strip + "\n"
  end
=end
}
