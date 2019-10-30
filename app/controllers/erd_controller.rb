class ErdMod
  @campos = {
    modelos: {tab: 'pre', gcols: 12, manti: 200},
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

    cols = {n: []}

    mod.column_names.each {|c|
      next if c == 'id'

      org = @adds[mod.table_name + '@' + c]
      if org
        cols[org] ||= [] 
        cols[org] << c
      else
        cols[:n] << c
      end
    }

    asocs = []
    cols.each {|org, cmps|
      if org != :n
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
              if @fp && niv < niv_max
                req = mod.propiedades[c.to_sym] && mod.propiedades[c.to_sym][:req]
                @fp_asocs << %Q(#{mod_name} *--#{req ? '1' : '?'} #{asoc.class_name.gsub('::', '__')} {label: "#{asoc.name}"}\n)
              end
            rescue
              @htm_mod << ' class=badasoc'
            end
            @htm_mod << ">#{asoc.class_name}"
          else
            @htm_mod << ' class=badasoc>?????'
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
    `egrep 'add_column|add_reference' modulos/*/db/migrate_*/* | grep -v _h_`.each_line {|l|
      # ejemplo de línea
      # modulos/venta/db/migrate_almacen/20170308174733_update_venta_almacen_familias.rb:      add_column :almacen_familias, :bajo_fisico_ped, :string
      la = l.split
      org = la[0].split('/')
      key = la[2][1..-2] + '@' + la[3][1..-2] + (la[1] == 'add_reference' ? '_id' : '')
      incidencias << [la[1..3].join(' ').chop, 'Repetido'] if @adds[key]
      incidencias << [la[1..3].join(' ').chop, 'Carpeta errónea'] if org[3].split('_')[1] != la[2].split('_')[0][1..-1]
      @adds[key] = org[1]
    }

    @mod_procesados = []
    @htm_mod = ''
    @fp_asocs = ''
    @fp = nil

    if @fact.erd
      if `which erd`.present?
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
        incidencias << [m, 'No existe el modelo']
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