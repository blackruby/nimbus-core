class GiController < ApplicationController
  # Método para contantizar un modelo y, si es un histórico, constantizar antes el modelo original para que se carguen las clases correctamente
  def h_constantize(mod)
    begin
      mod.constantize
    rescue
      im = mod.index('::')
      if im
        (mod[0..im+1] + mod[im+3..-1]).constantize
      else
        mod[1..-1].constantize
      end
      mod.constantize
    end
  end

  def nuevo_mod(mod, path)
    models = Dir.glob(path + '/**/*.rb').
      select {|f| !(f.ends_with?('_add.rb') || f == 'modulos/nimbus-core/app/models/vista.rb' || f == "modulos/#{mod}/app/models/#{mod}.rb")}.
      map {|f|
        a = f.split('/')
        (a.size == 6 ? a[4].capitalize + '::' : '') + Pathname(f).basename.to_s[0..-4].capitalize
       }.sort

    @tablas[mod] = models if models.present?
  end

  def nuevo_form(mod, path, ext=true)
    @forms[mod] = [] unless ext
    Dir.glob(path + '/*.yml').sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      @forms[mod] ||= []
      if ext
        modelo = desc = com = ''
        open(fic, 'r').each_with_index {|l, i|
          break if i > 3
          modelo = YAML.load(l)[:modelo] if l.starts_with?(':modelo:')
          desc = YAML.load(l)[:descripcion] if l.starts_with?(':descripcion:')
          com = YAML.load(l)[:comentario] if l.starts_with?(':comentario:')
        }
        @forms[mod] << [ficb[0..-5], modelo, desc, com]
      else
        @forms[mod] << ficb[0..-5]
      end
    }
  end

  def all_files(ext)
    @forms = {}

    nuevo_form('privado', "formatos/_usuarios/#{@usu.codigo}", ext)
    nuevo_form('publico', 'formatos/_publico', ext)

    if (@usu.codigo == 'admin')
      nuevo_form(Rails.app_class.to_s.split(':')[0].downcase, 'formatos', ext)

      Dir.glob(Nimbus::ModulosGlob).sort.each {|mod|
        nuevo_form(mod.split('/')[1], mod + '/formatos', ext)
      }
    end
  end

  def gi
    @assets_stylesheets = %w(gi)
    @assets_javascripts = %w(gi)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @titulo = nt('gi')
    all_files(true)
    @modo = 'edit'
  end

  def giv
    @assets_stylesheets = %w(gi)
    @assets_javascripts = %w(gi)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['giv']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @titulo = nt('giv')
    all_files(true)
    @modo = 'run'
    render 'gi'
  end

  def new
    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    if params[:modelo]
      @assets_stylesheets = %w(gi_edita)
      @assets_javascripts = %w(gi_edita)

      @modelo = params[:modelo]
