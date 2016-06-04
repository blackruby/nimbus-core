class GiMod
  @campos = {
    formato: {sel: {pdf: 'pdf', xlsx: 'excel', xls: 'excel_old'}, tab: 'post', hr: true},
    form_modulo: {},
    form_file: {},
  }
end

class GiMod
  include MantMod
end

class GiController < ApplicationController
  def nuevo_mod(mod, path)
    Dir.glob(path).sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      next if File.directory?(fic)
      next if ficb == 'vista.rb'

      @tablas[mod] ||= []
      @tablas[mod] << ficb[0..-4].capitalize
    }
  end

  def nuevo_form(mod, path, ext=true)
    @forms[mod] = [] unless ext
    Dir.glob(path + '/*.yml').sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      @forms[mod] ||= []
      if ext
        modelo = desc = ''
        open(fic, 'r').each_with_index {|l, i|
          break if i > 3
          #modelo = l[9..-1] if l.starts_with?(':modelo:')
          #desc = l[14..-1] if l.starts_with?(':descripcion:')
          modelo = YAML.load(l)[:modelo] if l.starts_with?(':modelo:')
          desc = YAML.load(l)[:descripcion] if l.starts_with?(':descripcion:')
        }
        @forms[mod] << [ficb[0..-5], modelo, desc]
      else
        @forms[mod] << ficb[0..-5]
      end
    }
  end

  def all_files(ext)
    @forms = {}

    nuevo_form('privado', "formatos/_usuarios/#{@usu.codigo}", ext)
    nuevo_form('publico', 'formatos/_publico', ext)
    nuevo_form(Rails.app_class.to_s.split(':')[0].downcase, 'formatos', ext)

    Dir.glob('modulos/*').sort.each {|mod|
      nuevo_form(mod.split('/')[1], mod + '/formatos', ext) unless mod.ends_with?('/idiomas') or mod.ends_with?('/nimbus-core')
    }
  end

  def gi
    @titulo = nt('gi')
    all_files(true)
    @modo = 'edit'
  end

  def giv
    @titulo = nt('giv')
    all_files(true)
    @modo = 'run'
    render 'gi'
  end

  def new
    if params[:modelo]
      @modelo = params[:modelo]
      begin
        @modelo.constantize # Solo para provocar una excepción si no existe el modelo
      rescue
        begin
          @modelo[1..-1].constantize  # Por si es un histórico
          @modelo.constantize # Solo para provocar una excepción si no existe el modelo
        rescue
          render file: '/public/404.html', status: 404, layout: false
          return
        end
      end
      @modulo = 'privado'
      @formato = ''
      @form = {}
      all_files(false)
      render 'edita'
    else
      @titulo = nt('gi')
      @tablas = {}

      nuevo_mod(Rails.app_class.to_s.split(':')[0].downcase, 'app/models/*')

      Dir.glob('modulos/*').each {|mod|
        nuevo_mod(mod.split('/')[1].capitalize, mod + '/app/models/*')
      }
    end
  end

  def edita
    @modulo = params[:modulo]
    @formato = params[:formato]
    @form = GI.formato_read(@modulo, @formato, @usu.codigo)
    if @form
      @modelo = @form[:modelo]
      all_files(false)
    else
      render file: '/public/404.html', status: 404, layout: false
    end
  end

  def campos
    begin
      clr = params[:node].constantize
      clr.column_names.include?('idid') ? cl = params[:node][1..-1].constantize : cl = clr
    rescue
      # Se supone que sería un histórico y está sin cargar su clase
      cl = params[:node][1..-1].constantize
      clr = params[:node].constantize
    end

    data = []
    clr.column_names.each {|c|
      d = {}
      if c.ends_with?('_id')
        d[:label] = c[0..-4]
        d[:load_on_demand] = true
        if cl != clr and c == 'created_by_id'
          d[:id] = 'Usuario'
        else
          d[:id] = cl.reflect_on_association(c[0..-4].to_sym).options[:class_name]
        end
      else
        cs = c.to_sym
        d[:label] = c
        d[:table] = cl.table_name
        d[:pk] = (c == cl.pk[-1])
        #d[:type] = cl.columns_hash[c] ? cl.columns_hash[c].type : cl.propiedades[cs][:type]
        d[:type] = clr.columns_hash[c].type
        if cl == clr
          d[:manti] = cl.propiedades[cs][:manti] if cl.propiedades[cs] and cl.propiedades[cs][:manti]
          decim = (cl.propiedades[cs] and cl.propiedades[cs][:decim]) ? cl.propiedades[cs][:decim] : 2
        end

        case d[:type]
          when :boolean
            d[:ali] = 'c'
            d[:estilo] = 'def_c'
          when :date
            d[:ali] = 'c'
            d[:estilo] = 'date'
          when :time
            d[:ali] = 'c'
            d[:estilo] = 'time'
          when :datetime
            d[:ali] = 'c'
            d[:estilo] = 'datetime'
          when :integer
            d[:ali] = 'd'
            d[:estilo] = 'int'
          when :decimal
            d[:ali] = 'd'
            d[:decim] = decim
            d[:estilo] = 'dec' + decim.to_s
          else
            d[:ali] = 'i'
        end
      end
      data << d
    }

    render json: data
  end

  def graba_fic
