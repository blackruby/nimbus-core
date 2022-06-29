# Ventana de búsqueda
#
# Funcionalidades:
#
# Click izquierdo en un campo lo añade al grid.
#
# Click derecho lo elimina (el que esté en última posición).
#
# Se puede multiordenar. Haciendo click en la cabecera de una columna
# se añade a la ordenación en orden ascendente, un segundo click en
# orden descendente y un tercero la quita de la ordenación.
# Hay que tener en cuenta que la ordenación de campos es de
# izquierda a derecha. Es decir el campo que esté más a la izquierda
# tiene más peso. Las columnas se pueden reordenar (arrastrando desde
# la cabecera) y así conseguir la ordenación deseada.
# Las columnas también se pueden redimensionar.
#
# Opciones del menú:
#
# Nueva: Vacía el grid para empezar una nueva selección.
#
# Guardar: Saca un diálogo en el que se nos pide el nombre de un fichero.
#   Si la búsqueda procede de un archivo del usuario se nos propondrá
#   el mismo nombre. Si cambiamos de nombre y éste ya existe se pondrá
#   en rojo para indicar el hecho (así no hay que sacar un diálogo
#   adicional indicando que ya existe). Los ficheros de búsqueda de
#   usuario se guardan en formato yaml (extensión .yml) y se sitúan en:
#   bus/_usuarios/<usuario>/Modelo/
#
# Predeterminar: Selecciona la búsqueda actual como predeterminada.
#   Si no hay búsqueda predeterminada por el usuario, la búsqueda
#   que se mostrará al abrir la ventana se elegirá con el siguiente
#   criterio:
#     .- clave ':bus' en el campo id del controlador, por ejemplo en el
#     controlador de clientes, en el campo agente_id podríamos poner:
#     agente_id: {tab: 'facturacion', gcols: 4, bus: 'path_a_mi_archivo'}
#
#     .- Fichero de búsqueda con el mismo nombre del modelo en la carpeta
#     'bus' de la aplicación (ej.: bus/Agente/Agente.yml)
#
#     .- Fichero de búsqueda con el mismo nombre del modelo en la carpeta
#     'bus' de algún módulo (ej.: modulos/venta/bus/Agente/Agente.yml)
#
#     .- El primer fichero que se encuentre en el orden:
#       bus/_usuarios/<usuario>/Modelo/*.yml
#       bus/Modelo/*.yml
#       modulos/*/bus/Modelo/*.yml
#
#   Las predeterminaciones (preferencias) se almacenarán en el fichero
#   bus/_usuarios/<usuario>/Modelo/_preferencias
#   y su estructura es:
#     controladorxx1: path_al_fichero_de_búsqueda
#     controladorxx2: path_al_fichero_de_búsqueda
#     ....
#   Así se puede tener una búsqueda predeterminada diferente para
#   cada controlador.
#
# Eliminar: Borra la búsqueda seleccionada.
#
# Excel: Exporta el contenido del grid a Excel.
#
# PDF: Genera un archivo PDF con el contenido del grid.
#
#
# La ventana de búsqueda se llama automáticamente desde el menú contextual
# de los campos 'id' pero también se podría llamar autónomamente con la url:
# /bus?mod=Modelo (p.ej.: /bus?mod=Cliente)
# Así se podría usar para poner un acceso directo en el menú a una ventana
# de búsqueda, o incluso añadirla al panel de control. En estos casos
# como no hay controlador subyacente se usará internamente el nombre de
# controlador '_'. Si en una ventana de éstas eligiéramos una búsqueda
# como predeterminada, en el fichero de preferencias figuraría como:
# _: path_al_fichero_de_búsqueda

