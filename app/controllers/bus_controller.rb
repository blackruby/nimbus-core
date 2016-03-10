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

    $h[@vid] = {mod: @mod.constantize, cols: [], types:{}, eid: ej[0], jid: ej[1]}
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

    if dat[:cols].empty?
      render nothing: true
      return
    end

    clm = dat[:mod]
    tabla = clm.table_name

    w = ''

    add_where(w, tabla + '.empresa_id=' + dat[:eid]) if clm.column_names.include?('empresa_id')
    add_where(w, tabla + '.ejercicio_id=' + dat[:jid]) if clm.column_names.include?('ejercicio_id')

    if params[:filters]
      fil = eval(params[:filters])
      fil[:rules].each {|f|
        #[:eq,:ne,:lt,:le,:gt,:ge,:bw,:bn,:in,:ni,:ew,:en,:cn,:nc,:nu,:nn]
        op = f[:op].to_sym

        if op == :nu or op == :nn
          add_where w, f[:field]
          w << ' IS'
          w << ' NOT' if op == :nn
          w << ' NULL'
          next
        end

        ty = dat[:types][f[:field]]
        add_where w, ([:bn,:ni,:en,:nc].include?(op) ? 'NOT ' : '') + (ty == 'string' ? 'UNACCENT(LOWER(' + f[:field] + '))' : f[:field])
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
    end

    # Formar la cadena de ordenación y seguir incluyendo tablas en eager-load
    #
    dat[:sortname] = params[:sidx]
    dat[:sortorder] = params[:sord]
    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << c2[0]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    #tot_records = clm.select(:id).joins(eager.map{|j| j.to_sym}).where(w).size
    tot_records = clm.select(:id).joins(dat[:cad_join]).where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    #sql = clm.eager_load(eager).where(w).where(params[:wh]).order(ord).offset((page-1)*lim).limit(lim)
    #sql = clm.select('id,' + dat[:cols].map{|c| c[:col]}.join(',')).where(w).order(ord).offset((page-1)*lim).limit(lim)
    sql = clm.select(tabla + '.id,' + dat[:cad_sel]).joins(dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)
    puts sql.inspect

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      dat[:cols].each {|c|
        begin
          h[:cell] << s[dat[:alias_cmp][c[:col]][:alias]].to_s
        rescue
          h[:cell] << ''
        end
      }
      res[:rows] << h
    }
    render :json => res
  end

  def nueva_col
    vid = params[:vista].to_i
    return unless vid

    dat = $h[vid]
    arg = eval(params[:dat])
    col = arg[:col]

    dat[:cols] = arg[:cols]

    keep_scroll = true

    if arg[:modo] == 'del'
      (dat[:cols].size - 1).downto(0).each {|i|
        if dat[:cols][i][:col] == col
          dat[:cols].delete_at(i)
          break
        end
      }

      # Construir el array de order
      ord = []
      cmp = nil
      (dat[:sortname] + dat[:sortorder]).gsub(',', '').split(' ').each_with_index { |s, i|
        if i.odd?
          ord << [cmp, s]
        else
          dat[:alias_cmp].each{|k, v|
            if v[:cmp_db] == s
              cmp = k
              break
            end
          }
        end
      }

      # Eliminar la columna col del array de order si está incluida
      (ord.size - 1).downto(0).each {|i|
        if ord[i][0] == col
          ord.delete_at(i)
          keep_scroll = false
          break
        end
      }

    else
      dat[:cols] << {col: col, w: 150}
    end

    mp = mselect_parse(dat[:mod], dat[:cols].map{|c| c[:col]})
    dat[:cad_sel] = mp[:cad_sel]
    dat[:cad_join] = mp[:cad_join]
    dat[:alias_cmp] = mp[:alias_cmp]
    dat[:types][dat[:alias_cmp][col][:cmp_db]] = arg[:type] if arg[:modo] == 'add'

    puts dat.inspect

    col_mod = dat[:cols].map.with_index{|c, i|
      h = {name: 'c' + i.to_s, label: c[:col], index: mp[:alias_cmp][c[:col]][:cmp_db], width: c[:w], searchoptions: {}}
      case dat[:types][c[:col]]
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

    # Construir cadena de ordenación
    if arg[:modo] == 'del'
      dat[:sortname] = ''
      ord.each {|s|
        dat[:sortname] << dat[:alias_cmp][s[0]][:cmp_db] + ' ' + s[1] + ', '
      }
      if dat[:sortname].empty?
        dat[:sortorder] = ''
      else
        dat[:sortname].chop!.chop!
        lb = dat[:sortname].rindex(' ')
        dat[:sortorder] = dat[:sortname][lb+1..-1]
        dat[:sortname] = dat[:sortname][0..lb]
      end
    end

    @ajax << "generaGrid(#{col_mod.to_json.gsub('"~', '').gsub('~"', '')}, '#{dat[:sortname]}', '#{dat[:sortorder]}', #{keep_scroll});"
  end

  def bus_value
    vid = params[:vista].to_i
    return '' unless vid

    val =  $h[vid][:mod].find(params[:id].to_i).auto_comp_value(:form)
    @ajax << "_autoCompField.val('#{val}');"
    @ajax << 'window.close();'
  end
end
