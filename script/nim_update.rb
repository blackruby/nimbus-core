require 'time'
require 'fileutils'
require 'redcarpet'

unless Dir.exist?('.git') && Dir.exist?('modulos')
  puts 'No se encuentra un proyecto válido.'
  exit
end

opts_validas = %w(--pull-submodules --file-name --file-date --all-commits --since --until)

unless (ARGV.map{|a| a.split('=')[0]} - opts_validas).empty?
  puts "Sintaxis: #{$0.split('/')[-1]} #{opts_validas.map{|p| '[' + p + ']'}.join(' ')}"
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

fecha_i[:gestion] = f_since || (Time.parse(`git log -1 --format='%cI'`.chomp) + 1).iso8601

Dir.glob('modulos/*') {|m|
  next if m == 'modulos/idiomas'

  Dir.chdir m
  fecha_i[m.split('/')[1]] = (f_since || (Time.parse(`git log -1 --format='%cI'`.chomp) + 1).iso8601) if File.exist?('.git')
  Dir.chdir '../..'
}

if f_since.nil?
  puts `git pull`
  puts `git submodule update` unless pull_smod
end
nuevo_repo('Particulares', fecha_i[:gestion])

Dir.glob('modulos/*') {|m|
  next if m == 'modulos/idiomas'

  Dir.chdir m

  if File.exist?('.git')
    if pull_smod && f_since.nil?
      puts `git checkout master`
      puts `git pull`
    end

    mod = m.split('/')[1]
    nuevo_repo(mod, fecha_i[mod])
  end

  Dir.chdir '../..'
}

FileUtils.mkpath('data/_nim_updates')

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

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
      fp.puts %Q(<div class="cuerpo">#{markdown.render(c[1])}</div>) unless c[1].empty?
    }
  }
}

fecha = get_param('file-date')
FileUtils.touch nombre, mtime: Time.parse(fecha) if fecha