=begin
    file = 'formatos/' + params[:file] + '.yml'
    if params[:ow] == 'n' and File.exists?(file)
      render text: 'n'
      return
    end

    data = eval(params[:data])
    File.write(file, data.to_yaml)
    render text: 's'
=end
    begin
      case params[:modulo]
        when ''
          render text: 'n'
          return
        when 'privado'
          path = "formatos/_usuarios/#{@usu.codigo}/"
        when 'publico'
          path = "formatos/_publico/"
        when Rails.app_class.to_s.split(':')[0].downcase
          path = "formatos/"
        else
          path = "modulos/#{params[:modulo]}/formatos/"
      end

      FileUtils.mkdir_p(path)
      File.write(path + params[:formato] + '.yml', eval(params[:data]).to_yaml)
      render text: 's'
    rescue Exception => e
      logger.fatal '######## ERROR #############'
      logger.fatal e.message
      logger.fatal e.backtrace[0..10]
      logger.fatal '############################'
      render text: 'n'
    end
  end

  def before_edit
    @form = GI.formato_read(params[:modulo], params[:formato], @usu.codigo)
    @form ? nil : {file: '/public/404.html', status: 404}
  end

  def ini_campos
    @fact.formato = 'pdf'
    @fact.form_modulo = params[:modulo]
    @fact.form_file = params[:formato]

    @form[:lim].each {|c, v|
      @fact.add_campo(c, eval('{' + v + '}'))
    }

    if @form[:modelo]
      begin
        cl = @form[:modelo].constantize
      rescue
        @form[:modelo][1..-1].constantize
        cl = @form[:modelo].constantize
      end
      tit = 'Listado de ' + nt(cl.table_name)
    else
      tit = 'Listado'
    end

    if @form[:descripcion]
      @titulo = @form[:descripcion].strip.empty? ? tit : @form[:descripcion]
    else
      @titulo = tit
    end
  end

  def after_save
    #@ajax << 'window.open("/gi/abrir/' + @fact.form_file + '?vista=' + params[:vista] + '", "_blank", "location=no, menubar=no, status=no, toolbar=no ,height=800, width=1000 ,left=" + (window.screenX + 10) + ",top=" + (window.screenY + 10));'
    @ajax << (@fact.formato == 'pdf' ? 'window.open("/gi/abrir");' : 'window.location.href="/gi/abrir";')
    flash[:vista] = @v.id
  end

  def abrir
    vid = flash[:vista]
    @v = Vista.find_by id: vid
    if @v
      @fact = @v.data[:fact]
    else
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    lim = {}
    @fact.campos.each {|c, v|
      lim[c] = v[:cmph] ? @fact[c.to_s[0..-4]].try(v[:cmph]) : @fact[c]
    }

    lim[:eid], lim[:jid] = get_empeje

    g = GI.new(@fact.form_modulo, @fact.form_file, @usu.codigo, lim)

    @titulo = 'HOLA'

    fns = "/tmp/nim#{vid}" #file_name_server

    g.gen_xls("#{fns}.xlsx")

    fnc = g.formato[:modelo] ? g.formato[:modelo].table_name : 'listado' #file_name_client

    case @fact.formato
      when 'pdf'
        `libreoffice --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
        send_data File.read("#{fns}.pdf"), filename: "#{fnc}.pdf", type: :pdf, disposition: 'inline'
        FileUtils.rm "#{fns}.pdf", force: true
      when 'xls'
        `libreoffice --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
        send_data File.read("#{fns}.xls"), filename: "#{fnc}.xls"
        FileUtils.rm "#{fns}.pdf", force: true
      when 'xlsx'
        send_data File.read("#{fns}.xlsx"), filename: "#{fnc}.xlsx"
      else
        render nothing: true
    end

    FileUtils.rm "#{fns}.xlsx", force: true
  end
