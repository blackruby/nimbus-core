class ErdMod
  @campos = {
    modelos: {tab: 'pre', gcols: 12, manti: 200, label: 'Modelos/Módulos', title: 'Los modelos se introducen como se referencia la clase, los módulos en minúsculas.'},
    nivel: {tab: 'pre', gcols: 1, manti: 2, type: :integer},
    erd: {tab: 'pre', gcols: 2, label: 'Diagrama ERD', type: :boolean},
    div: {tab: 'pre', gcols: 12, type: :div, br: true},
  }

  @titulo = 'Diagramas Entidad-Relación'
  @nivel = :g

  include MantMod
end

class ErdController < ApplicationController
  def before_edit
    @usu.codigo == 'admin'
  end

  def entity(mod, niv_max, niv)
    return if @mod_procesados.include?(mod)

    @mod_procesados << mod
    @htm_mod << "<table><tr><th colspan=3>#{mod}</th></tr>"

    if @fp
      mod_name = mod.to_s.gsub('::', '__')
      @fp.puts "[#{mod_name}]"
    end

    modulo = mod.to_s.split('::')[-2]
    cols = {modulo => []}

    mod.column_names.each {|c|
      next if c == 'id'

      org = @adds[mod.table_name + '@' + c]
      if org
        org.capitalize!
        cols[org] ||= [] 
        cols[org] << c
      else
        cols[modulo] << c
      end
    }

    asocs = []
    cols.each {|org, cmps|
      if org != modulo
        @htm_mod << "<tr><td class='modulo' colspan=3>#{org}</td></tr>"
        @fp.puts org + ' {bgcolor: "#D1C4E9", size: "17"}' if @fp
      end

      cmps.each {|c|
        pk = mod.pk.include?(c)

        if @fp
          @fp.print '*' if pk
          @fp.print '+' if c.ends_with?('_id')
          @fp.puts %Q(#{c} {label: "#{mod.columns_hash[c].type}"})
        end

        @htm_mod << "<tr><td>#{pk ? '<b>' : ''}#{c}#{pk ? '</b>' : ''}</td><td>#{mod.columns_hash[c].type}</td><td"
        if c.ends_with?('_id')
          asoc = mod.reflect_on_association(c[0..-4])
          if asoc
            begin
              ref = asoc.class_name.constantize
              asocs << ref unless asocs.include?(ref)
              modulo_ref = asoc.class_name.split('::')[-2]
              @htm_mod << ' class="add-asoc"' unless [nil, org, modulo, 'Comun'].include?(modulo_ref)

              if @fp && niv < niv_max
                req = mod.propiedades[c.to_sym] && mod.propiedades[c.to_sym][:req]
                @fp_asocs << %Q(#{mod_name} *--#{req ? '1' : '?'} #{asoc.class_name.gsub('::', '__')} {label: "#{asoc.name}"}\n)
              end
            rescue
              @htm_mod << ' class="bad-asoc"'
            end
            @htm_mod << ">#{asoc.class_name}"
          else
            @htm_mod << ' class="no-asoc">?????'
          end
        else
          @htm_mod << '>'
        end
        @htm_mod << '</td></tr>'
      }
    }

    @htm_mod << '</table>'

    asocs.each{|a| entity(a, niv_max, niv + 1)} if niv < niv_max
  end

  def before_envia_ficha
    @assets_stylesheets = %w(erd)
  end

  def after_save
    return if @fact.modelos.strip.empty?

    incidencias = []

    # Obtener lista de campos añadidos por otros módulos
    @adds = {}
    #`egrep 'add_column|add_reference' modulos/*/db/migrate_*/* | grep -v _h_`.each_line {|l|
    `egrep 'add_column|add_reference| t\.' modulos/*/db/migrate_*/* | egrep -v '_h_|:idid|:created_by|:created_at'`.each_line {|l|
      # Las posibles líneas que pueden llegar son:
      # modulos/mmmm/db/migrate_nnnn/999999_xxxxxxxxxxxxxxxx.rb: add_column    :almacen_familias,        :bajo_fisico_ped, :string
      # modulos/mmmm/db/migrate_nnnn/999999_xxxxxxxxxxxxxxxx.rb: add_reference :tesoreria_recibocobros, :representante, index: false
      # modulos/mmmm/db/migrate_nnnn/999999_create_pppp_tttt.rb: t.references  :empresa, index: false
      # modulos/mmmm/db/migrate_nnnn/999999_create_pppp_tttt.rb: t.xxxxxxxxxx  :codigo

      la = l.split
      org = la[0].split('/')
      if la[1][0..1] == 't.'
        ic = org[4].index('create')
        if ic 
          key = org[4][(ic + 7)..-5] + '@' + la[2][1..(la[2][-1] == ',' ? -2 : -1)] + (la[1] == 't.references' ? '_id' : '')
        else
          inci = [la[0], 'Nombre mal formado']
          incidencias << inci unless incidencias.include?(inci)
          next
        end
      else
        key = la[2][1..-2] + '@' + la[3][1..(la[3][-1] == ',' ? -2 : -1)] + (la[1] == 'add_reference' ? '_id' : '')
        incidencias << [la[1..3].join(' ').chop, 'Carpeta errónea'] if org[3].split('_')[1] != la[2].split('_')[0][1..-1]
      end
      incidencias << [l, 'Repetido'] if @adds[key]
      @adds[key] = org[1]
    }

    @mod_procesados = []
    @htm_mod = ''
    @fp_asocs = ''
    @fp = nil

    if @fact.erd
      if `which erd`.present?
        # Para poder generar diagramas erd hay que instalar el paquete: https://github.com/BurntSushi/erd
        # En el server del repositorio hay una copia del binario en /u/files_nimbus/erd
        # Instalando el paquete graphViz (con yum) y ese binario debería ser suficiente si la versión del S.O. es adecuada.
        pdf = "/tmp/nim#{@v.id}.pdf"
        @fp = IO.popen("erd -o #{pdf} >log/erd.stdout 2>&1", 'w')
      else
        incidencias << ['No se generará diagrama','No está instalado el paquete "erd"']
      end
    end

    @fact.modelos.gsub(',', ' ').split(' ').each {|m|
      begin
        entity(m.constantize, (@fact.nivel == 0 ? 999 : @fact.nivel), 1)
      rescue
        if Dir.exist? "modulos/#{m}"
          Dir.glob("modulos/#{m}/app/models/#{Dir.exist?('modulos/' + m + '/app/models/' + m) ? m : ''}/*.rb") {|n|
            begin
              entity((m.capitalize + '::' + n.split('/')[-1][0..-4].camelize).constantize, (@fact.nivel == 0 ? 999 : @fact.nivel), 1)
            rescue
              incidencias << [n, 'Modelo no válido']
            end
          }
        else
          incidencias << [m, 'No existe el módulo/modelo o no es válido']
        end
      end
    }

    if @fp
      @fp.print(@fp_asocs) if @fp_asocs.present?
      @fp.close
      envia_fichero file: pdf, file_cli: 'erd.pdf', rm: true, disposition: 'inline', popup: true
    end

    if incidencias.present?
      htm = '<table><tr><td class=incidencias colspan=2>INCIDENCIAS</td></tr>'
      incidencias.each {|i| htm << "<tr><td>#{i[0]}</td><td>#{i[1]}</td></tr>"}
    else
      htm = ''
    end

    @ajax << "$('#div').html(#{(htm + @htm_mod).to_json});"
  end
end