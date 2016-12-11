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

    @titulo = nt('bus')

    @mod = flash[:mod] || params[:mod]
    if @mod.nil?
      render nothing: true
      return
    end

    clm = @mod.constantize
    tabla = clm.table_name
    @tabla = nt tabla

    ctr = flash[:ctr] || params[:ctr] || '_'

    ej = (flash[:eid] or flash[:jid]) ? [flash[:eid].to_s, flash[:jid].to_s] : get_empeje

    w = flash[:wh] || ''

    #add_where(w, tabla + '.empresa_id=' + ej[0]) if clm.column_names.include?('empresa_id')
    #add_where(w, tabla + '.ejercicio_id=' + ej[1]) if clm.column_names.include?('ejercicio_id')
    if clm.respond_to?('ejercicio_path')
      join_emej = clm.ejercicio_path
      add_where(w, "#{join_emej.empty? ? tabla : 't_emej'}.ejercicio_id=#{ej[1]}")
    elsif clm.respond_to?('empresa_path')
      join_emej = clm.empresa_path
      add_where(w, "#{join_emej.empty? ? tabla : 't_emej'}.empresa_id=#{ej[0]}")
    end

    @v = Vista.new
    @v.data = {mod: clm, ctr: ctr, cols: {}, last_col: 'c00', types:{}, join_emej: join_emej, order: '', wh: w, filters: {rules: []}, eid: ej[0], jid: ej[1]}

    # Calcular fichero de preferencias
    fic_pref = nil
    pref = "bus/_usuarios/#{@usu.codigo}/#{@mod}/_preferencias"
    if File.exists?(pref)
      fic_pref = YAML.load(File.read(pref))[ctr]
      fic_pref = nil unless File.exists?(fic_pref.to_s)
    end

    unless fic_pref
      fic_pref = flash[:pref] || params[:pref]
      fic_pref = nil unless File.exists?(fic_pref.to_s)
    end

    # Construcción de de la lista de ficheros de búsqueda
    @sel = {}

    k = @usu.codigo
    Dir.glob("bus/_usuarios/#{k}/#{@mod}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
    }

    k = Rails.app_class.to_s.split(':')[0]
    Dir.glob("bus/#{@mod}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
      fic_pref ||= f if f[f.rindex('/')+1..-5] == @mod
    }

    Dir.glob("modulos/*/bus/#{@mod}").each {|m|
      k = m.split('/')[1]
      Dir.glob(m + '/*.yml').each_with_index {|f, i|
        i == 0 ? @sel[k] = [f] : @sel[k] << f
        fic_pref ||= f if f[f.rindex('/')+1..-5] == @mod
      }
    }

    fic_pref ||= @sel.first[1][0] unless @sel.empty?

    @v.save

    @ajax = "_vista=#{@v.id};"
    @ajax << (params[:ctr] ? "_controlador_edit='#{params[:ctr]}';" : "_controlador_edit='#{clm.table_name}';")
    #@ajax << (fic_pref ? "callFonServer('bus_sel', {fic: '#{fic_pref}'}); $('#bus-sel').val('#{fic_pref}')" : '')
    @ajax << "fic_pref=#{fic_pref.to_json};"
  end

  def list
    unless @v
      render nothing: true
      return
    end

    cols = @dat[:cols]

    if :cols.empty?
      render nothing: true
      return
    end

    clm = @dat[:mod]
    tabla = clm.table_name

    #w = ''

    #add_where(w, tabla + '.empresa_id=' + dat[:eid]) if clm.column_names.include?('empresa_id')
    #add_where(w, tabla + '.ejercicio_id=' + dat[:jid]) if clm.column_names.include?('ejercicio_id')

    w = @dat[:wh].dup

    if params[:filters]
      @dat[:filters] = eval(params[:filters])
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
          f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase + '\','}
          w.chop!
          w << ')'
        else
          w << '\''
          w << '%' if [:ew,:en,:cn,:nc].include?(op)
          w << (ty == 'string' ? I18n.transliterate(f[:data]).downcase : f[:data])
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

    tot_records = @dat[:cad_sel].empty? ? 0 : clm.select(:id).joins(@dat[:cad_join]).where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    sql = @dat[:cad_sel].empty? ? [] : clm.select(tabla + '.id,' + @dat[:cad_sel]).joins(@dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      cols.each {|k, v|
        begin
          case v[:type]
          when 'datetime'
            h[:cell] << s[v[:alias]].to_time.strftime('%d-%m-%Y %H:%M:%S')
          else
            h[:cell] << s[v[:alias]].to_s
          end
        rescue
          h[:cell] << ''
        end
      }
      res[:rows] << h
    }
    render :json => res

    @v.save
  end

  def genera_grid(kh, kv)
    mp = mselect_parse(@dat[:mod], @dat[:cols].map{|k, v| v[:label]})
    @dat[:cad_sel] = mp[:cad_sel]
    jemej = @dat[:join_emej].to_s.empty? ? '' : ljoin_parse(@dat[:mod], @dat[:join_emej] + '(t_emej)')[:cad]
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
        when 'date'
          h[:align] = 'center'
          h[:searchoptions][:sopt] = ['eq','ne','lt','le','gt','ge','nu','nn']
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

    @ajax << "generaGrid(#{col_mod.to_json.gsub('"~', '').gsub('~"', '')}, '#{sortname}', '#{sortorder}', #{postdata.to_json}, #{kh}, #{kv});"
  end

  def nueva_col
    #vid = params[:vista].to_i
    #return unless vid
    return unless @v

    #dat = $h[vid]
    arg = eval(params[:dat])
    col = arg[:col]

    @dat[:cols] = arg[:cols]

    rul = @dat[:filters][:rules]

    keep_scroll_v = true

    if arg[:modo] == 'del'
      name_col = nil
      @dat[:cols].reverse_each {|k, v|
        if v[:label] == col
          name_col = k
          break
        end
      }

      @dat[:cols].delete(name_col)
      name_col = name_col.to_s

      # Eliminar la columna col de la cadena de order
      vo = @dat[:order].split(', ')
      (vo.size - 1).downto(0).each {|i|
        if vo[i].starts_with?(name_col + ' ')
          vo.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
      @dat[:order] = vo.join(', ') unless keep_scroll_v

      # Eliminar la columna col del hash de filter si está incluida
      (rul.size - 1).downto(0).each {|i|
        if rul[i][:field] == name_col
          rul.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
    else
      @dat[:cols][@dat[:last_col].next!.to_sym] =  {label: col, w: 150, type: arg[:type]}
    end

    genera_grid(arg[:modo] == 'del', keep_scroll_v)
  end

  def bus_value
    return '' unless @v

    mod =  @dat[:mod]
    val =  mod.mselect(mod.auto_comp_mselect).where("#{mod.table_name}.id = #{params[:id]}")[0].auto_comp_value(:form)
    @ajax << "_autoCompField.val('#{val}');"
    @ajax << 'window.close();'
  end

  def bus_save
    return unless @v

    arg = eval(params[:dat])

    h = {cols: arg[:cols], filters: @dat[:filters], order: @dat[:order]}
    path = "bus/_usuarios/#{@usu.codigo}/#{@dat[:mod]}"
    FileUtils.mkdir_p(path)
    File.write("#{path}/#{params[:fic]}.yml", h.to_yaml)
  end

  def genera_grid_from_file(fic)
    @dat.merge! YAML.load(File.read(fic))
    genera_grid(false, false)
    @dat[:last_col] = @dat[:cols].map{|k, v| k}.max.to_s
  end

  def bus_sel
    return unless @v

    genera_grid_from_file(params[:fic])
  end

  def bus_send
    vid = flash[:vista]
    @v = Vista.find_by id: vid
    if @v
      dat = @v.data
    else
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    send_data File.read("/tmp/nim#{vid}.#{dat[:file_type]}"), filename: "#{dat[:mod].table_name}.#{dat[:file_type]}"
    FileUtils.rm "/tmp/nim#{vid}.xlsx", force: true
    FileUtils.rm "/tmp/nim#{vid}.pdf", force: true if dat[:file_type] == 'pdf'
  end

  def bus_export
    return unless @v

    cols = @dat[:cols]

    xls = Axlsx::Package.new
    wb = xls.workbook
    sh = wb.add_worksheet(:name => "Hoja1")

    sh.add_row(cols.map {|k, v| v[:label]})

    @dat[:mod].select(@dat[:cad_sel]).joins(@dat[:cad_join]).where(@dat[:cad_where]).order(@dat[:cad_order]).each {|s|
      sh.add_row(cols.map {|k, v| v[:type] == 'string' ? ' ' + s[v[:alias]].to_s : s[v[:alias]]})
    }

    # Fijar la fila de cabecera para repetir en cada página
    wb.add_defined_name("Hoja1!$1:$1", :local_sheet_id => sh.index, :name => '_xlnm.Print_Titles')

    xls.serialize("/tmp/nim#{@v.id}.xlsx")
    `libreoffice --headless --convert-to pdf --outdir /tmp /tmp/nim#{@v.id}.xlsx` if params[:tipo] == 'pdf'
    @dat[:file_type] = params[:tipo]
    @ajax << "window.location.href='/bus/send';"
    flash[:vista] = @v.id
  end

  def bus_pref
    return unless @v

    path = "bus/_usuarios/#{@usu.codigo}/#{@dat[:mod]}"
    pref = path + '/_preferencias'
    if File.exists?(pref)
      hpref = YAML.load(File.read(pref))
      hpref[@dat[:ctr]] = params[:fic]
    else
      hpref = {@dat[:ctr] => params[:fic]}
      FileUtils.mkdir_p(path)
    end

    File.write(pref, hpref.to_yaml)
  end

  def bus_del
    f = params[:fic]
    FileUtils.rm(f, {force: true}) if f.starts_with?("bus/_usuarios/#{@usu.codigo}/")
  end
end