class BusController < ApplicationController
  def bus
    @assets_stylesheets = %w(bus)
    @assets_javascripts = %w(bus)

    @help = flash[:help] || params[:help]

    @mod = flash[:mod] || params[:mod]
    if @mod.nil? || @mod == 'Usuario' && !@usu.admin
      render_error '404'
      return
    end

    ej = (flash[:eid] or flash[:jid]) ? [flash[:eid].to_s, flash[:jid].to_s] : get_empeje

    begin
      clm = @mod.constantize
    rescue
      render_error '404'
      return
    end

    # Controlar si el modelo tiene permisos a través de su controlador asociado.
    unless @usu.admin
      ctrl_perm = clm.ctrl_for_perms
      #unless @usu.pref[:permisos][:ctr][ctrl_perm] && @usu.pref[:permisos][:ctr][ctrl_perm][ej[0].to_i]
      if !@usu.pref.dig(:permisos, :ctr, ctrl_perm, ej[0].to_i) || clm.historico? && !@usu.pref.dig(:permisos, :ctr, '_acc_hist_', ej[0].to_i)
        render_error '401'
        return
      end
    end

    begin
      modelo_bus = clm.modelo_bus
      if modelo_bus
        @mod = modelo_bus
        @views = ([modelo_bus] + clm.db_views.to_a).uniq
        clm = modelo_bus.constantize
      else
        @views = [@mod] + clm.db_views.to_a
      end
    rescue => e
      logger.fatal "Búsqueda: modelo = #{@mod}"
      logger.fatal e.message
      logger.fatal e.backtrace.join("\n")

      head :no_content
    end

    tabla = clm.table_name

    ctr = flash[:ctr] || params[:ctr] || '_'

    w = flash[:wh] || ''
    if w[0] == '#'
      # Es el caso de que el where va implícito en un id de vistas. En este caso se recibe una cadena de la forma: #vid#campo
      w_a = w.split('#')
      v = Vista.find(w_a[1])
      w = v.data[:auto_comp][w_a[2].to_sym]
    end

    if clm.respond_to?('ejercicio_path')
      join_emej = clm.ejercicio_path
      add_where(w, "#{join_emej.empty? ? tabla : 't_emej'}.ejercicio_id=#{ej[1]}")
    elsif clm.respond_to?('empresa_path')
      join_emej = clm.empresa_path
      add_where(w, "#{join_emej.empty? ? tabla : 't_emej'}.empresa_id=#{ej[0]}")
    end

    # Añadir, si existe, un filtro especial definido en el modelo para limitar la búsqueda.
    # El método tiene que ser un método de clase (self.) y recibirá como argumento un hash
    # con los parámetros que se ven en la llamada de abajo.
    add_where(w, clm.bus_filter({usu: @usu, eid: ej[0], jid: ej[1]})) if clm.respond_to? :bus_filter

    # la clave 'tipo' del flash indica algún tipo de acción especial.
    # De momento se contempla 'hb' para histórico de borrados.
    if flash[:tipo] == 'hb'
      #cols = {'c01'=> {label: 'created_by.nombre', w: 200, type: :string}, 'c02' => {label: 'created_at', w: 130, type: :datetime}}
      cols = {c01: {label: 'created_by.nombre', w: 200, type: :string}, c02: {label: 'created_at', w: 130, type: :datetime}}
      last_col = 'c02'
    else
      cols = {}
      last_col = 'c00'
    end

    @nim_bus_lock = flash[:lock]

    @v = Vista.new
    @dat = @v.data = {
      mod: clm,
      view: clm,
      ctr: ctr,
      cols: cols,
      last_col: last_col,
      types:{},
      msel: flash[:msel],
      join_emej: join_emej,
      order: '',
      #who: flash[:wh].to_s,
      who: w,
      wh: w.dup,
      filters: {rules: []},
      eid: ej[0],
      jid: ej[1],
      rows: 50,
      tit: flash[:tit] || (clm.respond_to?(:nim_bus_tit) ? clm.nim_bus_tit(@dat[:eid], @dat[:jid], @usu) : nil) || "Búsqueda de #{nt(tabla)}",
      rld: flash[:rld] || params[:rld],
      home: Nimbus::BusPath + "/_usuarios/#{@usu.codigo}/#{@mod}"
    }
    @titulo = @dat[:tit]

    # Calcular fichero de preferencias
    fic_pref = flash[:pref] || params[:pref]
    fic_pref = nil unless File.exist?(fic_pref.to_s)

    unless fic_pref
      pref = "#{@dat[:home]}/_preferencias"
      if File.exist?(pref)
        fic_pref = YAML.load(File.read(pref))[ctr]
        fic_pref = nil unless File.exist?(fic_pref.to_s)
      end
    end

    # Construcción de de la lista de ficheros de búsqueda
    @sel = {}

    k = @usu.codigo
    Dir.glob("#{@dat[:home]}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
    }

    k = Nimbus::Gestion
    Dir.glob("#{Nimbus::BusPath}/#{@mod}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
      fic_pref ||= f if f[f.rindex('/')+1..-5] == @mod
    }

    Dir.glob("#{Nimbus::ModulosGlob}/bus/#{@mod}").each {|m|
      k = m.split('/')[1]
      Dir.glob(m + '/*.yml').each_with_index {|f, i|
        i == 0 ? @sel[k] = [f] : @sel[k] << f
        fic_pref ||= f if f[f.rindex('/')+1..-5] == @mod
      }
    }

    fic_pref ||= @sel.first[1][0] unless @sel.empty?
    # Si el tipo de la búsqueda es 'hb' (histórico de borrados) y no hay fichero de preferencias darle
    # el valor '*' que significa que luego en el callback al cargar el árbol de campos (método bus_sel)
    # se fuerce a cargar el grid con las columnas predefinidas para este tipo de búsqueda.
    fic_pref ||= '*' if flash[:tipo] == 'hb'

    ctr = flash[:ctr] || params[:ctr]

    @v.save

    @ajax = "_vista=#{@v.id};"
    @ajax << (ctr ? "_controlador_edit='#{ctr}';" : "_controlador_edit='#{@mod.include?('::') ? clm.table_name.sub('_', '/') : clm.table_name}';")
    @ajax << "fic_pref=#{fic_pref.to_json};"
    @ajax << "view='#{clm}';"
    @ajax << "empresa='#{ej[0]}';"
    # Si hay definido un tipo especial de búsqueda (p.ej. histórico de borrados (hb)) dar valor "*" a _autoCompField
    # y almacenar el tipo en la variable busTipo para que al hacer doble click sobre un registro se haga la acción oportuna.
    @ajax << "_autoCompField='*';_busTipo=#{flash[:tipo].to_json};" if flash[:tipo]

    @ajax << "nimRldServer=#{@dat[:rld] ? 'true' : 'false'};"

    @tipo_bus = flash[:tipo].to_s
  end

  def list
    unless @v
      #render nothing: true
      head :no_content
      return
    end

    cols = @dat[:cols]

    if :cols.empty?
      #render nothing: true
      head :no_content
      return
    end

    #clm = @dat[:mod]
    clm = @dat[:view]
    tabla = clm.table_name

    w = @dat[:wh].dup

    if params[:filters]
      #@dat[:filters] = eval(params[:filters])
      @dat[:filters] = JSON.parse(params[:filters]).deep_symbolize_keys
      @dat[:filters][:rules].each {|f|
        #[:eq,:ne,:lt,:le,:gt,:ge,:bw,:bn,:in,:ni,:ew,:en,:cn,:nc,:nu,:nn]
        op = f[:op].to_sym
        cmp = cols[f[:field].to_sym]
        cmp_db = cmp[:cmp_db]

        if op == :nu or op == :nn
          add_where w, cmp_db
          w << ' IS'
          w << ' NOT' if op == :nn
          w << ' NULL'
          next
        end

        ty = cmp[:type]
        add_where w, ([:bn,:ni,:en,:nc].include?(op) ? 'NOT ' : '') + (ty == 'string' ? 'UNACCENT(LOWER(' + cmp_db + '))' : cmp_db)
        w << ({eq: '=', ne: '<>', cn: ' LIKE ', bw: ' LIKE ', ew: ' LIKE ', nc: ' LIKE ', bn: ' LIKE ', en: ' LIKE ', in: ' IN (', ni: ' IN (', lt: '<', le: '<=', gt: '>', ge: '>='}[op] || '=')
        if op == :in or op == :ni
          #f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase + '\','}
          f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase.gsub('\'', '\'\'') + '\','}
          w.chop!
          w << ')'
        else
          w << '\''
          w << '%' if [:ew,:en,:cn,:nc].include?(op)
          #w << (ty == 'string' ? I18n.transliterate(f[:data]).downcase : f[:data])
          w << (ty == 'string' ? I18n.transliterate(f[:data]).downcase.gsub('\'', '\'\'') : f[:data].gsub('\'', '\'\''))
          w << '%' if [:bw,:bn,:cn,:nc].include?(op)
          w << '\''
        end
      }
    else
      @dat[:filters] = {rules: []}
    end

    # Formar la cadena de ordenación
    #
    @dat[:order] = params[:sidx].empty? ? '' : params[:sidx] + ' ' + params[:sord]
    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << cols[c2[0].to_sym][:cmp_db]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    @dat[:cad_where] = w
    @dat[:cad_order] = ord
    lim = @dat[:rows] = params[:rows] == '10000' ? 0 : params[:rows].to_i

    res = {page: 0, total: 0, records: 0, rows: [id: 0, cell: []]}
    if lim > 0 && (params[:rld] || !@dat[:rld])
      begin
        #tot_records = @dat[:cad_sel].empty? ? 0 : clm.select(:id).joins(@dat[:cad_join]).where(w).size
        if @dat[:cad_sel].empty?
          tot_records = 0
        else
          tot_records = clm.joins(@dat[:cad_join]).where(w)
          tot_records = tot_records.fonargs(*clm.nim_fon_args(@dat[:eid], @dat[:jid], @usu)) if clm.respond_to?(:nim_fon_args)
          tot_records = tot_records.size
        end
        tot_pages = tot_records / lim
        tot_pages += 1 if tot_records % lim != 0
        page = params[:page].to_i
        page = tot_pages if page > tot_pages
        page = 1 if page <=0

        #sql = @dat[:cad_sel].empty? ? [] : clm.select(tabla + '.id,' + @dat[:cad_sel]).joins(@dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)
        if @dat[:cad_sel].empty?
          sql = []
        else
          sql = clm.select(tabla + '.id,' + @dat[:cad_sel]).joins(@dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)
          sql = sql.fonargs(*clm.nim_fon_args(@dat[:eid], @dat[:jid], @usu)) if clm.respond_to?(:nim_fon_args)
        end

        res = {page: page, total: tot_pages, records: tot_records, rows: []}
        sql.each {|s|
          h = {:id => s.id, :cell => []}
          cols.each {|k, v|
            begin
              # Para acceder a los atributos de "s" es mejor usar el hash "attributes" que acceder a pelo (s[atributo]) porque el atributo "id" cuando
              # la tabla que se procesa es una vista no es accesible "a pelo"
              h[:cell] << _forma_campo(:grid, v, '', s.attributes[v[:alias]])
            rescue
              h[:cell] << ''
            end
          }
          res[:rows] << h
        }
      rescue => e
        logger.debug e.message
        logger.debug e.backtrace.join("\n")
      end
    end

    render :json => res

    @v.save
  end

  def genera_grid(kh, kv)
    #mp = mselect_parse(@dat[:view], @dat[:cols].map{|k, v| v[:label]})
    mp = mselect_parse(@dat[:view], @dat[:cols].map{|k, v| v[:label]} + @dat[:msel].to_a)
    @dat[:cad_sel] = mp[:cad_sel]
    jemej = @dat[:join_emej].to_s.empty? ? '' : ljoin_parse_alias(@dat[:view], 'iz', @dat[:join_emej] + '(t_emej)')[:cad]
    @dat[:cad_join] = mp[:cad_join] + ' ' + jemej

    col_mod = @dat[:cols].map {|k, c|
      c[:cmp_db] = mp[:alias_cmp][c[:label]][:cmp_db]
      c[:alias] = mp[:alias_cmp][c[:label]][:alias]
      h = {name: k.to_s, label: c[:label], type: c[:type], width: c[:w], searchoptions: {}, flag: true}
      case c[:type]
        when 'boolean'
          h[:align] = 'center'
          h[:formatter] = '~format_check~'
          h[:searchoptions][:sopt] = ['eq']
        when 'integer', 'decimal'
          h[:align] = 'right'
          h[:searchoptions][:sopt] = ['eq','ne','lt','le','gt','ge','in','ni','nu','nn']
        when 'date', 'time'
          h[:align] = 'center'
          h[:searchoptions][:sopt] = ['eq','ne','lt','le','gt','ge','nu','nn']
          h[:searchoptions][:dataInit] = '~function(e){date_pick(e)}~'
        when 'datetime'
          h[:align] = 'center'
          h[:searchoptions][:sopt] = ['ge','le','gt','lt','eq','ne','nu','nn']
        else
          h[:searchoptions][:sopt] = ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
      end
      h
    }

    # Construir filters

    if @dat[:filters][:rules].empty?
      postdata = {}
    else
      @dat[:filters][:rules].each {|r|
        col_mod.each {|c|
          if c[:name] == r[:field] and c[:flag]
            c[:flag] = false
            i = c[:searchoptions][:sopt].index(r[:op])
            if i > 0
              c[:searchoptions][:sopt].delete_at(i)
              c[:searchoptions][:sopt].unshift(r[:op])
            end
          end
        }
      }

      postdata = {filters: @dat[:filters].to_json}
    end

    lb = @dat[:order].rindex(' ')
    if lb
      sortname = @dat[:order][0..lb]
      sortorder = @dat[:order][lb+1..-1]
    else
      sortname = ''
      sortorder = ''
    end

    @ajax << "generaGrid(#{col_mod.to_json.gsub('"~', '').gsub('~"', '')}, #{@dat[:rows]}, '#{sortname}', '#{sortorder}', #{postdata.to_json}, #{kh}, #{kv});"
  end

  def nueva_col
    return unless @v

    #arg = eval(params[:dat])
    arg = JSON.parse(params[:dat]).deep_symbolize_keys
    col = arg[:col]

    @dat[:cols] = arg[:cols]

    rul = @dat[:filters][:rules]

    keep_scroll_v = true

    if arg[:modo] == 'del'
