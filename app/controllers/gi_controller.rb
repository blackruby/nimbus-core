class GiMod
  @campos = {
    formato: {sel: {pdf: 'pdf', xlsx: 'excel', xls: 'excel_old'}, tab: 'post', hr: true},
    form_file: {},
  }
end

class GiMod
  include MantMod
end

class GiController < ApplicationController
  def nuevo_mod(mod, path)
    Dir.glob(path).each {|fic|
      ficb = Pathname(fic).basename.to_s

      next if File.directory?(fic)
      next if ficb == 'vista.rb'

      @tablas[mod] ||= []
      @tablas[mod] << ficb[0..-4].capitalize
    }
  end

  def gi
    @titulo = nt('gi')
    @tablas = {}

    nuevo_mod(Rails.app_class.to_s.split(':')[0], 'app/models/*')

    Dir.glob('modulos/*').each {|mod|
      nuevo_mod(mod.split('/')[1].capitalize, mod + '/app/models/*')
    }
  end

  def campos
    cl = params[:node].constantize
    data = []
    cl.column_names.each {|c|
      d = {}
      if c.ends_with?('_id')
        d[:label] = c[0..-4]
        d[:load_on_demand] = true
        d[:id] = cl.reflect_on_association(c[0..-4].to_sym).options[:class_name]
      else
        cs = c.to_sym
        d[:label] = c
        d[:table] = cl.table_name
        d[:type] = cl.columns_hash[c] ? cl.columns_hash[c].type : cl.propiedades[cs][:type]
        case d[:type]
          when :boolean
            d[:ali] = 'c'
            d[:estilo] = 'def_c'
          when :date
            d[:ali] = 'c'
            d[:estilo] = 'date'
          when :time, :datetime
            d[:ali] = 'c'
            d[:estilo] = 'time'
          when :integer
            d[:ali] = 'd'
            d[:estilo] = 'int'
          when :decimal
            d[:ali] = 'd'
            d[:estilo] = 'dec' + cl.propiedades[cs][:decim].to_s
          else
            d[:ali] = 'i'
        end
      end
      data << d
    }

    render json: data
  end

  def graba_fic
    file = 'formatos/' + params[:file]
    if params[:ow] == 'n' and File.exists?(file)
      render text: 'n'
      return
    end

    def graba_ban(f, v, nb=0)
      f.puts '['
      v.each {|r|
        f.puts ' '*nb + '  ['
        r.each {|c|
          cad = '    {'
          c.each {|k, v|
            cad << k + ': %q(' + v + '), '
          }
          f.puts ' '*nb + cad[0..(cad[-1] == ' ' ? -3 : -1)] + '},'
        }
        f.print ' '*nb + '  ],'
      }
      f.puts
      f.print ' '*nb + ']'
    end

    File.open(file, 'w') {|f|
      data = ActiveSupport::JSON.decode(params[:data])
      data.each {|k, v|
        next if v == ''
        f.print k + ': '
        if k == 'cab' or k == 'det' or k == 'pie'
          graba_ban(f, v)
        elsif k == 'rup'
          f.puts '['
          v.each {|v|
            f.puts '  {'
            v.each {|k, v|
              f.print '    ' + k + ': '
              if v.is_a? Array then
                graba_ban(f, v, 4)
              elsif k == 'campo'
                f.print '%q(' + v + ')'
              else
                f.print v
              end
              f.puts ','
            }
            f.print '  },'
          }
          f.puts
          f.print ']'
        elsif k == 'style' or k == 'lim'
          f.puts '{'
          opi = (k == 'style' ? '[' : '{')
          opd = (k == 'style' ? ']' : '}')
          v.each {|k, v|
            f.puts '  ' + k + ': ' + opi + v + opd + ','
          }
          f.print '}'
        else
          f.print v
        end
        f.puts ','
      }
    }
    render text: 's'
  end

  def ini_campos
    @fact.formato = :pdf
    @fact.form_file = params[:file]

    form = GI.formato_read(params[:file])

    form[:lim].each {|c, v| @fact.add_campo(c, v)}
    if form[:tit_c]
      @titulo = form[:tit_c]
    elsif form[:tabla]
      @titulo = 'Listado de ' + nt(form[:tabla].table_name)
    end
  end

  def after_save
    @ajax << 'window.open("/gi/abrir/' + @fact.form_file + '?vista=' + params[:vista] + '", "_blank", "location=no, menubar=no, status=no, toolbar=no ,height=800, width=1000 ,left=" + (window.screenX + 10) + ",top=" + (window.screenY + 10));'
  end

  def abrir
    @fact = $h[params[:vista].to_i][:fact]

    lim = {}
    @fact.campos.each {|c, v|
      lim[c] = @fact.method(c).call
    }

    lim[:eid], lim[:jid] = get_empeje

    g = GI.new(params[:file], nil, lim)
    g.gen_xls('/tmp/z.xlsx')

    case @fact.formato
      when 'pdf'
        `libreoffice --headless --convert-to pdf --outdir /tmp /tmp/z.xlsx`
        send_file '/tmp/z.pdf', type: :pdf, disposition: 'inline'
      when 'xls'
        `libreoffice --headless --convert-to xls --outdir /tmp /tmp/z.xlsx`
        send_file '/tmp/z.xls'
      when 'xlsx'
        send_file '/tmp/z.xlsx'
    end
  end
