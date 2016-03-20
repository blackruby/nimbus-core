class BusController < ApplicationController
  def bus
    @titulo = nt('bus')

    @mod = params[:mod]
    if @mod.nil?
      render nothing: true
      return
    end

    @vid = Vista.create.id

    ej = get_empeje

    @tabla = nt @mod.constantize.table_name

    $h[@vid] = {mod: @mod.constantize, cols: {}, last_col: 'c00', types:{}, order: '', filters: {rules: []}, eid: ej[0], jid: ej[1]}

    # Construcción de de la lista de ficheros de búsqueda
    @sel = {}

    k = @usu.codigo
    Dir.glob("bus/usuarios/#{k}/#{@mod}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
    }

    k = Rails.app_class.to_s.split(':')[0]
    Dir.glob("bus/#{@mod}/*.yml").each_with_index {|f, i|
      i == 0 ? @sel[k] = [f] : @sel[k] << f
    }

    Dir.glob("modulos/*/bus/#{@mod}").each {|m|
      k = m.split('/')[1]
      Dir.glob(m + '/*.yml').each_with_index {|f, i|
        i == 0 ? @sel[k] = [f] : @sel[k] << f
      }
    }

    #genera_grid_from_file(@sel.first[1][0], $h[@vid]) unless @sel.empty?
    @ajax = @sel.empty? ? '' : "callFonServer('bus_sel', {fic: '#{@sel.first[1][0]}'});"
  end

  def list
    # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)
    unless request.xhr?
      render nothing: true
      return
    end

    vid = params[:vista].to_i
    unless vid
      render nothing: true
      return
    end

    dat = $h[vid]
    cols = dat[:cols]

    if :cols.empty?
      render nothing: true
      return
    end

    clm = dat[:mod]
    tabla = clm.table_name

    w = ''

    add_where(w, tabla + '.empresa_id=' + dat[:eid]) if clm.column_names.include?('empresa_id')
    add_where(w, tabla + '.ejercicio_id=' + dat[:jid]) if clm.column_names.include?('ejercicio_id')

    if params[:filters]
      dat[:filters] = eval(params[:filters])
      dat[:filters][:rules].each {|f|
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
      dat[:filters] = {rules: []}
    end

    # Formar la cadena de ordenación
    #
    dat[:order] = params[:sidx].empty? ? '' : params[:sidx] + params[:sord]
    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << cols[c2[0].to_sym][:cmp_db]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    dat[:cad_where] = w
    dat[:cad_order] = ord

    tot_records = clm.select(:id).joins(dat[:cad_join]).where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    sql = clm.select(tabla + '.id,' + dat[:cad_sel]).joins(dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      cols.each {|k, v|
        begin
          h[:cell] << s[v[:alias]].to_s
        rescue
          h[:cell] << ''
        end
      }
      res[:rows] << h
    }
    render :json => res
  end

  def genera_grid(dat, kh, kv)
    mp = mselect_parse(dat[:mod], dat[:cols].map{|k, v| v[:label]})
    dat[:cad_sel] = mp[:cad_sel]
    dat[:cad_join] = mp[:cad_join]

    col_mod = dat[:cols].map {|k, c|
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
    on_load = ''
    dat[:filters][:rules].each {|r|
      col_mod.each {|c|
        if c[:name] == r[:field] and c[:flag]
          c[:flag] = false
          on_load << "$('#gs_#{r[:field]}').val(#{r[:data].to_json});"
          i = c[:searchoptions][:sopt].index(r[:op])
          if i > 0
            c[:searchoptions][:sopt].delete_at(i)
            c[:searchoptions][:sopt].unshift(r[:op])
          end
        end
      }
    }
    postdata = {filters: dat[:filters].to_json}

    lb = dat[:order].rindex(' ')
    if lb
      sortname = dat[:order][0..lb]
      sortorder = dat[:order][lb+1..-1]
    else
      sortname = ''
      sortorder = ''
    end

    @ajax << "generaGrid(#{col_mod.to_json.gsub('"~', '').gsub('~"', '')}, '#{sortname}', '#{sortorder}', #{postdata.to_json}, #{on_load.to_json}, #{kh}, #{kv});"
  end

  def nueva_col
    vid = params[:vista].to_i
    return unless vid

    dat = $h[vid]
    arg = eval(params[:dat])
    col = arg[:col]

    dat[:cols] = arg[:cols]

    rul = dat[:filters][:rules]

    keep_scroll_v = true

    if arg[:modo] == 'del'
      name_col = nil
      dat[:cols].reverse_each {|k, v|
        if v[:label] == col
          name_col = k
          break
        end
      }

      dat[:cols].delete(name_col)
      name_col = name_col.to_s

      # Eliminar la columna col de la cadena de order
      vo = dat[:order].split(', ')
      (vo.size - 1).downto(0).each {|i|
        if vo[i].starts_with?(name_col + ' ')
          vo.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
      dat[:order] = vo.join(', ') unless keep_scroll_v

      # Eliminar la columna col del hash de filter si está incluida
      (rul.size - 1).downto(0).each {|i|
        if rul[i][:field] == name_col
          rul.delete_at(i)
          keep_scroll_v = false
          break
        end
      }
    else
      dat[:cols][dat[:last_col].next!.to_sym] =  {label: col, w: 150, type: arg[:type]}
    end

    genera_grid(dat, arg[:modo] == 'del', keep_scroll_v)
  end

  def bus_value
    vid = params[:vista].to_i
    return '' unless vid

    val =  $h[vid][:mod].find(params[:id].to_i).auto_comp_value(:form)
    @ajax << "_autoCompField.val('#{val}');"
    @ajax << 'window.close();'
  end

  def bus_save
    vid = params[:vista].to_i
    return unless vid

    dat = $h[vid]

    arg = eval(params[:dat])

    h = {cols: arg[:cols], filters: dat[:filters], order: dat[:order]}
    path = "bus/usuarios/#{@usu.codigo}/#{dat[:mod]}"
    FileUtils.mkdir_p(path)
    File.write("#{path}/#{params[:fic]}.yml", h.to_yaml)
  end

  def genera_grid_from_file(fic, dat)
    dat.merge! YAML.load(File.read(fic))
    genera_grid(dat, false, false)
    dat[:last_col] = dat[:cols].map{|k, v| k}.max.to_s
  end

  def bus_sel
    vid = params[:vista].to_i
    return unless vid

    genera_grid_from_file(params[:fic], $h[vid])
  end

  def bus_send
    vid = params[:vista].to_i
    return unless vid

    dat = $h[vid]

    send_data File.read("/tmp/nim#{vid}.#{dat[:file_type]}"), filename: "#{dat[:mod].table_name}.#{dat[:file_type]}"
    FileUtils.rm "/tmp/nim#{vid}.xlsx", force: true
    FileUtils.rm "/tmp/nim#{vid}.pdf", force: true if dat[:file_type] == 'pdf'
  end

  def bus_export
    vid = params[:vista].to_i
    return unless vid

    dat = $h[vid]
    cols = dat[:cols]

    xls = Axlsx::Package.new
    wb = xls.workbook
    sh = wb.add_worksheet(:name => "Hoja 1")

    dat[:mod].select(dat[:cad_sel]).joins(dat[:cad_join]).where(dat[:cad_where]).order(dat[:cad_order]).each {|s|
      sh.add_row(cols.map {|k, v| s[v[:alias]]})
    }

    xls.serialize("/tmp/nim#{vid}.xlsx")
    `libreoffice --headless --convert-to pdf --outdir /tmp /tmp/nim#{vid}.xlsx` if params[:tipo] == 'pdf'
    dat[:file_type] = params[:tipo]
    @ajax << "window.location.href='/bus/send?vista=#{vid}';"
  end

  def bus_bye
  end
end