end

class GI
  def self.formato_read(modulo, file, user)
=begin
    path = nil
    fi = 'formatos/' + file + '.yml'
    path = fi if File.exists?(fi)
    if path.nil?
      Dir.glob('modulos/*/formatos').each {|mod|
        next if mod.ends_with?('/nimbus-core')
        fi = mod + '/' + file + '.yml'
        if File.exists?(fi)
          path = fi
          break
        end
      }
    end
    if path.nil?
      fi = 'modulos/nimbus-core/formatos/' + file + '.yml'
      path = fi if File.exists?(fi)
    end

    if path.nil?
      {}
    else
      #eval('{' + File.read(path) + '}')
      formato = YAML.load(File.read(path))
      formato
    end
=end
    case modulo
      when '', '_', Rails.app_class.to_s.split(':')[0].downcase
        path = "formatos/#{file}"
      when 'publico'
        path = "formatos/_publico/#{file}"
      when 'privado'
        path = "formatos/_usuarios/#{user}/#{file}"
      else
        path = "modulos/#{modulo}/formatos/#{file}"
    end

    begin
      YAML.load(File.read(path + '.yml'))
    rescue
      nil
    end
  end

  def alias_cmp_db(cad, h_alias)
    new_cad = ''
    cad.split('~').each_with_index {|c, i|
      c = h_alias[c][:cmp_db] if i.odd?
      new_cad << c
    }
    new_cad
  end

  def procesa_macros(cad, vpl=true)
    return(nil) unless cad

    new_cad = ''
    cad.split('~').each_with_index {|c, i|
      if i.odd?
        if c[0] == 'S'  # Es un campo de select
          #c = "@d[#{@ali_sel.index(c.to_sym)}]"
          c = "f[#{@ali_sel.index(c.to_sym)}]"
        else
          @msel << c unless @msel.include?(c)
          if vpl
            ip = @vpluck.index(c)
            unless ip
              ip = @vpluck.size
              @vpluck << c
            end
            c = "f[#{ip}]"
          end
        end
      end
      new_cad << c
    }
    new_cad
  end

  def gen_alias(sym_ban, ban)
    ali = @alias[sym_ban] = {}
    ban.each_with_index {|r, nf |
      r.each_with_index {|h, nc|
        if h[:alias] and h[:alias] != ''
          ali[h[:alias].to_sym] = {col: ('A'.ord + nc).chr, row: nf}
        end

        # Procesar campos para sustituirlos por su posición en el vector vpluck y generar éste.
        h[:campo] = procesa_macros(h[:campo])
      }
    }
  end

  def initialize(modulo, form, user, lim={}, data=nil)
    if form.is_a? String
      @form = self.class.formato_read(modulo, form, user)
    else
      @form = form
    end

    @e = Empresa.find_by(id: lim[:eid]) if lim[:eid]

    @form[:modelo] = @form[:modelo].constantize if @form[:modelo]
    @form[:style].each {|k, v| @form[:style][k] = eval('[' + v + ']')}

    #@form[:tit_i] = '&B' + (lim[:eid] ? Empresa.find_by(id: lim[:eid]).nombre : '') + '&B' if @form[:tit_i].empty?
    @form[:tit_i] = '&B' + @e.try(:nombre) + '&B' if @form[:tit_i].empty?
    @form[:tit_d] = '&P de &N' if @form[:tit_d].empty?
    @form[:tit_c] = '&BListado de ' + nt(@form[:modelo].table_name) + '&B' if @form[:tit_c].empty? and @form[:modelo]

    @vpluck = []
    @msel = []
    @ali_sel = []
    @alias = {}
    @lim = lim
    @fx = {}

    # Procesar fómulas
    @form[:formulas].each {|k, v| @form[:formulas][k] = procesa_macros(v)}

    # Procesar select (1ª vuelta)
    @form[:select].each {|k, v|
      @ali_sel << k
      @vpluck << v
      procesa_macros(v, false)
    }
    # Generar el hash de 'alias' y pluck
    gen_alias(:cab, @form[:cab]) if @form[:cab]
    gen_alias(:det, @form[:det]) if @form[:det]
    gen_alias(:pie, @form[:pie]) if @form[:pie]

    @form[:rup].each_with_index {|r, i|
      r[:campo] = procesa_macros(r[:campo])
      gen_alias("rc#{i}", r[:cab]) if r[:cab]
      gen_alias("rp#{i}", r[:pie]) if r[:pie]
    }

    # Añadir where de empresa y ejercicio si procede
    if @form[:filt_emej]
      if @form[:modelo].respond_to?('ejercicio_path')
        jp = @form[:modelo].ejercicio_path
        jpi = jp + (jp.empty? ? '' : '.') + 'ejercicio_id'
        @form[:where]['_weje'] = '~' + jpi + '~' + ' = :jid'
      elsif @form[:modelo].respond_to?('empresa_path')
        ep = @form[:modelo].empresa_path
        epi = ep + (ep.empty? ? '' : '.') + 'empresa_id'
        @form[:where]['_wemp'] = '~' + epi + '~' + ' = :eid'
      end
    end

    # procesar where (1ª vuelta)
    @form[:where].each {|_, v|
      procesa_macros(v, false)
    }

    # procesar order (1ª vuelta)
    procesa_macros(@form[:order], false)

    # procesar group (1ª vuelta)
    procesa_macros(@form[:group], false)

    # procesar having (1ª vuelta)
    @form[:having].each {|_, v|
      procesa_macros(v, false)
    }

    if data
      @data = data
    else
      #@data = @form[:modelo].select(@form[:select]).ljoin(@form[:join]).where(@form[:where], lim).order(@form[:order])
      ms = mselect_parse @form[:modelo], @msel

      # procesar vpluck (2ª vuelta)
      nsel = @form[:select].size
      @vpluck.size.times {|i|
        if i < nsel # Los primeros son los selects
          @vpluck[i] = alias_cmp_db(@vpluck[i], ms[:alias_cmp])
        else
          @vpluck[i] = ms[:alias_cmp][@vpluck[i]][:cmp_db]
        end
      }

      # procesar where (2ª vuelta)
      wh = ''
      @form[:where].each {|_, v|
        wh << ' AND ' unless wh.empty?
        wh << alias_cmp_db(v, ms[:alias_cmp])
      }

      # procesar order (2ª vuelta)
      @form[:order] = alias_cmp_db(@form[:order], ms[:alias_cmp])

      # procesar group (2ª vuelta)
      @form[:group] = alias_cmp_db(@form[:group], ms[:alias_cmp])

      # procesar having (2ª vuelta)
      ha = ''
      @form[:having].each {|_, v|
        ha << ' AND ' unless ha.empty?
        ha << alias_cmp_db(v, ms[:alias_cmp])
      }

      # Obtener la query
      @data = @form[:modelo].joins(ms[:cad_join]).where(wh, lim).group(@form[:group]).having(ha, lim).order(@form[:order]).pluck(*@vpluck)
    end
  end

  def formato
    @form
  end

  def cel(ali)
    @alias[@ban][ali][:col] + (@ri - @bi + @alias[@ban][ali][:row]).to_s
  end

  def tot(ali, niv=@rupi)
    col = @alias[:det][ali][:col]
    "=SUBTOTAL(9,#{col}#{@rup[niv]}:#{col}#{@ri - 1})"
  end

  def val_campo(c, f=@d)
    if c.is_a? Symbol
      return f.method(c).call
    elsif c.is_a? Fixnum
      # Para el caso de que los datos sea un array y 'c' represente el índice
    elsif c.is_a? String
      return eval(c)
    else
      return c
    end
  end

  def add_banda(ban)
    return unless ban

    merg = []
    ban.each_with_index {|r, i|
      @bi = i
      res = []
      r.each_with_index {|c, i|
        res << val_campo(c[:campo])
        if c[:colspan].to_i > 0 or c[:rowspan].to_i > 0
          merg << "#{('A'.ord + i).chr}#{@ri}:#{('A'.ord + i + c[:colspan].to_i).chr}#{@ri + c[:rowspan].to_i}"
        end
      }
      #@sh.add_row res, style: r.map {|c| c[:estilo] ? @sty[c[:estilo].to_sym] : nil}, widths: [:ignore, 10, :ignore], height: 0
      @sh.add_row res, style: r.map {|c| c[:estilo] ? @sty[c[:estilo].to_sym] : @sty[:def]}, types: r.map {|c| c[:tipo] ? (c[:tipo].empty? ? nil : c[:tipo].to_sym) : nil}
      @ri += 1
    }
    merg.each {|m| @sh.merge_cells(m)}
  end

  def new_style(s, st)
    if s.is_a? Array
      s.each {|a|
        (a.is_a? Symbol) ? new_style(@form[:style][a], st) : st.merge!(a)
      }
    else
      st.merge!(s)
    end
  end

  def gen_xls(name=nil)
    name ||= Dir::Tmpname.make_tmpname('/tmp/', '.xlsx')

    # Procesar la banda de detalle para extraer campos a totalizar