end

class GI
  def self.formato_read(file)
    path = nil
    fi = 'formatos/' + file
    path = fi if File.exists?(fi)
    if path.nil?
      Dir.glob('modulos/*/formatos').each {|mod|
        next if mod.ends_with?('/nimbus-core')
        fi = mod + '/' + file
        if File.exists?(fi)
          path = fi
          break
        end
      }
    end
    if path.nil?
      fi = 'modulos/nimbus-core/formatos/' + file
      path = fi if File.exists?(fi)
    end

    if path.nil?
      {}
    else
      eval('{' + File.read(path) + '}')
    end
  end

  def initialize(form, data=nil, lim={})
    if form.is_a? String
      #@form = eval('{' + File.read('formatos/' + form) + '}')
      @form = self.class.formato_read(form)
    else
      @form = form
    end

    @form[:tit_i] = (lim[:eid] ? Empresa.find_by(id: lim[:eid]).nombre : '') if @form[:tit_i].empty?
    #@form[:titulo] ||= ('Listado de ' + (@form[:tabla] ? nt(@form[:tabla].table_name) : ''))
    @form[:select] = @form[:tabla].table_name + '.*' if @form[:select].empty?

    if data
      @data = data
    else
      @data = @form[:tabla].select(@form[:select]).ljoin(@form[:join]).where(@form[:where], lim).order(@form[:orden])
    end

    def gen_alias(sym_ban, ban)
      ali = @alias[sym_ban] = {}
      ban.each_with_index {|r, nf |
        r.each_with_index {|h, nc|
          if h[:alias] and h[:alias] != ''
            ali[h[:alias].to_sym] = {col: ('A'.ord + nc).chr, row: nf}
          end
        }
      }
    end

    # Generar el hash de 'alias'
    @alias = {}
    gen_alias(:cab, @form[:cab]) if @form[:cab]
    gen_alias(:det, @form[:det]) if @form[:det]
    gen_alias(:pie, @form[:pie]) if @form[:pie]

    @form[:rup].each_with_index {|r, i|
      gen_alias("rc#{i}", r[:cab]) if r[:cab]
      gen_alias("rp#{i}", r[:pie]) if r[:pie]
    }
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

    ban.each_with_index {|r, i|
      @bi = i
      res = []
      r.each {|c|
        res << val_campo(c[:campo])
      }
      #@sh.add_row res, style: r.map {|c| c[:estilo] ? @sty[c[:estilo].to_sym] : nil}, widths: [:ignore, 10, :ignore], height: 0
      @sh.add_row res, style: r.map {|c| c[:estilo] ? @sty[c[:estilo].to_sym] : @sty[:def]}
      @ri += 1
    }
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
    @sh = wb.add_worksheet(:name => "Prueba")

    # Fijar las filas de cabecera para repetir en cada página
    wb.add_defined_name("Prueba!$1:$#{@form[:cab].size}", :local_sheet_id => @sh.index, :name => '_xlnm.Print_Titles')

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
      @d = dat
      @di = di

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
    #@sh.print_options.grid_lines = true
    @sh.page_setup.set(@form[:page_setup]) if @form[:page_setup]
    @sh.header_footer.odd_header = '&L' + @form[:tit_i] + '&C' + @form[:tit_c] + ' &R&P de &N'
#@sh.column_widths nil, 10, nil
    xls.serialize(name)
    return name
  end
end