=begin
      name_col = nil
      @dat[:cols].reverse_each {|k, v|
        if v[:label] == col
          name_col = k
          break
        end
      }

      @dat[:cols].delete(name_col)
      name_col = name_col.to_s
=end
      @dat[:cols].delete(col.to_sym)

      # Eliminar la columna col de la cadena de order
      vo = @dat[:order].split(', ')
      (vo.size - 1).downto(0).each {|i|
        #if vo[i].starts_with?(name_col + ' ')
        if vo[i].starts_with?(col + ' ')
          vo.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
      @dat[:order] = vo.join(', ') unless keep_scroll_v

      # Eliminar la columna col del hash de filter si está incluida
      (rul.size - 1).downto(0).each {|i|
        #if rul[i]['field'] == name_col
        if rul[i][:field] == col
          rul.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
    else
      @dat[:cols][@dat[:last_col].next!.to_sym] =  {label: col, w: 150, type: arg[:type]}
    end

    genera_grid((arg[:modo] == 'del' ? true : 99999), keep_scroll_v)
    @ajax << "$('#view-sel').attr('disabled', #{@dat[:cols].empty? ? 'false' : 'true'});"
  end

  def bus_value
    return '' unless @v

    #mod =  @dat[:mod]
    mod =  @dat[:view]
    ty = params[:type] ? params[:type].to_sym : :form
    val =  mod.mselect(mod.auto_comp_mselect).where("#{mod.table_name}.id = #{params[:id]}")
    val = val.fonargs(*mod.nim_fon_args(@dat[:eid], @dat[:jid], @usu)) if mod.respond_to?(:nim_fon_args)
    val =  val[0].auto_comp_value(ty)
    @ajax << "_autoCompField.val('#{val}');"
    @ajax << 'window.close();'
  end

  def bus_save
    return unless @v

    arg = JSON.parse(params[:dat]).deep_symbolize_keys

    h = {view: @dat[:view].to_s, cols: arg[:cols], filters: @dat[:filters], order: @dat[:order], rows: @dat[:rows]}
    FileUtils.mkdir_p(@dat[:home])
    File.write("#{@dat[:home]}/#{params[:fic]}.yml", h.to_yaml)
  end

  def change_table_in_view(view)
    tabla = view.table_name

    @dat[:who] = '(' + @dat[:who] + ')' if @dat[:who].present? && @dat[:who][0] != '('
    @dat[:who].gsub!(/\W#{@dat[:view].table_name}\./) {|a| a[0] + tabla + '.'}

    @dat[:wh] = @dat[:who].dup

    if view.respond_to?('ejercicio_path')
      @dat[:join_emej] = view.ejercicio_path
      w = "#{@dat[:join_emej].empty? ? tabla : 't_emej'}.ejercicio_id=#{@dat[:jid]}"
      add_where(@dat[:wh], w) unless @dat[:wh].include?(w)
    elsif view.respond_to?('empresa_path')
      @dat[:join_emej] = view.empresa_path
      w = "#{@dat[:join_emej].empty? ? tabla : 't_emej'}.empresa_id=#{@dat[:eid]}"
      add_where(@dat[:wh], w) unless @dat[:wh].include?(w)
    end
  end

  def bus_sel
    return unless @v

    if params[:fic] == '*'
      # Es el caso en que sólo se pide forzar la carga inicial del grid
      # no hay fichero que cargar, sólo refrescar.
      genera_grid(false, false)
      return
    end

    h = YAML.load(File.read(params[:fic]))
    h[:view] = h[:view] ? h[:view].constantize : @dat[:mod]
    @ajax << "view='#{h[:view]}';$('#view-sel').val(view).attr('disabled', true);"
    if h[:view] != @dat[:view]
      change_table_in_view(h[:view])
      @ajax << "$('#tree-campos').tree('loadDataFromUrl', '/gi/campos?node=#{h[:view]}');"
    end
    @dat.merge! h
    @ajax << "$('#l-titulo').text(#{(h[:view].respond_to?(:nim_bus_tit) ? h[:view].nim_bus_tit(@dat[:eid], @dat[:jid], @usu) : @dat[:tit]).to_json});"
    genera_grid(false, false)
    @dat[:last_col] = @dat[:cols].map{|k, v| k}.max.to_s
  end

  def bus_send
    envia_fichero(file: "/tmp/nim#{@v.id}.#{@dat[:file_type]}", file_cli: "#{@dat[:mod].table_name}.#{@dat[:file_type]}", rm: true, disposition: @dat[:file_type] == 'pdf' ? 'inline' : 'attachment')
  end

  def bus_export
    return unless @v

    label = 'Obteniendo información'
    exe_p2p(label: label, width: 400, cancel: true, info: "bus: #{@dat[:view]}", tag: (params[:tipo] == 'xlsx' ? :xls : :loff), fin: :bus_send) {
      begin
        cols = @dat[:cols]

        xls = Axlsx::Package.new
        wb = xls.workbook
        sh = wb.add_worksheet(:name => "Hoja1")

        sty, typ = array_estilos_tipos_axlsx(cols.map{|k, v| v}, wb)

        # Primera fila (Cabecera)
        sh.add_row(cols.map {|k, v| v[:label]})

        @dat[:view].select(@dat[:cad_sel]).joins(@dat[:cad_join]).where(@dat[:cad_where]).order(@dat[:cad_order]).each {|s|
          sh.add_row(cols.map {|k, v| Nimbus.nimval(s[v[:alias]])}, types: typ, style: sty)
        }

        # Fijar la fila de cabecera para repetir en cada página
        wb.add_defined_name("Hoja1!$1:$1", :local_sheet_id => sh.index, :name => '_xlnm.Print_Titles')

        xls.serialize("/tmp/nim#{@v.id}.xlsx")
        #`libreoffice --headless --convert-to pdf --outdir /tmp /tmp/nim#{@v.id}.xlsx` if params[:tipo] == 'pdf'
        if params[:tipo] == 'pdf'
          p2p label: label << '<br>Generando PDF'
          h = spawn "libreoffice -env:UserInstallation=file:///tmp/nim#{@v.id}_lo_dir --headless --convert-to pdf --outdir /tmp /tmp/nim#{@v.id}.xlsx"
          Process.wait h
          FileUtils.rm_rf %W(/tmp/nim#{@v.id}.xlsx /tmp/nim#{@v.id}_lo_dir)
        end
        @dat[:file_type] = params[:tipo]
      rescue => e
        FileUtils.rm_rf Dir.glob("/tmp/nim#{@v.id}*")
        raise e
      end
    }
  end

  def bus_pref
    return unless @v

    pref = @dat[:home] + '/_preferencias'
    if File.exist?(pref)
      hpref = YAML.load(File.read(pref))
      hpref[@dat[:ctr]] = params[:fic]
    else
      hpref = {@dat[:ctr] => params[:fic]}
      FileUtils.mkdir_p(@dat[:home])
    end

    File.write(pref, hpref.to_yaml)
  end

  def bus_del
    f = params[:fic]
    FileUtils.rm(f, {force: true}) if f.starts_with?(@dat[:home]) && !f.include?('..')
  end

  def view_sel
    view = params[:view].constantize
    change_table_in_view(view)
    @dat[:view] = view
    @dat[:cols] = {}
    @dat[:last_col] = 'c00'
    @dat[:types] = {}
    @dat[:order] = ''
    @dat[:filters] = {rules: []}

    @ajax << "$('#l-titulo').text(#{(view.respond_to?(:nim_bus_tit) ? view.nim_bus_tit(@dat[:eid], @dat[:jid], @usu) : @dat[:tit]).to_json});"

    genera_grid(false, false)
  end

  def reset_filtros
    @dat[:filters] = {rules: []}
    genera_grid(false, false)
  end
end
