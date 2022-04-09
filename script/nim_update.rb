#!/usr/local/bin/ruby

require 'time'
require 'fileutils'
require 'asciidoctor'

unless Dir.exist?('.git') && Dir.exist?('modulos')
  puts 'No se encuentra un proyecto válido.'
  exit
end

opts_validas = %w(--help --pull-submodules --all-commits --file-name=<nombre> --file-date=<fecha> --since=<fecha> --until=<fecha>)

unless (ARGV.map{|a| a.split('=')[0]} - opts_validas.map{|a| a.split('=')[0]}).empty?
  puts "Sintaxis: #{$0.split('/')[-1]} #{opts_validas.map{|p| '[' + p + ']'}.join(' ')}"
  exit 
end

if ARGV.include?('--help')
  puts %q(
Este comando actualiza el repositorio de la gestión en la que nos encontremos
situados y genera un archivo en "data/_nim_updates" con los commits de la
actualización. Las opciones disponibles son las siguiente:

--help
    Muestra este texto de ayuda.

--pull-submodules
    Hace un "git pull" de todos los módulos de la gestión. Por defecto se hace
    un "git submodule update" para dejar cada módulo como indique el repositorio
    principal.

--all-commits
    Se incluyen todos los commits. Por defeceto sólo se tienen en cuenta los
    commits cuyo "subject" comience por "-"

--file-name=<nombre>
    Nombre del fichero que se generará. Por defecto es la fecha y hora actual.

--file-date=<fecha>
    Fecha de modificación que se aplicará al fichero creado. Por defecto es la
    actual. Esto es útil para el orden en el que aparecerán los ficheros de
    actualizaciones, ya que dicho orden es por la fecha de modificación de los
    archivos. El formato de la fecha es bastante amplio, pero se recomienda el
    formato "yyyy-mm-ddThh:mm:ss".

--since=<fecha>
    Si se especifica este argumento no se realizará la actualización del
    repositorio (no se hará "git pull") y en su lugar sólo se generará el
    fichero con los commits a partir de la fecha indicada en este argumento.
    El formato de la fecha es igual que en la opción anterior.

--until=<fecha>
    Sólo es válido si se ha especificado la opción "--since". Indica hasta
    qué fecha se tendrán en cuenta los commits. Por defecto es hasta el
    último commit disponible. El formato de la fecha es igual que en la
    opción anterior.

La estructura de los commits (del comentario) es la siguiente:

.- Una primera línea con el subject del commit (se recomienda un máximo de
   entre 70 y 80 caracteres).
   Si el subject comienza con "-" el commit será incluido en el fichero
   (salvo que se haya especificado la opción "--all-commits").
   Se puede seguir opcionalmente con un texto entre paréntesis indicando
   en qué sección se incluirá el commit. Si no se especifica, se incluirá
   en una sección cuyo nombre será el del módulo al que pertenezca, o la
   sección "Particulares" si el commit es del repositorio principal.

.- Una línea en blanco (opcional).

.- El cuerpo del commit (opcional).
   Si se usa "markdown" para formatear el texto, éste se convertirá a HTML
   para que la presentación sea más estética.
   Si en el comentario se incluye una línea con el texto "=fin", se ignorará
   todo lo que venga a continuación. Esto es útil si queremos incluir 
   información para los desarrolladores que no queremos que se muestre al
   usuario.
  ) 
  exit
end

def get_param(p)
  i = ARGV.index {|a| a.split('=')[0][2..-1] == p}
  i ? ARGV[i].split('=')[1] : nil
end

def nuevo_repo(mod, f_since)
  sep = "____----____----____"
  `git log --no-merges --since='#{f_since}' #{@f_until ? "--until='" + @f_until + "'" : ''} --format='%B#{sep}'`.split(sep + "\n").each {|cm|
  #return unless File.exist?("/tmp/#{mod}")
  #File.read("/tmp/#{mod}").split(sep).each {|cm| cm = cm[1..-1]
    if cm[0]  == '-'
      ini = 1
    else
      ini = 0
      next unless @all_commits
    end

    fin = cm.index("\n=fin\n") || -1
    nmod = mod
    cma = cm[ini..fin].split("\n")

    next if cma.empty?

    subj = nil
    if cma[0][0] == '('
      pf = cma[0].index(')')
      if pf
        nmod = cma[0][1...pf] if pf
        subj = cma[0][pf+1..-1]
      end
    end
    subj ||= cma[0]
    @commits[nmod] ||= []
    @commits[nmod] << [subj, cma[1..-1].join("\n").chomp]
  }
end

pull_smod = ARGV.include?('--pull-submodules')
@all_commits = ARGV.include?('--all-commits')
f_since = get_param('since')
@f_until = get_param('until') if f_since

@commits = {}
fecha_i = {}

fecha_i[:gestion] = f_since || (Time.parse(`git log -1 --format='%ci'`) + 1).iso8601

Dir.glob('modulos/*') {|m|
  next if m == 'modulos/idiomas'

  Dir.chdir m
  fecha_i[m.split('/')[1]] = (f_since || (Time.parse(`git log -1 --format='%ci'`) + 1).iso8601) if File.exist?('.git')
  Dir.chdir '../..'
}

if f_since.nil?
  puts `git pull`
  puts `git submodule update` unless pull_smod
end
nuevo_repo('Particulares', fecha_i[:gestion])

Dir.glob('modulos/*') {|m|
  Dir.chdir m

  if File.exist?('.git')
    if pull_smod && f_since.nil?
      puts `git checkout master`
      puts `git pull`
    end

    mod = m.split('/')[1]
    nuevo_repo(mod, fecha_i[mod]) unless mod == 'idiomas'
  end

  Dir.chdir '../..'
}

if @commits.empty?
  puts "\nNo hay commits disponibles en el periodo. No se generará ningún archivo."
else
  FileUtils.mkpath('data/_nim_updates')

  nombre = 'data/_nim_updates/' + (get_param('file-name') || Time.now.strftime('%d-%m-%Y %H:%M'))
  File.open(nombre, 'w') {|fp|
    @commits.each {|k, v|
      fp.puts %Q(<div class="modulo"><%= nt(%q(#{k})) %></div>)
      v.each {|c|
        fp.print '<div class="commit">'
        if c[1].empty?
          fp.print '<i class="material-icons">remove</i>'
        else
          fp.print '<i class="material-icons expande">expand_more</i>'
        end
        fp.puts %Q(<span>#{c[0]}</span></div>)
        fp.puts %Q(<div class="cuerpo">#{Asciidoctor.convert(c[1])}</div>) unless c[1].empty?
      }
    }
  }

  fecha = get_param('file-date')
  FileUtils.touch nombre, mtime: Time.parse(fecha) if fecha
end