=begin
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
=end

      # Comprobar si existe el modelo constantizándolo
      begin
        h_constantize(@modelo)
      rescue
        render file: '/public/404.html', status: 404, layout: false
        return
      end

      @modulo = 'privado'
      @formato = ''
      @form = {}
      all_files(false)
      render 'edita'
    else
      @assets_stylesheets = %w(gi_new)

      @titulo = nt('gi')
      @tablas = {}

      nuevo_mod(Rails.app_class.to_s.split(':')[0].downcase, 'app/models')

      Dir.glob(Nimbus::ModulosGlob).sort.each {|mod|
        nuevo_mod(mod.split('/')[1], mod + '/app/models')
      }
    end
  end

  def edita
    @assets_stylesheets = %w(gi_edita)
    @assets_javascripts = %w(gi_edita)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

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
    cl = h_constantize(params[:node])

    emp = params[:emp].to_i

    data = []

    cols = Nimbus::Config.dig(:gi, :ord_cmp) ? cl.column_names : (['id'] + cl.pk + cl.column_names.sort).uniq
    cols.each {|c|
      cs = c.to_sym
      next if cl.propiedades.dig(cs, :bus_hide)
      d = {table: cl.table_name, type: cl.columns_hash[c].type}
      if c.ends_with?('_id')
        assoc = cl.reflect_on_association(c[0..-4].to_sym)
        if assoc
          #d[:id] = cl.reflect_on_association(c[0..-4].to_sym).options[:class_name]
          d[:id] = assoc.class_name
          # Controlar permisos. Si no se tiene permiso para el controlador asociado al modelo
          # correspondiente al campo "id" ==> Excluir dicho id para no poder acceder a esa tabla.
          unless @usu.admin
            ctrl = assoc.class_name.constantize.ctrl_for_perms
            next unless @usu.pref[:permisos][:ctr][ctrl] && @usu.pref[:permisos][:ctr][ctrl][emp]
          end
          d[:label] = c[0..-4]
          d[:load_on_demand] = true
        else
          logger.fatal "######## ERROR. Modelo: #{cl}, campo: #{c} No tiene belongs_to asociado."
          next
        end
      else
        d[:label] = c
        d[:pk] = cl.respond_to?(:pk) ? (c == cl.pk[-1]) : false
        d[:manti] = cl.propiedades[cs][:manti] if cl.propiedades[cs] and cl.propiedades[cs][:manti]
        decim = (cl.propiedades[cs] and cl.propiedades[cs][:decim]) ? cl.propiedades[cs][:decim] : 2

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
            if decim.is_a?(String)
              d[:decim] = decim[decim.index('#{').to_i+2...decim.rindex('}').to_i]
              d[:estilo] = 'dyn'
            else
              d[:decim] = decim
              d[:estilo] = 'dec' + decim.to_s
            end
          else
            d[:ali] = 'i'
        end
      end
      tit = cl.propiedades.dig(cs, :title)
      d[:title] = tit if tit
      data << d
    }

    render json: data
  end

  def graba_fic
    begin
      case params[:modulo]
        when ''
          #render text: 'n'
          render plain: 'n'
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
      #render text: 's'
      render plain: 's'
    rescue Exception => e
      pinta_exception(e)
      #render text: 'n'
      render plain: 'n'
    end
  end

  def borra_formato
    form = params[:form]
    return unless form
    form = form.split('/')
    return if form.size != 2
    return if !(@usu.codigo == 'admin' || @usu.pref[:permisos] && @usu.pref[:permisos][:ctr] && @usu.pref[:permisos][:ctr]['gi'] && (form[0] == 'publico' || form[0] == 'privado'))

    if form[0] == 'publico'
      pref = 'formatos/_publico'
    elsif form[0] == 'privado'
      pref = "formatos/_usuarios/#{@usu.codigo}"
    elsif form[0] == Rails.app_class.to_s.split(':')[0].downcase
      pref = 'formatos'
    else
      pref = "modulos/#{form[0]}/formatos"
    end

    FileUtils.rm_rf "#{pref}/#{form[1]}.yml"
  end

  def before_edit
    if params[:controller] == 'gi'
      @gi_modulo = params['modulo']
      @gi_formato = params['formato']

      if @gi_modulo != 'publico' and @gi_modulo != 'privado'
        pref_html = '/'
        if @gi_modulo == Rails.app_class.to_s.split(':')[0].downcase
          pref = 'app/controllers'
        else
          pref = "modulos/#{@gi_modulo}/app"
          if File.exist?("#{pref}/models/#{@gi_modulo}.rb")
            pref << "/controllers/#{@gi_modulo}"
            pref_html = "/#{@gi_modulo}/"
          else
            pref << "/controllers"
          end
        end
        #return({redirect: "#{pref_html}#{@gi_formato}"}) if File.exist?("#{pref}/#{@gi_formato}_controller.rb")
        if File.exist?("#{pref}/#{@gi_formato}_controller.rb")
          redirect_to "#{pref_html}#{@gi_formato}"
          return
        end
      end

      #return('/public/401.html') unless @usu.admin or params[:modulo] == 'publico' or params[:modulo] == 'privado' or @usu.pref[:permisos][:ctr]['gi/run/' + params[:modulo] + '/' + params[:formato]]
      prm = @usu.pref[:permisos][:ctr]['gi/run/' + params[:modulo] + '/' + params[:formato]]
      return(false) unless @usu.admin or params[:modulo] == 'publico' || params[:modulo] == 'privado' || prm && prm[get_empeje[0].to_i]
    else
      ctr = params[:controller].split('/')
      if ctr.size == 1
        @gi_modulo = Rails.app_class.to_s.split(':')[0].downcase
        @gi_formato = ctr[0]
      else
        @gi_modulo = ctr[0]
        @gi_formato = ctr[1]
      end
    end

    @formato = GI.new(@gi_modulo, @gi_formato, @usu.codigo, nil)
    @form = @formato.formato

    if @form
      @titulo = @form[:descripcion] if @form[:descripcion] && !@form[:descripcion].strip.empty?
      if @form[:modelo]
        cl = h_constantize(@form[:modelo])
        if cl.respond_to?('ejercicio_path')
          @nivel = :j
        elsif cl.respond_to?('empresa_path')
          @nivel = :e
        end
        @titulo ||= 'Listado de ' + nt(cl.table_name)
      else
        @titulo ||= 'Listado'
      end
      @nivel ||= :g
      return true
    else
      render file: '/public/404.html', status: 404, layout: false
      return
    end
    #@form ? nil : {file: '/public/404.html', status: 404}
  end

  def before_envia_ficha
    @g[:go] = params[:go]
    @g[:info] = @titulo

    @fact.form_type = 'pdf'
    @fact.form_modulo = @gi_modulo
    @fact.form_file = @gi_formato

    @form[:lim].each {|c, v|
      @fact.add_campo(c, eval('{' + v + '}'))
    }
    @fact.campos.each {|c, v|
      @fact[c] = params[c] if params[c]
    }
    if @formato.respond_to?(:ini_campos)
      if @formato.method(:ini_campos).arity == 1
        @formato.ini_campos(@fact)
      elsif @formato.method(:ini_campos).arity == 2
        @formato.ini_campos(@fact, params)
      else
        @formato.ini_campos(@fact, params, @form)
      end
    end

