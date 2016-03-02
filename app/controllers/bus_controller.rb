class BusController < ApplicationController
  def bus
    @titulo = nt('bus')

    @mod = params[:mod]
    if @mod.nil?
      render nothing: true
      return
    end

    @vid = Vista.create.id
    $h[@vid] = {mod: @mod.constantize, cols: []}
  end

  def list
    # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)
    unless request.xhr?
      render json: ''
      return
    end

    vid = params[:vista].to_i
    unless vid
      render json: ''
      return
    end

    dat = $h[vid]

    if dat[:cols].empty?
      render json: ''
      return
    end

    clm = dat[:mod]
    tabla = clm.table_name

    w = ''
=begin
    if clm.column_names.include?('empresa_id')
      if params[:eid]
        add_where(w, mod_tab + '.empresa_id=' + params[:eid])
      else
        render json: {error: 'no_emp'}
        return
      end
    end

    if clm.column_names.include?('ejercicio_id')
      if params[:jid]
        add_where(w, mod_tab + '.ejercicio_id=' + params[:jid])
      else
        render json: {error: 'no_eje'}
        return
      end
    end
=end

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

        ty = f[:field].split('.')
        ty = ty[-2].model.columns_hash[ty[-1]].type
        add_where w, ([:bn,:ni,:en,:nc].include?(op) ? 'NOT ' : '') + (ty == :string ? 'UNACCENT(LOWER(' + f[:field] + '))' : f[:field])
        w << ({eq: '=', ne: '<>', cn: ' LIKE ', bw: ' LIKE ', ew: ' LIKE ', nc: ' LIKE ', bn: ' LIKE ', en: ' LIKE ', in: ' IN (', ni: ' IN (', lt: '<', le: '<=', gt: '>', ge: '>='}[op] || '=')
        if op == :in or op == :ni
          f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase + '\','}
          w.chop!
          w << ')'
        else
          w << '\''
          w << '%' if [:ew,:en,:cn,:nc].include?(op)
          w << (ty == :string ? I18n.transliterate(f[:data]).downcase : f[:data])
          w << '%' if [:bw,:bn,:cn,:nc].include?(op)
          w << '\''
        end
      }
    end

    sel = ''

    # Formar la cadena de ordenación y seguir incluyendo tablas en eager-load
    #
    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << c2[0]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    #tot_records = clm.select(:id).joins(eager.map{|j| j.to_sym}).where(w).size
    tot_records = clm.select(:id).where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    #sql = clm.eager_load(eager).where(w).where(params[:wh]).order(ord).offset((page-1)*lim).limit(lim)
    sql = clm.select('id,' + dat[:cols].map{|c| c[:col]}.join(',')).where(w).order(ord).offset((page-1)*lim).limit(lim)
    puts sql.inspect

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      dat[:cols].each {|c|
        begin
          h[:cell] << s[c[:col]].to_s
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
    render json: '' unless vid

    dat = $h[vid]
     col = params[:col]

    if params[:modo] == 'del'
      (dat[:cols].size - 1).downto(0).each {|i|
        if dat[:cols][i][:col] == col
          dat[:cols].delete_at(i)
          break
        end
      }
      dat[:cols].delete(col)
    else
      dat[:cols] << {col: col}
    end

    col_mod = dat[:cols].map{|c| {name: c[:col]}}.to_json
    @ajax << "$('#grid').jqGrid('GridUnload');generaGrid(#{col_mod});"
  end
end