=begin
    @ctot = {}
    @form[:det][:row][0].each_with_index {|c, i|
      if c.is_a? Array
        @ctot[c[0]] = {col: ('A'.ord + i).chr}
      end
    }
=end

    xls = Axlsx::Package.new
    wb = xls.workbook
    marg = eval('{' + @form[:page_margins] + '}') if @form[:page_margins]
    @sh = wb.add_worksheet(:name => "Uno", page_margins: marg)

    # Fijar las filas de cabecera para repetir en cada página
    wb.add_defined_name("Uno!$1:$#{@form[:cab].size}", :local_sheet_id => @sh.index, :name => '_xlnm.Print_Titles')

    # Añadir estilos
    if @form[:style]
      @sty = {}
      @form[:style].each {|c, v|
        st = {}
        new_style(v, st)
        @sty[c] = wb.styles.add_style(st)
      }
    end

    # Inicializar vector de rupturas (para llevar la fila de inicio de cada una)
    @rup = [@form[:cab].size + 1]

    ds = @data.size - 1
    nr = @form[:rup] ? @form[:rup].size : nil

    @di = 0
    @ri = 1

    # Añadir banda de cabecera
    @d = @data[0]
    @ban = :cab
    @rupi = 0
    add_banda(@form[:cab])

    @data.each_with_index {|dat, di|
      dat = [dat] unless dat.is_a?(Array)
      @d = dat
      @di = di

      # Procesar fórmulas
      f = dat
      @form[:formulas].each {|k, v|
        @fx[k] = eval(v)
      }

      # Añadir bandas de cabecera de ruptura
      if nr
        if di == 0
          add = true
        else
          add = false
          dat_a = @data[di-1]
        end

        @form[:rup].each_with_index {|r, i|
          @ban = "rc#{i}"
          @rupi = i + 1
          if add
            add_banda(r[:cab])
            @rup[i+1] = @ri
          else
            if val_campo(r[:campo], dat) != val_campo(r[:campo], dat_a)
              add_banda(r[:cab])
              @rup[i+1] = @ri
              add = true
            end
          end
        }
      end

      # Añadir banda de detalle
      @ban = :det
      @rupi = 0
      add_banda(@form[:det])

      # Añadir bandas de pie de ruptura
      if nr
        if di == ds
          ir = 0
        else
          ir = nr
          dat_s = @data[di+1]
          @form[:rup].each_with_index {|r, i|
            if val_campo(r[:campo], dat) != val_campo(r[:campo], dat_s)
              ir = i
              break
            end
          }
        end

        (nr - 1).downto(ir).each {|i|
          @ban = "rp#{i}"
          @rupi = i + 1
          add_banda(@form[:rup][i][:pie])
          @sh.add_page_break("A#{@ri - 1}") if @form[:rup][i][:salto]
        }
      end
    }

    # Añadir banda de pie
    @ban = :pie
    @rupi = 0
    add_banda(@form[:pie])

    # Opciones varias
    #@sh.page_setup.fit_to :width => 1
    #@sh.page_setup.set orientation: :landscape, paper_width: "210mm", paper_height: "297mm"
    @sh.print_options.grid_lines = true if @form[:pingrid]
    @sh.page_setup.set(eval('{' + @form[:page_setup] + '}')) if @form[:page_setup]
    @sh.header_footer.odd_header = "&L#{@form[:tit_i]}&C#{@form[:tit_c]}&R#{@form[:tit_d]}"
    @sh.header_footer.odd_footer = "&L#{@form[:pie_i]}&C#{@form[:pie_c]}&R#{@form[:pie_d]}"
    @sh.column_widths(*(@form[:col_widths].split(',').map{|w| w.to_i})) if @form[:col_widths]
    xls.serialize(name)
    return name
  end
end