=begin
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

    tit = @form[:descripcion] if @form[:descripcion] && !@form[:descripcion].strip.empty?
    set_titulo(tit, @e&.codigo, @j&.codigo)
=end

    if @formato.respond_to?(:before_envia_ficha)
      eval(@formato.before_envia_ficha)
    end
  end

  def mi_render
    if params[:go]
      @ajax_load << 'callFonServer("grabar");'
      render html: '', layout: 'basico_ajax'
    end
  end

  def gi_envia_datos
    #envia_fichero(file: "#{@g[:fns]}.#{@fact.form_type}", file_cli: "#{@fact.form_file}.#{@fact.form_type}", rm: true, disposition: @fact.form_type == 'pdf' ? 'inline' : 'attachment', popup: @g[:go] ? :self : false)
    envia_fichero(
      file: "#{@g[:fns]}.#{@fact.form_type}",
      file_cli: "#{@fact.form_file}.#{@fact.form_type}",
      rm: true,
      disposition: @fact.form_type == 'pdf' ? 'inline' : 'attachment',
      popup: @g[:go] ? :self : false,
      tit: "#{@g[:info]} (#{@fact.form_type})"
    )
  end

  def after_save
    label = 'Obteniendo información'
    exe_p2p(label: label, width: 400, cancel: true, info: @g[:info], tag: (@fact.form_type == 'xlsx' ? :xls : :loff), fin: :gi_envia_datos) {
      begin
        lim = {}
        @fact.campos.each {|c, v|
          cs = c.to_s
          if v[:cmph]
            lim[c] = @fact[cs[0..-4]].try(v[:cmph])
          elsif v[:rango]
            lim[c] = @fact[c].expande_rango
            lim[("#{cs}_rango").to_sym] = @fact[c]
          else
            lim[c] = @fact[c]
          end

          if cs.ends_with?('_id')
            lim[("#{cs}_value").to_sym] = @fact[c] ? forma_campo_id(v[:ref], @fact[c], :gi) : ''
          end
        }

        lim[:eid], lim[:jid] = get_empeje

        g = GI.new(@fact.form_modulo, @fact.form_file, @usu.codigo, lim)

        fns = "/tmp/nim#{@v.id}" #file_name_server
        #fnc = @fact.form_file
        @g[:fns] = fns

        p2p label: label << '<br>Formateando datos'
        g.gen_xls("#{fns}.xlsx", @fact.form_type == 'pdf')

        case @fact.form_type
          when 'pdf'
            p2p label: label << '<br>Generando PDF'
            # LibreOffice, de momento, no es capaz de rodar instancias en paralelo. Parece que esto se va a
            # solucionar en la versión 5.3.0
            # Mientras tanto y como "workaround" se puede solventar forzando en cada instancia un directorio
            # distinto de configuración con la opción: -env:UserInstallation=file:///directorio_de_conf
            # Cuando el tema esté resuelto habría que quitar esta opción de la llamada a libreoffice.

            #`libreoffice --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
            #`libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
            h = spawn "libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to pdf --outdir /tmp #{fns}.xlsx"
            Process.wait h
            FileUtils.rm_rf %W(#{fns}.xlsx #{fns}_lo_dir)
          when 'xls'
            p2p label: label << '<br>Generando XLS'
            # La misma historia que en el caso anterior

            #`libreoffice --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
            #`libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
            h = spawn "libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to xls --outdir /tmp #{fns}.xlsx"
            Process.wait h
            FileUtils.rm_rf %W(#{fns}.xlsx #{fns}_lo_dir)
        end
      rescue Exception => e
        FileUtils.rm_rf %W(#{fns}.xlsx #{fns}.xls #{fns}.pdf #{fns}_lo_dir)
        raise e
      end
    }
  end
end
