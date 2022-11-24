class ApplicationController < ActionController::Base
  SESSION_EXPIRATION_TIME = 30.minutes

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, unless: -> {
    params[:action] == 'destroy_vista' || request.fullpath.starts_with?('/api/')
  }

  include ActionView::Helpers::NumberHelper

  before_action :ini_controller
  skip_before_action :ini_controller, only: [:destroy_vista]

  def self.nimbus_hook(h)
    @nimbus_hooks ||= {}
    h.each {|k, v|
      k = k.to_sym
      v = v.to_sym
      @nimbus_hooks[k] ? @nimbus_hooks[k] << v : @nimbus_hooks[k] = [v]
    }
  end

  def self.nimbus_hooks
    @nimbus_hooks
  end

  def self.set_nimbus_views(tipo, paths)
    @nimbus_views ||= {}
    @nimbus_views[tipo] = paths
  end

  def self.nimbus_views
    @nimbus_views
  end

  def call_nimbus_hook(fun, *ar)
    fun = fun.to_sym
    method(fun).call(*ar) if self.respond_to?(fun)
    if self.class.nimbus_hooks and self.class.nimbus_hooks[fun]
      self.class.nimbus_hooks[fun].each {|f| method(f).call(*ar)}
    end
  end

  def sesion_invalida
    ahora = Time.now
    @usu = Usuario.find_by id: session[:uid]

    return(true) unless @usu

    fex = @usu.timeout.nil? ? SESSION_EXPIRATION_TIME : @usu.timeout.minutes

    @usu.password_fec_mod.nil? or
    session[:fec] < @usu.password_fec_mod or
    (@usu.num_dias_validez_pass.to_i != 0 and (ahora - @usu.password_fec_mod)/86400 > @usu.num_dias_validez_pass) or
    (@usu.fecha_baja and @usu.fecha_baja <= Date.today) or
    (fex != 0 and session[:fem].to_time + fex < ahora)
  end

  def ini_controller
    if request.fullpath.starts_with?('/api/')
      if params[:jwt]
        begin
          jwt = JWT.decode(params[:jwt], Rails.application.secrets.secret_key_base)[0]
          @usu = Usuario.find_by id: jwt['uid']
        rescue JWT::ExpiredSignature
          render json: {st: 'El token ha expirado'}
        rescue
          render json: {st: 'Token inválido'}
        end
      else
        render json: {st: 'No hay token'}
      end
      return
    elsif sesion_invalida
      if request.xhr? # Si la petición es Ajax...
        if request.fullpath == '/noticias'
          render js: 'session_out();'
          return
        end

        case params[:action]
        when 'auto'
          render json: [{error: 'no_session'}]
        when 'list'
          render json: {error: 'no_session'}
        when 'validar'
          @ajax = 'alert(js_t("no_session"));'
          c = params[:campo]
          d = Vista.find_by({id: params[:vista].to_i}).try(:data)
          if d
            @fact = d[:fact]
            envia_campo(c, @fact[c]) if @fact
          end
          render js: @ajax
        else
          render js: 'alert(js_t("no_session"))'
        end
      else
        render_error '401'
      end

      return
    end

    session[:fem] = Time.now unless request.fullpath == '/noticias'    #Actualizar fecha de último uso
    I18n.locale = session[:locale]

    if params[:vista]
      @v = Vista.find_by id: params[:vista].to_i
      if @v
        @dat = @v.data
      else
        case params[:action]
          when 'auto'
            render json: [{error: 'no_vista'}]
          when 'list'
            render json: {error: 'no_vista'}
          else
            render js: 'alert(js_t("no_vista"))'
        end
        return
      end
    end

    if Nimbus::Config[:licencias] && %w(index edit new).include?(params[:action]) && !Licencia.get_licencia(@usu.id, session[:session_id])
      @mensaje = {tit: 'Aviso', msg: 'Hay demasiadas licencias en uso.<hr>Espere a que alguna quede libre o póngase en contacto con el administrador'}
      render html: '', layout: 'mensaje'
    end
  end

  def render_error(tag)
    case tag
    when '401'
      @mensaje = {
        tit: 'Permiso denegado',
        msg: 'No tiene autorización para ver el contenido de esta página.<hr>Es posible que no haya iniciado sesión'
      }
      st = 401
    when '404'
      @mensaje = {
        tit: 'La página no existe',
        msg: 'Es posible que haya tecleado mal la dirección.'
      }
      st = 404
    when '500'
      @mensaje = {
        tit: 'Error interno',
        msg: 'Contacte con el administrador.'
      }
      st = 500
    when 'emp'
      @mensaje = {
        tit: 'Empresa requerida',
        msg: 'Seleccione una empresa en la ventana principal.'
      }
      st = 406
    when 'eje'
      @mensaje = {
        tit: 'Ejercicio requerido',
        msg: 'Seleccione una empresa y ejercicio en la ventana principal.'
      }
      st = 406
    else
      @mensaje = {
        tit: 'Error no codificado',
        msg: 'Contacte con el administrador.'
      }
      st = 501
    end
    render html: '', status: st, layout: 'mensaje'
  end

  # Clase del modelo ampliado para este mantenimiento (con campos X etc.)
  def class_mant
    if self.class.superclass.to_s == 'GiController'
      GiMod
    else
      begin
        (self.class.to_s[0..-11] + 'Mod').constantize
      rescue
        nil
      end
    end
  end

  # Clase del modelo original
  def class_modelo
    class_mant.modelo_base rescue nil
  end

  def eval_cad(cad)
    cad.is_a?(String) ? eval('%~' + cad.gsub('~', '\~') + '~') : cad
  end

  # Funciones para interactuar con el cliente

  ##nim-doc {sec: 'Métodos de usuario', met: 'params2fact(go = true)', mark: :rdoc}
  #
  # Asigna valores a los campos de @fact si se han pasado como parámetros en la URL.
  # Si el parámetro _go_ es _true_ (que es su valor por defecto) y se ha recibido también
  # el parámetro _go_ en la URL, se llamará directamente al método <em>after_save</em>
  # al acabar <em>before_envia_ficha</em>, así el proceso se ejecuta inmediatamente.
  # Este método sólo tiene sentido usarlo en <em>before_envia_ficha</em>.
  #
  ##

  def params2fact(go = true)
    @fact.campos.each_key {|c| @fact[c] = params[c] if params[c]}
    @nimbus_go = true if go && params[:go]
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'mensaje(arg)', mark: :rdoc}
  #
  # Saca una ventana flotante modal mostrando un mensaje.
  #
  # <b>Parámetros</b>
  #
  # * *arg* (String, Hash) -- Si es un string se usará como texto del mensaje.
  #
  # <b>Opciones Hash (arg):</b>
  #
  # * *:msg* (String) -- Texto del mensaje a mostrar.
  # * *:tit* (String) <em>(Defalut: 'Aviso')</em> -- Título de la ventana del mensaje.
  # * *:width* (Integer) <em>(Defalut: nil)</em> -- Anchura de la ventana. Si no se especifica será automática.
  # * *:hmax* (Integer) <em>(Defalut: nil)</em> -- Máxima altura de la ventana. Si no se especifica será automática.
  # * *:hide_close* (Boolean) <em>(Default: false)</em> -- Si es _true_ no aparecerá el botón para cerrar
  #   el diálogo ni se podrá cerrar con <ESC>. En este caso es necesario que haya algún botón definido, ya
  #   que, si no, el mensaje se quedaría permanentemente.
  # * *:close* (Boolean) <em>(Default: true)</em> -- Indica si se cerrará o no el mensaje al pulsar en alguno de
  #   sus posibles botones.
  # * *:js* (String) <em>(Default: nil)</em> -- Contiene código javascript que se ejecutará al cerrar el diálogo.
  # * *:onload* (Boolean) <em>(Default: false)</em> -- Si es true el mensaje se generará después de cargar la página.
  #   Esto es útil para mensajes usados en before_envia_ficha.
  # * *:bot* (Array) <em>(Default: [])</em> -- Cada elemento del array es un hash que define un botón.
  #   Las posibles opciones del hash son:
  #   * *:label* (String) <em>(Default: '')</em> -- Es el texto a mostrar en el botón.
  #   * *:icon* (String) <em>(Default: nil)</em> -- Es el nombre de un icono de
  #     {material design}[https://material.io/resources/icons].
  #   * *:close* (Boolean) <em>(Default: hereda la opción _:close_ de _:arg_)</em> -- Indica si se
  #     cerrarará el diálogo después de ejecutar la acción asociada al botón.
  #   * *:accion* (Symbol, String) <em>(Default: nil)</em> -- Es el método del controlador que será
  #     llamado al pulsar el botón.
  #     Si es una String y comienza por "js:" se interpretará que lo que va a continuación es
  #     código javascript que se ejecutará al pulsar el botón. En este caso no hay llamada
  #     al servidor, salvo que el código javascript realice alguna.
  #   * *:busy* (Boolean) <em>(Default: false)</em> -- Si es true se mostrará una pantalla gris mientras
  #     dura la acción para prevenir interacciones del usuario.
  ##

  def mensaje(arg)
    arg = arg.is_a?(String) ? {msg: arg} : arg.deep_dup
    arg[:tit] ||= nt('aviso')
    arg[:close] = true if arg[:close].nil?
    arg[:context] ||= 'self' # Solo válido en mensajes sin botones (los botones saldrían sin estilo y las acciones podrían no encontrar el controlador/vista adecuado)
    arg[:bot] ||= []
    arg[:bot].each {|b|
      b[:close] = arg[:close] if b[:close].nil?
      b[:label] = nt(b[:label])
    }

    f_open = ''
    f_open << "$(this).parent().find('.ui-dialog-titlebar-close').css('display', 'none');" if arg[:hide_close]
    f_open << "$(this).parent().find('.nim-dialog-button').first().focus();" if arg[:bot].present?

    @ajax << '$(window).load(function(){' if arg[:onload]
    @ajax << %Q[$('<div class="nim-dialogo"></div>', #{arg[:context]}).html(#{arg[:msg].to_json}).dialog({]
    @ajax << "title: #{arg[:tit].to_json},"
    @ajax << %Q(resizable: false, modal: true, width: #{arg[:width] || '"auto"'},)
    @ajax << %Q(maxHeight: #{arg[:hmax]},) if arg[:hmax]
    @ajax << "closeOnEscape: false," if arg[:hide_close]
    @ajax << "close: function(){#{arg[:js] ? arg[:js] : ''};$(this).remove();},"
    @ajax << "open: function(){#{f_open}}," if f_open.present?
    @ajax << "create: function(){creaBotonesDialogo(#{arg[:bot].to_json},$(this))}" if arg[:bot].present?
    @ajax << '});'
    @ajax << '});' if arg[:onload]
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'select_options(cmp, val, options)'}
  # Asigna un set de opciones al campo <i>cmp</i> que previamente ha tenido que
  # ser declarado como "select" (cláusula <i>sel</i> en la definición de campos).
  # <i>val</i> será la opción por defecto que quedará seleccionada.
  # <i>options</i> es un hash con la lista de opciones (clave: valor).
  ##

  def select_options(cmp, val, options)
    cmp = cmp.to_sym

    return unless @fact.campos[cmp][:sel]

    @ajax << "$('##{cmp}').html('"
    options.each{|k, v|
      @ajax << %Q(<option value="#{k}">#{nt(v)}</option>)
    }
    @ajax << %Q[').val("#{val}");]

    @fact[cmp] = val
  end

  def enable_disable(c, ed)
    ty = rol = rich = nil

    if @fact
      v = @fact.campos[c.to_sym]
      if v
        ty = v[:type]
        rol = true if v[:rol]
        rich = v[:rich]
        v[:ro] = ed == :d ? :all : nil
      end
    end

    if c.to_s.ends_with?('_id') or rol
      @ajax << "$('##{c}').attr('readonly', #{ed == :d ? 'true' : 'false'}).attr('tabindex', #{ed == :d ? '-1' : '0'});"
    elsif ty == :date
      @ajax << "$('##{c}').datepicker('#{ed == :d ? 'disable' : 'enable'}');"
    elsif ty == :datetime
      @ajax << "$('#_f_#{c}').datepicker('#{ed == :d ? 'disable' : 'enable'}');"
      @ajax << "$('#_h_#{c}').attr('disabled', #{ed == :d ? 'true' : 'false'});"
    elsif ty == :boolean
      @ajax << "mdlCheckStatus('#{c}','#{ed}');"
    elsif ty == :text && rich
      @ajax << "nq_#{c}.enable(#{ed == :e ? 'true' : 'false'});"
    else
      @ajax << "$('##{c}').attr('disabled', #{ed == :d ? 'true' : 'false'});"
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable(campo)'}
  # Habilita el campo <i>campo</i>
  ##

  def enable(c)
=begin
    if c.to_s.ends_with?('_id')
      @ajax << "$('##{c}').attr('readonly', false).attr('tabindex', 0);"
    elsif @fact and @fact.campos[c.to_sym] and @fact.campos[c.to_sym][:type] == :date
      @ajax << "$('##{c}').datepicker('enable');"
    else
      @ajax << "$('##{c}').attr('disabled', false);"
    end
=end
    enable_disable(c, :e)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable(campo)'}
  # Deshabilita el campo <i>campo</i>
  ##

  def disable(c)
    enable_disable(c, :d)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_all'}
  # Deshabilita todos los campos
  ##

  def disable_all
    @ajax << '$(":input").attr("disabled", true);'
    #@ajax << '$(".page-content").css("pointer-events", "none");'
    status_botones grabar: false, crear: false, borrar: false
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable_menu(id)'}
  # Habilita la opción de @menu_r con id <i>id</i>
  ##

  def enable_menu(m)
    @ajax << "if (parent == self) $('##{m}').attr('disabled', false); else $('##{m}', parent.document).attr('disabled', false);"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_menu(id)'}
  # Deshabilita la opción de @menu_r con id <i>id</i>
  ##

  def disable_menu(m)
    @ajax << "if (parent == self) $('##{m}').attr('disabled', true); else $('##{m}', parent.document).attr('disabled', true);"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable_tab(tab)'}
  # Habilita la pestaña <i>tab</i>
  ##

  def enable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#t_#{t}').css('cursor', 'pointer');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_tab(tab)'}
  # Deshabilita la pestaña <i>tab</i>
  ##

  def disable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#').css('cursor', 'not-allowed');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_padre'}
  # deshabilita todos los campos del mantenimiento padre y el botón de grabar
  ##

  def disable_padre
    @ajax << '$(":input", parent.parent.document).attr("disabled", true);'
    @ajax << '$(".cl-grabar", parent.parent.parent.document).attr("disabled", true);'
    @ajax << '$("#dialog-borrar", parent.parent.document).parent().find(":input").attr("disabled", false);'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'visible(cmp)'}
  # Hace que el campo <i>cmp</i> sea visible
  ##

  def visible(c)
=begin
    if @fact.campos[c.to_sym][:type] == :boolean
      @ajax << "$('##{c}').parent().parent().css('display', 'block').parent().css('display', 'block');"
    else
      @ajax << "$('##{c}').parent().css('display', 'block').parent().css('display', 'block');"
    end
=end
    @ajax << "$('##{c}').closest('div').css('display', 'block').parent().css('display', 'block');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'invisible(cmp, collapse)'}
  # Hace que el campo <i>cmp</i> desaparezca de pantalla.
  # Si <i>collapse</i> vale true hará que desaparezca el elemento y su hueco, acomodándose el resto de elementos al nuevo layout.
  # Por el contrario si vale false el elemento desaparece pero el hueco continúa.
  ##

  def invisible(c, collapse=false)
=begin
    if @fact.campos[c.to_sym][:type] == :boolean
      @ajax << "$('##{c}').parent().parent().#{collapse ? 'parent().' : ''}css('display', 'none');"
    else
      @ajax << "$('##{c}').parent().#{collapse ? 'parent().' : ''}css('display', 'none');"
    end
=end
    @ajax << "$('##{c}').closest('div').#{collapse ? 'parent().' : ''}css('display', 'none');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'visible_element(elemento)'}
  # Hace que el elemento del DOM <i>elemento</i> sea visible
  ##

  def visible_element(c)
    @ajax << "$('##{c}').css('display', 'block');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'invisible_element(elemento)'}
  # Hace que el elemento del DOM <i>elemento</i> desaparezca de pantalla.
  ##

  def invisible_element(c)
    @ajax << "$('##{c}').css('display', 'none');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'foco(cmp)'}
  # Cede el foco al campo <i>cmp</i>
  ##

  def foco(c)
    @ajax_post << '$("#' + c.to_s + '").focus();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'abre_dialogo(dlg)'}
  # Abre el diálogo <i>dlg</i>
  ##

  def abre_dialogo(diag)
    @ajax_post << "$('##{diag}').dialog('open');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'cierra_dialogo(dlg)'}
  # Cierra el diálogo <i>dlg</i>
  ##

  def cierra_dialogo(diag)
    @ajax << "$('##{diag}').dialog('close');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'edita_ficha(id)'}
  # Edita la ficha con id <i>id</i> del mantenimiento en curso
  ##

  def edita_ficha(id)
    #@ajax << "window.open('/#{params[:controller]}/#{id}/edit', '_self');"
    @ajax << "parent.editInForm(#{id});"
  end

  def add_empeje_to_url(url)
    uri = URI(url)
    # Si hay un host explícito (url externa) no hacer nada
    return(url) if uri.host

    q = URI.decode_www_form(uri.query.to_s).to_h
    q['eid'] = @dat[:eid] if !q.include?('eid') && @dat[:eid].present?
    q['jid'] = @dat[:jid] if !q.include?('jid') && @dat[:jid].present?

    q.present? ? uri.path + '?' + URI.encode_www_form(q) : url
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'open_url(url)'}
  # Abre la URL especificada en una nueva pestaña
  ##

  def open_url(url)
    @ajax << "window.open('#{add_empeje_to_url(url)}', '_blank');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'index_reload'}
  # Vuelve a cargar la página index del mantenimiento
  ##

  def index_reload
    @ajax << 'if (parent != self) parent.location.reload();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_reload'}
  # Actualiza el contenido del grid
  ##

  def grid_reload
    @ajax << 'parentGridReload();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_show'}
  # Muestra el grid del mantenimiento
  ##

  def grid_show
    @ajax << 'parentGridShow();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_hide'}
  # Oculta el grid del mantenimiento
  ##

  def grid_hide
    @ajax << 'parentGridHide();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'status_botones(hash)'}
  # Control del estado de los botones del mantenimiento
  # Nombres de los botones (claves del hash): editar, crear, grabar, borrar
  # Los valores de cada clave (botón) pueden ser: true (habilitar), false (deshabilitar), nil (eliminar el botón)
  # Ej.: status_botones borrar: nil, editar: true, grabar: false
  ##

  def status_botones(h={})
    h[:borrar] = false if @dat && %w(b c).include?(@dat[:prm]) && h[:borrar]
    h[:grabar] = false if @dat && %w(c).include?(@dat[:prm]) && h[:grabar]
    @ajax << "statusBotones(#{h.to_json});"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: "envia_fichero(file:, file_cli: nil, rm: true, disposition: 'attachment', popup: false, tit: file_cli)", mark: :rdoc}
  #
  # Método para hacer download de un fichero.
  #
  # <b>Parámetros</b>
  #
  # * *file* (String) -- Path del fichero a descargar.
  # * *file_cli* (String) <em>(Default: el "basename" de file)</em> -- Es el nombre que se propondrá para almacenar la descarga.
  # * *rm* (Boolean) <em>(Default: true)</em> -- Si vale _true_ el fichero se borrará tras la descarga.
  # * *disposition* (String) <em>(Default: 'attachment')</em> -- Puede valer 'attachment' para que el fichero se descargue, o 'inline' para que
  #   se muestre directamente en el navegador si éste es capaz de visualizar el contenido.
  # * *popup* (Boolean, Symbol) <em>(Default: false)</em> -- Si vale _true_ la ventana donde se muestra el fichero será flotante
  #   (solo válido para disposition: 'inline'). Si vale _false_ se abrirá en una ventana nueva. Si vale :self se abrirá en la ventana
  #   que ha hecho la llamada reemplazando el contenido de ésta.
  # * *tit* (String) <em>(Default: file_cli)</em> -- Título que aparecerá en la pestaña que muestra el fichero si _disposition_
  #   es 'inline'.
  # Ejemplo de uso:
  #   envia_fichero file: '/tmp/zombi.pdf', file_cli: 'datos.pdf', rm: false
  ##

  def envia_fichero(file:, file_cli: nil, rm: true, disposition: 'attachment', popup: false, tit: file_cli)
=begin
    flash[:file] = file
    flash[:file_cli] = file_cli
    flash[:rm] = rm
    flash[:disposition] = disposition
=end
    cry = ActiveSupport::MessageEncryptor.new Rails.application.secrets[:secret_key_base][0..31]
    arg = {file: file, file_cli: file_cli, rm: rm, disposition: disposition}.to_json
    tit = tit ? '/' + tit.gsub('/', '-').gsub(/[?&]/, ' ') : ''
    url = "/nim_download#{tit}?#{URI.encode_www_form({data: cry.encrypt_and_sign(arg)})}"

    popup = :self if @nimbus_go && !popup

    if disposition == 'attachment'
      @ajax << "window.location.href='#{url}';"
    else
      if popup
        if popup == :self
          @ajax << "window.open('#{url}', '_self');"
        else
          @ajax << "window.open('#{url}', '_blank', 'width=700, height=750, left=' + (window.screenLeft + (window.outerWidth - 700)/2) + ', top=10');"
        end
      else
        @ajax << "window.open('#{url}');"
      end
    end
  end

  def nim_download
    if params[:data]
      cry = ActiveSupport::MessageEncryptor.new Rails.application.secrets[:secret_key_base][0..31]
      begin
        args = JSON.parse(cry.decrypt_and_verify(params[:data])).symbolize_keys
      rescue
        render_error '500'
        return
      end
    else
      args = {file: flash[:file], file_cli: flash[:file_cli], disposition: flash[:disposition], rm: flash[:rm]}
    end

    if args[:file]
      file_name = args[:file]
      unless File.exist? file_name
        render_error '404'
        return
      end
    else
      render_error '401'
      return
    end

    if file_name.split('.')[-1].upcase == 'TXT'
      send_data File.read(file_name), filename: args[:file_cli] || file_name.split('/')[-1], type: 'text/plain; charset=utf-8', disposition: args[:disposition] || 'attachment'
    else
      send_data File.read(file_name), filename: args[:file_cli] || file_name.split('/')[-1], disposition: args[:disposition] || 'attachment'
    end
    FileUtils.rm_f(file_name) if args[:rm]
  end

  # Método para poder solicitar archivos del servidor a través de GET
  # Sólo se admiten ficheros que si empiezan por "/" se refieran a "/tmp..."
  # No se admiten ficheros que contengan en su path ".."
  # Si el fichero comienza por "~/" se asume que es un path que arranca del home del proyecto (sólo válido para el usuario "admin")
  # En cualquier otro caso se supone que el path es relativo a la carpeta "data" del proyecto

  def nim_send_file
    f = params[:file]
    if f.nil? || f.include?('..') || f[0] == '/' && !f.starts_with?('/tmp/') || f[0..1] == '~/' && @usu.codigo != 'admin'
      head :no_content
      return
    end
    if f[0..1] == '~/'
      f = f[2..-1]
    elsif f[0] != '/'
      f = "#{Nimbus::DataPath}/#{f}"
    end
    if File.file? f
      send_file f, disposition: :inline
    else
      head :no_content
    end
  end

  def nim_path_image(modelo, id, tag)
    src = Dir.glob("#{Nimbus::DataPath}/#{modelo}/#{id}/_imgs/#{tag}.*")
    src.size > 0 ? "src='/nim_send_file?file=#{src[0][Nimbus::DataPath.size+1..-1]}'" : ''
  end

  def nim_image(mod: class_modelo, id: (@fact.respond_to?(:id) ? @fact.id : 0), tag:, hid: nil, w: nil, h: nil)
    h = 25 if w.nil? && h.nil?
    "<img #{hid ? 'id=' + hid : ''} #{nim_path_image(mod, id, tag)}#{w ? ' width=' + w.to_s : ''}#{h ? ' height=' + h.to_s: ''} />"
  end

  def nim_asset_image(img:, hid: nil, w: nil, h: nil)
    h = 25 if w.nil? && h.nil?
    "<img #{hid ? 'id=' + hid : ''} src='#{helpers.image_path(img)}'#{w ? ' width=' + w.to_s : ''}#{h ? ' height=' + h.to_s : ''} />"
  end

  def ir_a_origen
    return unless @fact.id

    org = $nim_origenes[@fact[params[:cmp]].to_sym]

    unless org
      mensaje 'Origen no registrado'
      return
    end

    url = org[:clase].constantize.method(org[:metodo]).call(@fact.id)

    if !url or url.empty?
      mensaje 'No existe la ficha asociada'
    else
      open_url url
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'crea_iframe(cmp:, src:, height: 300)'}
  # Crea un iframe sobre el campo X <i>cmp</i>, que debe estar declarado con type: :div<br>
  # <i>src</i> es la url que mostrará el iframe y <i>height</i> la altura del mismo.<br>
  # Este último argumento es opcional y por defecto vale 300px.
  ##

  def crea_iframe(cmp:, src:, height: 300)
    @fact[cmp] = add_empeje_to_url(src)
    @ajax << %Q($('##{cmp}').html('<iframe src="#{@fact[cmp]}" style="height: #{height}px"></iframe>');)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'crea_boton(cmp:, label: nil, icon: nil, title: nil, mdl: false, accion: nil, busy: false)', mark: :rdoc}

  # Crea un botón sobre un campo de tipo :div (definido con "type: :div" en @campos)
  #
  # <b>Parámetros</b>
  #
  # * *cmp* (Symbol, String) -- Indica el campo sobre el que se construirá el botón.
  # * *label* (String) <em>(Default: nil)</em> -- Es el texto a mostrar en el botón (solo se aplica si _mdl_ es true).
  # * *icon* (String) <em>(Default: nil)</em> -- Es el nombre de un icono de
  #   {material design}[https://material.io/resources/icons].
  # * *title* (String) <em>(Default: nil)</em> -- Es el texto a mostrar en el tooltip al posar el ratón encima.
  # * *mdl* (Boolean) <em>(Default: false)</em> -- Indica el aspecto del botón. Si es _true_ el botón tendrá el aspecto
  #   de los botones "favoritos" de material design: Redondos y del color secundario (como los de las cabeceras de los
  #   mantenimientos); en este caso solo se usa el icono (_icon_) y se ignorará la _label_. Si es false, el botón será
  #   un rectángulo del color primario, aceptando _icon_ y _label_ (como los botones de los diálogos).
  # * *accion* (Symbol, String) <em>(Default: nil)</em> -- Es el método del controlador que será
  #   llamado al pulsar el botón.
  #   Si es una String y comienza por "js:" se interpretará que lo que va a continuación es
  #   código javascript que se ejecutará al pulsar el botón. En este caso no hay llamada
  #   al servidor, salvo que el código javascript realice alguna.
  # * *busy* (Boolean) <em>(Default: false)</em> -- Si es true se mostrará una pantalla gris mientras
  #   dura la acción para prevenir interacciones del usuario.
  ##

  def crea_boton(cmp:, label: nil, icon: nil, title: nil, mdl: false, accion: nil, busy: false)
    if mdl
      @ajax << %Q(#{cmp}.innerHTML = creaMdlButton("b_#{cmp}", 36, 0, 24, '#{icon}', '#{title}');)
    else
      htm = %Q(<button id="b_#{cmp}" class="mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-js-ripple-effect" title="#{title}">)
      htm += '<i class="material-icons">' + icon + '</i>'  + (label ? '&nbsp;' : '') if icon
      htm += "#{label}</button>"
      @ajax << %Q(#{cmp}.innerHTML = #{htm.to_json};)
    end

    @ajax << "$('#b_#{cmp}').click(function(){clickNimButton('#{accion}', #{busy ? 'true' : 'false'})});" if accion
  end

  # Métodos para ejecutar procesos en segundo plano con seguimiento

  #class P2PSysCancel < StandardError
  class P2PSysCancel < SystemExit
    # Clase para generar la excepción que detenga un proceso en segundo plano (p2p) al recibir un kill TERM (15)
  end

  class P2PCancel < SystemExit
    # Clase para generar la excepción que detenga un proceso en segundo plano (p2p) al recibir un kill INT (2) (al cancelar el usuario)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'p2p(label: nil, pbar: nil, js: nil, st: :run)'}
  # <i>st</i> indica el status del proceso. Los posibles valores son:<ul>
  # <li>:run: El proceso está en marcha</li>
  # <li>:fin: El proceso ha finalizado (esto es de cara al cliente. El server puede continuar)</li>
  # <li>:err: Ha ocurrido un error en el proceso. No se llamará al método 'fin' si existiera</li>
  # </ul>
  ##

  def p2p(label: nil, pbar: nil, js: nil, st: :run)
    @dat[:p2p][:label] = label if label
    @dat[:p2p][:pbar] = pbar if pbar
    @dat[:p2p][:js] = js if js
    @dat[:p2p][:st] = st
    @v.save
  end

  def p2p_req
    if params[:p2ps] == '1'  # Proceso en curso
=begin
      begin
        Process.waitpid(@dat[:p2p][:pid], Process::WNOHANG)
      rescue
        @dat[:p2p][:st] = :fin unless @dat[:p2p][:st] == :err
      end
=end
      p2ps = [:fin, :run, :err].index(@dat[:p2p][:st])
      @ajax << "p2pStatus=#{p2ps};" if p2ps != 1
    else  # Proceso cancelado
      begin
        Process.kill('INT', -@dat[:p2p][:pid])
        Process.waitpid(@dat[:p2p][:pid])
      rescue
      end

      @v.reload
      @dat = @v.data
    end

    #@ajax << "$('#p2p-d',#{@dat[:p2p][:mant] ? 'parent.document' : 'document'}).html(#{@dat[:p2p][:label].html_safe.to_json});" if @dat[:p2p][:label]
    @ajax << "$('#p2p-d',#{@dat[:p2p][:mant] ? 'parent.document' : 'document'}).html(#{@dat[:p2p][:label].html_safe.to_json}).parent().scrollTop(100000);" if @dat[:p2p][:label]
    @ajax << "$('#p2p-p',#{@dat[:p2p][:mant] ? 'parent.document' : 'document'})[0].MaterialProgress.setProgress(#{@dat[:p2p][:pbar]});" if @dat[:p2p][:tpb] == :fix and @dat[:p2p][:pbar]
    @ajax << @dat[:p2p][:js] if @dat[:p2p][:js]
  end

  def exe_p2p(tit: 'En proceso', label: nil, pbar: :inf, cancel: false, width: nil, info: '', tag: nil, fin: {label: 'Finalizar', met: nil})
    busy = P2p.count >= Nimbus::Config[:p2p][:tot]
    busy = (P2p.where(tag: tag).count >= Nimbus::Config[:p2p][tag]) if !busy && Nimbus::Config[:p2p][tag]
    if busy
      mensaje 'El servidor está sobrecargado.<br>Por favor, inténtelo más tarde'
      return
    end

    @v.save # Por si hay cambios en @fact, etc. que se graben antes del fork y así padre e hijo tienen la misma información

    # Poner en orden el argumento 'fin'
    case fin
      when String
        fin = {label: fin, met: nil}
      when Symbol
        fin = {label: nil, met: fin}
      when NilClass
        fin = {label: nil, met: nil}
      when Hash
        fin[:label] = 'Finalizar' unless fin.include?(:label)
        fin[:met] = nil unless fin.include?(:met)
      else
        raise ArgumentError, 'El argumento <fin> de exe_p2p tiene que ser String, Symbol, Nil o Hash'
    end

    if Rails.version < '6'
      config = ActiveRecord::Base.connection_config
    else
      config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
    end

    clm = class_mant
    mant = clm ? class_mant.mant? : false

    # Crear el proceeso hijo
    h = fork {
      # Cierro todos los sockets que haya abiertos para que no interfieran
      # en las lecturas que de ellos haga el parent (básicamente los requests http)
      ObjectSpace.each_object(IO) {|io| io.close if io.class == TCPSocket and !io.closed?}
      begin
        # Establecer conexión con la base de datos
        config[:pool] = 1
        ActiveRecord::Base.establish_connection(config)
      rescue Exception => e
        p2p label: 'Error al conectar con la base de datos', st: :err
        pinta_exception(e)
        return
      end

      # Registrar el proceso en la tabla p2p
      P2p.create(usuario_id: @usu.id, fecha: Nimbus.now, ctrl: self.class.to_s, info: info, tag: tag, pgid: Process.pid)

      # Para hacer de este proceso el líder de grupo (por si lanza nuevos comandos poderlos matar a todos de golpe)
      Process.setsid

      @dat[:p2p] = {pid: Process.pid, label: label, tpb: pbar, mant: mant, st: :run}
      @v.save

      Signal.trap('TERM') do
        raise P2PSysCancel, 'Cierre forzado'
      end

      Signal.trap('INT') do
        raise P2PCancel, 'Cancelado'
      end

      begin
        yield
        p2p st: :fin
      rescue P2PCancel
        #
      rescue P2PSysCancel
        p2p label: 'Proceso cancelado por el sistema', st: :err
      rescue Exception => e
        p2p label: 'Error interno', st: :err
        pinta_exception(e)
      ensure
        P2p.where(pgid: Process.pid).delete_all
        ActiveRecord::Base.connection.disconnect!
      end
    }

    # Código específico del padre...

    # No hacer seguimiento del status del hijo (para que no quede zombi al terminar)
    Process.detach(h)

    # Código javascript para sacar el cuadro de diálogo de progreso del hijo
    @ajax << "p2p(#{tit.to_json}, #{label.to_s.to_json}, #{pbar.to_json}, #{cancel.to_json}, #{width.to_json}, #{mant.to_json}, #{fin.to_json});"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: "abre_bus(mod:, tit: nil, met: nil, wh: nil, pref: nil, div: nil, w: 700, h: 500, x: 0, y: 0)", mark: :rdoc}
  #
  # Método para sacar una ventana de búsqueda
  #
  # <b>Parámetros</b>
  #
  # * *mod* (ActiveRecord::Base, String) -- Modelo sobre el que realizar la búsqueda.
  # * *tit* (String) <em>(Default: nil)</em> -- Título de la ventana de búsqueda. Si _nil_ se usará el nombre del modelo.
  # * *met* (Symbol, String) <em>(Default: nil)</em> -- Método que se llamará al seleccionar un registro en la ventana de búsqueda.
  #   En el método tendremos disponible el _id_ del registro seleccionado a través de la clave _:id_ del hash _params_.
  #   Si vale _nil_, al seleccionar un registro se editará en el controlador asociado al modelo de la búsqueda.
  # * *wh* (String) <em>(Default: nil)</em> -- Es una cadena que puede contener una cláusula _where_ para limitar la búsqueda.
  # * *pref* (String) <em>(Default: nil)</em> -- Indica un fichero _yml_ de preferencias para la búsqueda.
  #   El path tiene que ser completo desde la raíz del proyecto.
  # * *div* (Symbol, String) <em>(Default: nil)</em> -- Indica un campo (de @campos) cuyo _type_ tiene que ser _:div_
  #   donde embeber la ventana de búsqueda. Si vale _nil_ la búsqueda aparecerá en una ventana flotante independiente.
  # * *w* (Integer) <em>(Default: 700)</em> -- Indica la anchura de la ventana de búsqueda. Si _div_ es distinto de _nil_
  #   este parámetro se ignorará y la anchura del _div_ será la correspondiente a su _gcols_.
  # * *h* (Integer) <em>(Default: 500)</em> -- Indica la altura de la ventana/div de búsqueda.
  # * *x* (Integer) <em>(Default: 0)</em> -- Indica la posición X (desde el borde izquierdo de la pantalla) de la ventana de búsqueda.
  #   Si _div_ es distinto de _nil_ este parámetro se ignorará.
  # * *y* (Integer) <em>(Default: 0)</em> -- Indica la posición Y (desde el borde superior de la pantalla) de la ventana de búsqueda.
  #   Si _div_ es distinto de _nil_ este parámetro se ignorará.
  ##

  def abre_bus(mod:, tit: nil, met: nil, wh: nil, pref: nil, div: nil, w: 700, h: 500, x: 0, y: 0)
    flash[:mod] = mod.to_s
    flash[:tit] = tit if tit
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    flash[:wh] = wh if wh
    flash[:tipo] = "metodo: #{met}" if met
    flash[:pref] = pref if pref

    if div
      crea_iframe cmp: div, src: '/bus', height: h
    else
      @ajax << "window.open('/bus', 'bus_met', 'width=#{w}, height=#{h}, left=#{x}, top=#{y}');"
    end
  end

  # Método para invocar al explorador de documentos asociados (oficina sin papeles: osp)
  def osp
    if @usu.admin
      prm_osp = 'p'
    else
      eid = @dat[:eid] || get_empeje[0]
      prm_osp = @usu.pref.dig(:permisos, :ctr, '_osp_', eid.to_i)
    end

    if Nimbus::Config[:osp] && prm_osp && @fact && @fact.id
      cms = class_modelo.to_s
      flash[:tit] = "#{nt(cms)}: #{forma_campo_id(cms, @fact.id, :osp)}"
      if @fact.respond_to?(:osp_ruta)
        flash[:ruta] = "#{Nimbus::DataPath}/#{@fact.osp_ruta}"
      else
        flash[:ruta] = "#{Nimbus::DataPath}/#{cms}/#{@fact.id}/osp"
      end
      #flash[:prm] = @dat[:prm]
      if @dat[:prm] == 'c' || prm_osp == 'c'
        flash[:prm] = 'c'
      elsif @dat[:prm] == 'b' || prm_osp == 'b'
        flash[:prm] = 'b'
      else
        flash[:prm] = 'p'
      end

      FileUtils.mkpath(flash[:ruta])

      @ajax << 'window.open("/osp", "_blank", "width=700, height=500, left=" + (window.screenLeft + (window.outerWidth - 700)/2) + ", top=" + (window.screenTop + (window.outerHeight - 500)/2));'
    end
  end

  # Métodos para el manejo del histórico de un modelo

  def histo
    begin
      modulo = params[:modulo] ? params[:modulo].capitalize + '::' : ''
      tab = params[:tabla].singularize.camelize
      modelo = (modulo + tab).constantize # Para cargar los modelos
      modeloh = (modulo + 'H' + tab).constantize # Para ver si existe (si tiene histórico)
    rescue
      render_error '404'
      return
    end

    # Control de permisos
    unless @usu.admin
      fr = modeloh.find_by idid: params[:id]

      unless fr
        render_error '404'
        return
      end

      if modelo == Empresa
        eid = fr.idid
      elsif fr.respond_to? :empresa
        eid = fr.empresa.id
      else
        eid = get_empeje[0].to_i
      end

      unless @usu.pref.dig(:permisos, :ctr, '_acc_hist_', eid) && @usu.pref.dig(:permisos, :ctr, modeloh.ctrl_for_perms, eid)
        render_error '401'
        return
      end
    end

    #@titulo = 'Histo: ' + modelo.table_name + '/' + params[:id]
    begin
      clave = params[:idb] ? forma_campo_id(modeloh, params[:idb]) : forma_campo_id(modelo, params[:id])
    rescue
      clave = nil
    end
    @titulo = 'Histo: ' + modelo.table_name + ' ' + (clave ? clave : "id: #{params[:id]}")
    @url_list = '/histo_list?modelo=' + modeloh.to_s + '&id=' + params[:id]
    @url_edit = '/'
    @url_edit << (params[:modulo] ? params[:modulo] + '/' : '')
    @url_edit << params[:tabla]
    render html: '', layout: 'histo'
  end

  def histo_list
    mod = params[:modelo].constantize

    w = 'idid=' + params[:id]
    tot_records = mod.where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << c2[0]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    sql = mod.where(w).order(ord).offset((page-1)*lim).limit(lim);

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      #h[:cell] <<  s.created_at.to_time.to_s[0..-7]
      h[:cell] <<  s.created_at.strftime('%d-%m-%Y %H:%M:%S')
      h[:cell] << s.created_by.try(:codigo)
      res[:rows] << h
    }
    render :json => res
  end

  def histo_borrados
    mod = class_modelo.to_s
    flash[:tit] = "Registros borrados de #{nt(mod)}"
    moda = mod.split('::')
    moda[-1] = 'H' + moda[-1]
    flash[:mod] = moda.join('::')
    flash[:ctr] = params[:controller].sub('::', '/')
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    flash[:wh] = 'idid < 0'
    flash[:tipo] = 'hb'

    open_url("/bus")
  end

  def histo_borrados_sel
    open_url("/histo/#{params[:ctr]}/#{-params[:mod].constantize.find(params[:id]).idid}?idb=#{params[:id]}");
  end

  def call_histo_pk
    flash[:mod] = class_modelo.to_s
    flash[:id] = @fact.id
    flash[:head] = 0
    flash[:nivel] = @nivel || class_mant.nivel
    open_url '/histo_pk'
  end

  def sincro_hijos(posponer = false, lock = false)
    hijos = class_mant.hijos
    return if hijos.empty?

    #id_hijos = params[:hijos] ? eval('{' + params[:hijos] + '}') : {}
    id_hijos = params[:hijos] ? JSON.parse('{' + params[:hijos] + '}').symbolize_keys : {}
    @ajax << '$(window).load(function(){' if posponer
    hijos.each_with_index {|h, i|
      next unless h[:url]

      @ajax << '$("#hijo_' + i.to_s + '").attr("src", "/' + h[:url]
      @ajax << '?mod=' + class_modelo.to_s
      @ajax << '&id=' + @fact.id.to_s
      @ajax << '&padre=' + @v.id.to_s
      @ajax << '&eid=' + @dat[:eid].to_s if @dat[:eid]
      @ajax << '&jid=' + @dat[:jid].to_s if @dat[:jid]
      @ajax << "&id_edit=#{id_hijos[h[:url].to_sym]}" if id_hijos[h[:url].to_sym]
      # Si posponer es true (caso de la primera carga desde "edit") pasar el permiso vigente (por si hay bloqueo)
      @ajax << '&lock=1' if posponer && lock
      @ajax << '");'
    }
    @ajax << '});' if posponer
  end

  def get_empeje
    #emej = cookies[:emej].split(':')
    emej = cookies[Nimbus::CookieEmEj] ? cookies[Nimbus::CookieEmEj].split(':') : ['null', 'null']
    eid = params[:eid]
    eid ||= (emej[0] == 'null' ? nil : emej[0])
    jid = params[:jid]
    jid ||= (emej[1] == 'null' ? nil : emej[1])

    return [eid, jid]
  end

  def ini_ajax
    @ajax = ''
    @ajax_post = ''
    @ajax_load = ''
  end

  def render_ajax
    render js: @ajax + @ajax_post
  end

  # Método llamado cuando en la url solo se especifica el nombre de la tabla
  # En general la idea es que la vista asociada sea un grid
  def index
    ini_ajax

    self.respond_to?('before_index') ? r = before_index : r = true
    return if render_before_ine(r)

    clm = class_mant
    mod_tab = clm.table_name

    eid, jid = get_empeje

    # Tener en cuenta que puede llegar el parámetro prm en modo consulta ('c') en el caso de que venga de un padre con bloqueo (nimlock)
    if @usu.admin
      #prm = 'p'
      prm = params[:lock] ? 'c' : 'p'
      prm_hist = 'p'
      prm_osp = 'p'
    else
      prm = @usu.pref[:permisos] && @usu.pref[:permisos][:ctr] && @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][eid.to_i]
      prm = 'c' if prm && params[:lock]
      prm_hist = @usu.pref.dig(:permisos, :ctr, '_acc_hist_', eid.to_i)
      prm_osp = @usu.pref.dig(:permisos, :ctr, '_osp_', eid.to_i)
    end

    case prm
      when nil
        render_error '401'
        return
      when 'c'
        #status_botones crear: false
        # ¡Ojo! Aquí no se puede usar status_botones ya que al ser el "index" el context se puede equivocar cuando sea un mantenimiento hijo ya que éste también tendrá un parent.document
        @ajax << '$(".cl-crear").remove();'
    end

    w = ''
    wemej = ''
    ljoin = ''
    if params[:mod]
      add_where(w, mod_tab + '.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id])
    else
      if clm.respond_to?('ejercicio_path')
        if jid
          ljoin = clm.ejercicio_path
          wemej = "#{ljoin.empty? ? mod_tab : 't_emej'}.ejercicio_id=#{jid}"
        else
          render_error 'eje'
          return
        end
      elsif clm.respond_to?('empresa_path')
        if eid
          ljoin = clm.empresa_path
          wemej = "#{ljoin.empty? ? mod_tab : 't_emej'}.empresa_id=#{eid}"
        else
          render_error 'emp'
          return
        end
      end
    end

    # Añadir, si existe, un filtro especial definido en el modelo para limitar la búsqueda.
    # El método tiene que ser un método de clase (self.) y recibirá como argumento un hash
    # con los parámetros que se ven en la llamada de abajo.
    add_where(w, clm.bus_filter({usu: @usu, eid: eid, jid: jid})) if clm.respond_to? :bus_filter

    @v = Vista.create
    @v.data = {}
    @dat = @v.data
    @dat[:eid] = eid
    @dat[:jid] = jid
    @dat[:persistencia] = {}
    @g = @dat[:persistencia]

    grid = clm.grid.deep_dup
    call_nimbus_hook :grid_conf, grid

    grid[:cellEdit] = false if prm == 'c'
    grid[:visible] = false if params[:hidegrid]

    add_where(w, grid[:wh]) if grid[:wh]

    @dat[:auto_comp] = {_pk_input: w} unless w.empty?
    @dat[:wgrid] = w.dup
    add_where(@dat[:wgrid], wemej)
    lj = [grid[:ljoin]]
    lj << ljoin + '(t_emej)' unless ljoin.empty?
    @dat[:cad_join] = ljoin_parse(clm, lj)[:cad]

    @view = {grid: grid}
    @view[:eid] = eid
    @view[:jid] = jid
    @view[:id_edit] = params[:id_edit] ? params[:id_edit] : 0
    @view[:prm_hist] = prm_hist
    @view[:prm_osp] = prm_osp
    @view[:model] = clm.superclass.to_s
    @view[:menu_r] = clm.menu_r
    # Adecuar menu_l añadiendo a las url la empresa y el ejercicio
    m_l = clm.menu_l.deep_dup
    m_l.each {|m| m[:url] = add_empeje_to_url(m[:url])}
    @view[:menu_l] = m_l
    @view[:url_base] = '/' + params[:controller] + '/'
    @view[:url_list] = @view[:url_base] + 'list'
    @view[:url_new] = @view[:url_base] + 'new'
    @view[:arg_edit] = '?head=0'
    @view[:arg_edit] << '&lock=1' if params[:lock]
    arg_list_new = @view[:arg_edit].clone

    if params[:mod] != nil
      padre = params[:padre] ? "&padre=#{params[:padre]}" : ''
      arg_list_new << '&mod=' + params[:mod] + '&id=' + params[:id] + padre
      @view[:arg_edit] << padre
    end

    arg_ej = ''
    arg_ej << '&eid=' + eid if eid
    arg_ej << '&jid=' + jid if jid

    if clm.respond_to?('ejercicio_path')
      @j = Ejercicio.find_by id: jid
      @e = @j.empresa
    elsif clm.to_s != 'EjerciciosMod' and clm.respond_to?('empresa_path')
      @e = Empresa.find_by id: eid
    end

    @view[:arg_auto] = @v ? "&vista=#{@v.id}&cmp=_pk_input" : arg_ej
    #set_titulo(clm.titulo, @e&.codigo, @j&.codigo, true) unless @titulo
    if @titulo
      @titulo_htm ||= @titulo
    else
      set_titulo(clm.titulo, @e&.codigo, @j&.codigo, clm.column_names.include?('ejercicio_id'))
    end

    @view[:url_list] << arg_list_new + arg_ej + (@v ? "&vista=#{@v.id}" : '')
    @view[:url_new] << arg_list_new + arg_ej
    @view[:arg_edit] << arg_ej

    # Pasar el parámetro v.id para poder usarlo en las fichas como referencia para bloqueos
    @view[:url_new] << "&idindex=#{@v.id}"
    @view[:arg_edit] << "&idindex=#{@v.id}"

    # Pasar como herencia el argumento especial 'arg'
    if params[:arg]
      @view[:url_new] << '&arg=' + params[:arg]
      @view[:arg_edit] << '&arg=' + params[:arg]
    end

    @view[:hijos] = clm.hijos

    if params[:hijos]
      @view[:arg_edit] << '&hijos=' + params[:hijos]
    end

    rich = false
    if clm.mant? # No es un proc, y por lo tanto preparamos los datos del grid
      @view[:url_cell] = @view[:url_base] + '/validar_cell'

      #cm = clm.columnas.map{|c| clm.campos[c.to_sym][:grid]}.deep_dup
      @dat[:columnas] = []  # Aquí construimos un array con las columnas visibles para usarlo en el método "list"
      cm = clm.columnas.
        select{|c| clm.propiedad(c, :visible, binding)}.
        map{|c|
          @dat[:columnas] << c;
          v = clm.campos[c.to_sym]
          rich = true if v[:rich]
          v[:grid]
        }.deep_dup
      cm.each {|h|
        h[:label] = nt(h[:label])
        if h[:edittype] == 'select'
          h[:editoptions][:value].each{|c, v|
            h[:editoptions][:value][c] = nt(v)
          }
        end
        if h[:stype] == 'select' && h[:searchoptions][:value] && h[:searchoptions][:value].is_a?(Hash)
          h[:searchoptions][:value].each{|c, v|
            h[:searchoptions][:value][c] = nt(v)
          }
        end
      }
      call_nimbus_hook :grid_col_model, cm
      @view[:col_model] = eval_cad(clm.col_model_html(cm))
    end

    call_nimbus_hook :after_index

    @v.save
    @ajax << '_vista=' + @v.id.to_s + ';_controlador="' + params['controller'] + '";'
    # Añadir distintivo de color de la empresa si procede
    @ajax << %Q($("body").append('<div class="#{@e.param[:estilo]}" style="background-color: #{@e.param[:color]}"></div>');) if @e && @e.param[:estilo] && @e.param[:estilo] != 'nil' && !params[:mod]

    # Incluir la hoja de estilo quill si hay campos "rich" en el grid
    @assets_stylesheets = @assets_stylesheets.to_a + %w(quill/nim_quill) if rich

    pag_render('grid')
  end

  # Método para añadir a la cadena 's' el valor 'v' concatenado con 'AND'
  def add_where(s, v)
    if v and v.strip != ''
      s << ' AND ' unless s == ''
      s << v
    end
  end

  # Método que provee de datos a las peticiones del grid

  def list
    # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)
    unless request.xhr?
      render json: ''
      return
    end

    clm = class_mant
    w = @dat[:wgrid] ? @dat[:wgrid] : ''

    # Definimos @e y @j por si hay campos que los utilizan algún parámetro (p.ej. :decim)
    @e = Empresa.find_by(id: @dat[:eid]) if @dat[:eid]
    @j = Ejercicio.find_by(id: @dat[:jid]) if @dat[:jid]

    if params[:filters]
      fil = JSON.parse(params[:filters]).deep_symbolize_keys
      fil[:rules].each {|f|
        #[:eq,:ne,:lt,:le,:gt,:ge,:bw,:bn,:in,:ni,:ew,:en,:cn,:nc,:nu,:nn]
        op = f[:op].to_sym

        fa = f[:field].split('.')
        field = fa.map{|c| %Q("#{c.gsub('"', '""')}")}.join('.')
        if fa[-2].nil? || fa[-2] == clm.table_name
          ty = clm.campos[fa[-1].to_sym][:type]
        else
          begin
            ty = fa[-2].model.columns_hash[fa[-1]].type
          rescue
            # Esto sería el caso en el que no se puede inferir el modelo
            # final, por ejemplo si hay dos campos id en un grid que
            # apuntan al mismo modelo, ya que, el método joins de
            # ActiveRecord usa una nomenclatura para estos casos en la
            # que no es inferible el nombre del modelo final.
            # A falta de una solución precisa (guardando el tipo final
            # en una clave nueva de @campos), suponemos que el tipo
            # será :string (válido en el 99% de los casos).
            ty = :string
          end
        end

        if op == :nu or op == :nn
          add_where w, field
          w << ' IS'
          w << ' NOT' if op == :nn
          w << ' NULL'
          next
        end

        add_where w, ([:bn,:ni,:en,:nc].include?(op) ? 'NOT ' : '') + (ty == :string ? 'UNACCENT(LOWER(' + field + '))' : field)
        w << ({eq: '=', ne: '<>', cn: ' LIKE ', bw: ' LIKE ', ew: ' LIKE ', nc: ' LIKE ', bn: ' LIKE ', en: ' LIKE ', in: ' IN (', ni: ' IN (', lt: '<', le: '<=', gt: '>', ge: '>='}[op] || '=')
        if op == :in or op == :ni
          f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase.gsub('\'', '\'\'') + '\','}
          w.chop!
          w << ')'
        else
          w << '\''
          w << '%' if [:ew,:en,:cn,:nc].include?(op)
          w << (ty == :string ? I18n.transliterate(f[:data]).downcase.gsub('\'', '\'\'') : f[:data].gsub('\'', '\'\''))
          w << '%' if [:bw,:bn,:cn,:nc].include?(op)
          w << '\''
        end
      }
    end

    eager = []
    sel = ''

    # Mirar si algún campo es de otra tabla para incluirla en la lista de eager-load
    # Componer también la cadena select (con los campos sql)
    @dat[:columnas].each{|c|
      if c.ends_with?('_id')
        eager << c[0..-4]
      end
      v = clm.campos[c.to_sym]
      if v[:sql]
        sel << '(' + v[:sql][:select] + ') as ' + c + ','
      end
    }
    sel.chop! if sel.ends_with?(',')

    # Formar la cadena de ordenación y seguir incluyendo tablas en eager-load
    #
    #ord = ''
    #sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    #sort_elem.each{|c|
      #c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      #ord << c2[0]
      #ord << (c2[1] ? ' ' + c2[1] : '') + ','
    #}
    #ord = ord[0..-2] + ' ' + params[:sord] if ord != ''
    ord = params[:sidx]
    ord += ' ' + params[:sord] if ord.present?

    begin
      tot_records =  clm.eager_load(eager).joins(@dat[:cad_join]).where(w).count
      lim = params[:rows].to_i
      tot_pages = tot_records / lim
      tot_pages += 1 if tot_records % lim != 0
      page = params[:page].to_i
      page = 1 if page <=0
      #page = tot_pages if page > tot_pages
      if page > tot_pages
        render json: {page: tot_pages, total: tot_pages, records: tot_records, rows: []}
        return
      end

      sql = clm.eager_load(eager).joins(@dat[:cad_join]).where(w).order(Arel.sql(ord)).offset((page-1)*lim).limit(lim)

      res = {page: page, total: tot_pages, records: tot_records, rows: []}
      sql.each {|s|
        # Inyectar variable @ctrl para que esté disponible en campos calculados a través de métodos
        s.instance_variable_set('@ctrl', {usu: @usu, emp: @e, eje: @j, eid: @dat[:eid], jid: @dat[:jid]})
        @fact = s
        h = {:id => s.id, :cell => []}
        @dat[:columnas].each {|c|
          begin
            h[:cell] << forma_campo(:grid, s, c, s[c]).to_s
          rescue
            h[:cell] << ''
          end
        }
        res[:rows] << h
      }
    rescue => e
      res = {page: 0, total: 0, records: 0, rows: []}
      logger.debug e.message
      logger.debug e.backtrace.join("\n")
    end
    render :json => res
  end

  def pag_render(pag, lay=pag)
    if self.class.nimbus_views && self.class.nimbus_views[pag.to_sym]
      r = ''
      self.class.nimbus_views[pag.to_sym].each {|v|
        r << File.read(v)
      }

      render inline: r, layout: lay
    else
      begin
        render action: pag, layout: lay
      rescue
        render html: '', layout: lay
      end
    end
  end

  def set_titulo(tit, ecod, jcod, list_ej = false)
    @titulo = "#{ecod}#{jcod ? '/' : ''}#{jcod} #{tit}".strip
    if jcod && list_ej && @dat
      @titulo_htm = "#{ecod}&nbsp;/"
      @titulo_htm << '<select id="sel-nim-ejer" onchange="selNewEjercicio()">'
      Ejercicio.where(empresa: @dat[:eid]).order(fec_inicio: :desc).pluck(:id, :codigo).each{|j|
        @titulo_htm << %Q(<option #{j[1] == jcod ? 'selected' : ''} value="#{j[0]}">#{j[1]}</option>)
      }
      @titulo_htm << '</select>'
      @titulo_htm << tit
    else
      @titulo_htm = @titulo
    end
  end

  def var_for_views(clm)
    #@titulo = clm.titulo
    set_titulo(@titulo || clm.titulo, @e&.codigo, @j&.codigo)
    @tabs = []
    @on_tabs = []
    @hijos = clm.hijos
    @dialogos = clm.dialogos
    @fact.campos.each{|_c, v|
      @tabs << v[:tab] if v[:tab] and !@tabs.include?(v[:tab]) and v[:tab] != 'pre' and v[:tab] != 'post'
    }
    clm.hijos.each{|h|
      @tabs << h[:tab] if h[:tab] and !@tabs.include?(h[:tab]) and h[:tab] != 'pre' and h[:tab] != 'post' and !@fact.campos.include?(h[:tab].to_sym)
    }

    if self.respond_to?('ontab_')
      @on_tabs << 'ontab_'
    else
      @tabs.each {|t|
        f = "ontab_#{t}"
        @on_tabs << f if self.respond_to?(f)
      }
    end

    #@head = (params[:head] ? params[:head].to_i : 1)
    @head = (flash[:head] || params[:head] || 1).to_i
    @menu_l = clm.menu_l
    @menu_r = clm.menu_r

    @es_un_mant = clm.mant?
  end

  def set_empeje(eid=0, jid=0)
    if eid == 0
      @e = @fact.empresa if @fact.respond_to?('empresa')
    else
      @e = eid ? Empresa.find_by(id: eid) : nil
    end

    if jid == 0
      @j = @fact.ejercicio if @fact.respond_to?('ejercicio')
    else
      @j = jid ? Ejercicio.find_by(id: jid) : nil
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'call_metodo_parent(metodo, nivel = 0)', mark: :rdoc}

  # Llama al método _metodo_ del mantenimiento padre, abuelo, etc, según el _nivel_ indicado.
  #
  # <b>Parámetros</b>
  # * *metodo* (Symbol, String) -- Método al que se quiere llamar.
  # * *nivel* (Integer) <em>(Default: 0)</em> -- Indica el nivel de profundidad: padre (0), abuelo (1), etc.
  ##

  def call_metodo_parent(metodo, nivel = 0)
    @ajax << 'parent.' * 2 * (nivel + 1) + "nimAjax('#{metodo}');"
  end

  def set_parent
    if params[:padre]
      @dat[:pid] = params[:padre]
      @dat[:vp] = Vista.find(params[:padre])
      @fact.parent = @dat[:vp].data[:fact]
    end
  end

  def graba_v
    @v.save
    if @dat[:vp]
      @dat[:vp].data[:hijos] ||= {}
      @dat[:vp].data[:hijos][params[:controller]] = @v.id
      @dat[:vp].save
    end
  end

  def fact_hijo(ctrl)
    h = (@v.data[:hijos] && @v.data[:hijos][ctrl]) ? Vista.find_by(id: @v.data[:hijos][ctrl]) : nil
    h ? h.data[:fact] : nil
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'fact_parent(nivel = 0)', mark: :rdoc}

  # Devuelve la ficha @fact del mantenimiento padre, abuelo, etc, según el _nivel_ indicado.
  #
  # <b>Parámetros</b>
  # * *nivel* (Integer) <em>(Default: 0)</em> -- Indica el nivel de profundidad: padre (0), abuelo (1), etc.
  ##

  def fact_parent(nivel = 0)
    #@v_parent = Vista.find(@dat[:pid]) if @dat[:pid] && @v_parent.nil?
    #@v_parent ? @v_parent.data[:fact] : nil
    @v_parent ||= []
    return @v_parent[nivel].data[:fact] if @v_parent[nivel]
    pid = @dat[:pid]
    (0..nivel).each {|n|
      return nil unless pid
      @v_parent[n] ||= Vista.find(pid)
      pid = @v_parent[n].data[:pid]
    }
    @v_parent[nivel].data[:fact].class.new  # Ver comentario en get_fact_from_marshal
    @v_parent[nivel].data[:fact]
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'sincro_parent(nivel = 0)', mark: :rdoc}

  # Sincroniza los cambios hechos en la ficha @fact del mantenimiento padre, abuelo, etc, según el _nivel_ indicado.
  #
  # <b>Parámetros</b>
  # * *nivel* (Integer) <em>(Default: 0)</em> -- Indica el nivel de profundidad: padre (0), abuelo (1), etc.
  ##

  def sincro_parent(nivel = 0)
    #@v_parent ? @v_parent.save : @dat[:vp].save
    #@ajax << 'parent.parent.callFonServer("envia_ficha");'
    if @v_parent
      if @v_parent[nivel]
        @v_parent[nivel].save
        call_metodo_parent :envia_ficha, nivel
      end
    else
      @dat[:vp].save
      @ajax << 'parent.parent.callFonServer("envia_ficha");'
    end
  end

  def render_before_ine(r)
    return true if performed?
    if r
      if r.is_a? Hash
        @mensaje = r
        r[:tit] ||= 'Aviso'
        render html: '', layout: 'mensaje'
        return true
      else
        return false
      end
    else
      render_error '401'
      return true
    end
  end

  def assets_for_rich
    @fact.campos.each_value {|v|
      if v[:type] == :text && v[:rich]
        @assets_javascripts = @assets_javascripts.to_a + %w(quill/nim_quill)
        @assets_stylesheets = @assets_stylesheets.to_a + %w(quill/nim_quill)
        break
      end
    }
  end

  def assets_for_nim_firma
    @fact.campos.each_value {|v|
      if v[:img] && v[:img][:firma]
        @assets_javascripts = @assets_javascripts.to_a + %w(nimFirma/nimFirma)
        break
      end
    }
  end

  def new
    ini_ajax

    self.respond_to?('before_new') ? r = before_new : r = true
    return if render_before_ine(r)

    clm = class_mant

    @v = Vista.new
    @v.data = {}
    @dat = @v.data
    @dat[:persistencia] = {}
    @g = @dat[:persistencia]
    @dat[:fact] = clm.new
    @fact = @dat[:fact]
    @fact.user_id = session[:uid]
    @dat[:head] = params[:head] if params[:head]
    @dat[:idindex] = params[:idindex].to_i

    set_parent

    if clm.superclass.to_s == 'Empresa'
      eid = jid = 0
    elsif clm.superclass.to_s == 'Ejercicio'
      eid = get_empeje[0]
      jid = 0
    else
      eid, jid = get_empeje
    end

    @dat[:eid] = eid
    @dat[:jid] = jid

    if @usu.admin
      @dat[:prm] = 'p'
    else
      @dat[:prm] = @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][@dat[:eid] ? @dat[:eid].to_i : 0]
      if @dat[:prm].nil? or @dat[:prm] == 'c'
        render_error '401'
        return
      end
    end

    if params[:mod]
      # Si es un mant hijo, inicializar el id del padre
      @fact[params[:mod].split(':')[-1].downcase + '_id'] = params[:id]
    else
      if clm.respond_to?('ejercicio_path')
        if jid.nil?
          render_error 'eje'
          return
        else
          @fact.ejercicio_id = jid.to_i if clm.column_names.include?('ejercicio_id')
        end
      elsif clm.respond_to?('empresa_path')
        if eid.nil?
          render_error 'emp'
          return
        else
          @fact.empresa_id = eid.to_i if clm.column_names.include?('empresa_id')
        end
      end
    end

    set_empeje(eid, jid)

    # Inyectar variable @ctrl para que esté disponible en campos calculados a través de métodos
    @fact.instance_variable_set('@ctrl', {usu: @usu, emp: @e, eje: @j, eid: @dat[:eid], jid: @dat[:jid]})

    var_for_views(clm)

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    #Activar botones necesarios (Grabar/Borrar)
    status_botones grabar: true, borrar: false, osp: false
    @ajax << 'setMenuR(false);'

    call_nimbus_hook :before_envia_ficha
    envia_ficha true

    if @usu.audit
      @dat[:audit_ctrl] = params[:controller]
      Auditoria.create usuario_id: @usu.id, fecha: Nimbus.now, controlador: params[:controller], accion: 'A'
    end

    graba_v
    @ajax << '_vista=' + @v.id.to_s + ',_controlador="' + params['controller'] + '",eid="' + eid.to_s + '",jid="' + jid.to_s + '";'

    # Incluir los assets necesarios si hay algún campo de tipo :text con rich: true
    assets_for_rich
    # Incluir los assets necesarios si hay algún campo :img con firma: true
    assets_for_nim_firma

    pag_render('ficha')
  end

  def edith
    clm = class_mant
    cls = class_modelo.to_s.split('::')
    clmh = (cls.size == 1 ? 'H' + cls[0] : cls[0] + '::H' + cls[1]).constantize
    fh = clmh.find_by id: params[:id][1..-1]
    if fh.nil?
      render_error '404'
      return
    end

    # Control de permisos

    unless @usu.admin
      if cls[0] == 'Empresa'
        eid = fh.idid
      elsif fh.respond_to? :empresa
        eid = fh.empresa.id
      else
        eid = get_empeje[0].to_i
      end

      unless @usu.pref.dig(:permisos, :ctr, '_acc_hist_', eid) && @usu.pref.dig(:permisos, :ctr, clmh.ctrl_for_perms, eid)
        render_error '401'
        return
      end
    end

    fo = clmh.where('idid = ? AND created_at < ?', fh.idid, fh.created_at).order(:created_at).last
    fo = fh if fo.nil?
    @fact = clm.new
    dif = ''
    clmh.column_names.each {|c|
      @fact[c] = fh[c] if c != 'id' && @fact.respond_to?(c)

      cmp = @fact.campos[c.to_sym]
      if cmp && cmp[:form] && cmp[:visible] && @fact[c] != fo[c]
        dif << "$('##{c}#{cmp[:type] == :text && cmp[:rich] ? ' .ql-editor' : ''}').addClass('nim-campo-cambiado');"
      end
    }

    set_empeje

    var_for_views(clm)

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    ini_ajax
    envia_ficha
    # Deshabilitar campos "normales"
    @ajax << '$(":input").attr("disabled", true);'
    # Deshabilitar campos "rich"
    @ajax << 'for(var e of $(".nq-contenedor")) window["nq_"+e.id].disable();'
    @ajax << dif

    # Incluir los assets necesarios si hay algún campo de tipo :text con rich: true
    assets_for_rich

    render html: '', layout: 'ficha'
  end

  def edit
    clm = class_mant

    if clm.mant? and params[:id][0] == 'h'
      edith
      return
    end

    if clm.mant?
      if params[:id] == '0'   # Para mostrar fichas vacías con todo deshabilitado
        @fact = clm.new
        @fact.id = 0
      else
        @fact = clm.find_by id: params[:id]
        if @fact.nil?
          render_error '404'
          return
        end
        @fact.user_id = session[:uid]
      end
    else
      @fact = clm.new
    end

    ini_ajax

    ((!clm.mant? or @fact.id != 0) and self.respond_to?('before_edit')) ? r = before_edit : r = true
    return if render_before_ine(r)

    call_nimbus_hook :ini_campos

    @v = Vista.new
    @v.data = {}
    @dat = @v.data
    @dat[:persistencia] = {}
    @g = @dat[:persistencia]
    @dat[:fact] = @fact
    @dat[:head] = params[:head] if params[:head]

    set_parent

    emp_perm = nil

    eid, jid = get_empeje

    if clm.mant?
      if @fact.id != 0
        if @fact.respond_to?('empresa')
          @dat[:eid] = @fact.empresa.id
        elsif clm.superclass.to_s == 'Empresa'
          @dat[:eid] = @fact.id
          @e = @fact
        else
          emp_perm = get_empeje[0].to_i
        end

        if @fact.respond_to?('ejercicio')
          @dat[:jid] = @fact.ejercicio.id
        elsif clm.superclass.to_s == 'Ejercicio'
          @dat[:jid] = @fact.id
        end

        set_empeje

        #Activar botones necesarios (Grabar/Borrar)
        status_botones grabar: true, borrar: true, osp: true
      else
        set_empeje(*get_empeje)

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: false, borrar: false});'
      end
    else
      @dat[:eid] = eid
      @dat[:jid] = jid

      case @nivel || clm.nivel
        when :e
          unless eid
            render_error 'emp'
            return
          end
          set_empeje(eid, nil)
        when :j
          unless jid
            render_error 'eje'
            return
          end
          set_empeje(eid, jid)
      end
    end

    emp_perm ||= @dat[:eid].to_i

    # Control de permisos
    @dat[:prm] = 'p'
    unless @usu.admin or params[:controller] == 'gi' or (clm.mant? and @fact.id == 0)
      @dat[:prm] = @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][emp_perm]
    end

    call_nimbus_hook(:set_permiso) if clm.mant? && @fact.id != 0

    if @dat[:prm].nil?
      render_error '401'
      return
    end

    # Inyectar variable @ctrl en @fact para que esté disponible en campos calculados a través de métodos
    @fact.instance_variable_set('@ctrl', {usu: @usu, emp: @e, eje: @j, eid: @dat[:eid] || eid, jid: @dat[:jid] || jid})

    @dat[:idindex] = params[:idindex].to_i
    @dat[:prm] = 'c' if params[:lock]

    blq = (@dat[:prm] == 'c')
    if clm.mant? && @fact.id != 0 && clm.nim_lock && @dat[:prm] != 'c'
      begin
        add_nim_lock
      rescue ActiveRecord::RecordNotUnique
        # El registro está bloqueado
        Bloqueo.transaction {
          blq = Bloqueo.lock.find_by controlador: params[:controller], ctrlid: @fact.id
          if blq.idindex != 0 && blq.idindex == @dat[:idindex]
            # El registro está siendo reeditado en la misma ventana
            blq.activo = true # Para que no se borre el bloqueo y así se puede reaprovechar
            blq.save
            @ajax << "_nimlock=#{blq.id};"
            blq = nil
          else
            mensaje onload: true, tit: 'Registro bloqueado', msg: "El registro está siendo editado por:<br><br>Usuario: #{blq.created_by.nombre}<br>Fecha: #{fecha_texto(blq.created_at, :long)}<br><br>Se activará el modo 'sólo lectura'."
            @dat[:prm] = 'c'
          end
        }
      end
    end

    case @dat[:prm]
      when 'b'
        status_botones borrar: false
      when 'c'
        status_botones grabar: false, borrar: false
        @ajax << 'soloLectura();'
    end

    # Activar/Desactivar las opciones necesarias en menu_r
    @ajax << "setMenuR(#{clm.mant? ? (@fact.id == 0) : true});"

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    @ajax << 'eid="' + @dat[:eid].to_s + '",jid="' + @dat[:jid].to_s + '";'

    var_for_views(clm)

    call_nimbus_hook :before_envia_ficha

    unless clm.mant? && @fact.id == 0
      if @usu.audit
        @dat[:audit_ctrl] = (params[:controller] == 'gi' ? 'gi/run/' + params[:modulo] + '/' + params[:formato] : params[:controller])
        Auditoria.create usuario_id: @usu.id, fecha: Nimbus.now, controlador: @dat[:audit_ctrl], accion: 'E', rid: (clm.mant? ? @fact.id : nil)
      end

      envia_ficha true
      graba_v
      @ajax << '_vista=' + @v.id.to_s + ';_controlador="' + params['controller'] + '";'
      sincro_hijos(true, blq ? true : false) if clm.mant?
    end

    # Incluir los assets necesarios si hay algún campo de tipo :text con rich: true
    assets_for_rich
    # Incluir los assets necesarios si hay algún campo :img con firma: true
    assets_for_nim_firma

    mi_render if self.respond_to?(:mi_render)

    unless performed?
      if @nimbus_go && self.respond_to?(:after_save)
        after_save
        render html: '', layout: 'basico_ajax'
      else
        pag_render('ficha')
      end
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'set_auto_comp_filter(cmp, wh)'}
  # Asocia el filtro where <i>wh</i> al campo <i>cmp</i>. El campo tiene que ser de tipo _id
  # <i>wh</i> Puede ser:
  # <ul>
  # <li>String: En este caso contendrá la cadena del where</li>
  # <li><pre>Symbol: En este caso se puede referir a otro campo del mantenimiento, en cuyo caso
  #     se compondrá autómaticamente un where de la forma 'campo = valor_de_ese_campo',
  #     o a un método de clase del controlador. En ese caso el método será llamado en
  #     cada ocasión que haya que filtrar, recibirá como argumentos @fact y el hash params,
  #     y tiene que devolver una cadena con el where (filtro) a aplicar.</pre></li>
  # </ul>
  ##

  def set_auto_comp_filter(cmp, wh)
    if wh.is_a? Symbol  # En este caso wh es un método de clase del controlador u otro campo de @fact
      if self.class.respond_to?(wh) # Es un método de clase del controlador
        wh = [self.class.to_s, wh]
      else # Es otro campo
        v = @fact[wh]
        wh = wh.to_s + ' = \'' + (v ? v.to_s : '0') + '\''
      end
    end
    #@ajax << 'set_auto_comp_filter($("#' + cmp.to_s + '"),"' + wh + '");'
    @dat[:auto_comp] ? @dat[:auto_comp][cmp.to_sym] = wh : @dat[:auto_comp] = {cmp.to_sym => wh}
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'set_auto_comp_empresa(cmp, eid)', mark: :rdoc}

  # Cambia la empresa por la que se filtran los registros de un campo references (_id)
  #
  # <b>Parámetros</b>
  #
  # * *cmp* (Symbol, String) -- Campo al que queremos cambiar el filtro
  # * *eid* (Integer) -- id de la empresa por la que queremos filtrar
  ##

  def set_auto_comp_empresa(cmp, eid)
    @ajax << "setAutoCompEmpeje('#{cmp}', #{eid}, 'e');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'set_auto_comp_ejercicio(cmp, jid)', mark: :rdoc}

  # Cambia el ejercicio por el que se filtran los registros de un campo references (_id)
  #
  # <b>Parámetros</b>
  #
  # * *cmp* (Symbol, String) -- Campo al que queremos cambiar el filtro
  # * *jid* (Integer) -- id del ejercicio por el que queremos filtrar
  ##

  def set_auto_comp_ejercicio(cmp, jid)
    @ajax << "setAutoCompEmpeje('#{cmp}', #{jid}, 'j');"
  end

  def _auto(par)
    unless request.xhr? # Si la petición no es Ajax... ¡Puerta! (para evitar accesos desde la barra de direcciones)
      #render json: ''
      return ''
    end

    p = par[:term]
    if p == '-' or p == '--'
      #render json: ''
      return ''
    end

    mod = par[:mod].constantize

    whv = nil
    if @dat
      ac = @dat[:auto_comp]
      #whv = ac ? ac[par[:cmp].to_sym] : nil
      if ac
        whv = ac[par[:cmp].to_sym]
        if whv.is_a? Array
          whv = (whv[0].constantize).send(whv[1], @dat[:fact], params)
        end
      end
    end

    if par[:type]
      type = par[:type].to_sym
    else
      type = :form
    end

    data = mod.auto_comp_data

    if mod.respond_to?(:auto_comp_test)
      r = mod.auto_comp_test(p)
    else
      r = nil
    end

    orden = nil
    if r.nil?
      # Si el texto introducido acaba en ^ revertir el orden de búsqueda.
      if p[-1] == '^'
        orden = data[:orden].upcase.ends_with?(' DESC') ? data[:orden][0..-6] : data[:orden] + ' DESC'
        p = p[0..-2]
      end

      if p[0] == '-'
        patron = p[1..-1]
      else
        patron = '%' + p
      end

      if patron[-1] == '-'
        patron = patron[0..-2]
      else
        patron << '%'
      end

      patron.gsub!('.', '%')
    else
      patron = r
    end

    patron = '\'' + I18n.transliterate(patron.gsub('"', '\"').gsub('\'', '\'\'')).downcase + '\''

    wh = '('
    data[:campos].each {|c|
=begin
      if mod.columns_hash[c].type == :integer
        begin
          n = Integer(p)
          wh << c + '=' + n.to_s + ' OR '
        rescue
        end
      else
        wh << 'UNACCENT(LOWER(' + c + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
      end
=end
      #wh << 'UNACCENT(LOWER(' + c.to_s + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
      wh << "UNACCENT(LOWER(#{c})) LIKE #{patron} OR "
    }

    wh = wh[0..-5] + ')'

    #wh << ' AND ' + mod.table_name + '.' + 'empresa_id=' + par[:eid] if mod.column_names.include?('empresa_id') and par[:eid]
    #wh << ' AND ' + mod.table_name + '.' + 'ejercicio_id=' + par[:jid] if mod.column_names.include?('ejercicio_id') and par[:jid]
    if mod.respond_to?(:ejercicio_path)
      ep = mod.ejercicio_path
      ep = ep + '.' unless ep.empty?
      ep = ep + 'ejercicio_id'
      msel = mselect_parse(mod, mod.auto_comp_mselect, ep)
      edb = msel[:alias_cmp][ep][:cmp_db]
      wh << " AND #{edb}=#{(par[:jid] || @dat[:jid])}"
    elsif mod.respond_to?(:empresa_path)
      ep = mod.empresa_path
      ep = ep + '.' unless ep.empty?
      ep = ep + 'empresa_id'
      msel = mselect_parse(mod, mod.auto_comp_mselect, ep)
      edb = msel[:alias_cmp][ep][:cmp_db]
      wh << " AND #{edb}=#{(par[:eid] || @dat[:eid])}"
    else
      msel = mselect_parse(mod, mod.auto_comp_mselect)
    end

    mod.select(msel[:cad_sel]).joins(msel[:cad_join]).where(wh).where(whv).order(orden || data[:orden]).limit(15).map {|r|
      {value: r.auto_comp_value(type), id: r[:id], label: r.auto_comp_label(type)}
    }
  end

  def auto
    render json: _auto(params)
  end

  def fact_clone
    #@fant = @fact.respond_to?(:id) ? {id: @fact.id} : {}
    #@fact.campos.each {|c, v| @fant[c] = @fact.method(c).call}
    fant = @fact.respond_to?(:id) ? {id: @fact.id} : {}
    #@fact.campos.each {|c, v| fant[c] = @fact.method(c).call}
    @fact.campos.each {|c, v| fant[c] = @fact[c]}
    @fant = fant.deep_dup
  end

  def forma_campo_id(ref, id, tipo = :form)
    return('') if id.nil? or id == 0 or id == ''

    mod = ref.is_a?(String) ? ref.constantize : ref
    ret = mod.mselect(mod.auto_comp_mselect).where(mod.table_name + '.id=' + id.to_s)[0]
    ret ? ret.auto_comp_value(tipo) : nil
  end

  def forma_campo_axlsx(cp, cmp, val)
    if cmp.ends_with?('_id')
      forma_campo_id(cp[:ref], val, :form)
    elsif cp[:sel].is_a? Hash
      (val.class == String) ? cp[:sel][val.to_sym] || cp[:sel][val] : cp[:sel][val]
    else
      Nimbus.nimval(val)
    end
  end

  def _forma_campo(tipo, cp, cmp, val)
=begin
    if cmp.ends_with?('_id')
      if val and val != 0 and val != ''
        ret = forma_campo_id(cp[:ref], val, tipo)
      else
        ret = ''
      end
      return ret
    end
=end

    if val.nil?
      ''
    elsif cmp.ends_with?('_id')
      forma_campo_id(cp[:ref], val, tipo)
    else
      case cp[:type].to_sym
        when :integer
          (cp[:sel]) ? val.to_s : number_with_precision(val, separator: ',', delimiter: '.', precision: 0)
        when :float, :decimal
          (cp[:sel]) ? val.to_s : number_with_precision(val, separator: ',', delimiter: '.', precision: (cp[:decim].is_a?(String) ? eval_cad(cp[:decim]).to_i : cp[:decim] || 2))
        when :date
          tipo == :lgrid ? val : val.to_s(:sp)
        when :time
          val.is_a?(String) ? val : val.strftime('%H:%M' + (cp[:seg] ? ':%S' : ''))
        when :datetime
          val.is_a?(String) ? val : val.strftime('%d-%m-%Y %H:%M' + (cp[:seg] ? ':%S' : ''))
        else
          if cp[:rol] == :origen
            nt(val)
          else
            val
          end
      end
    end
  end

  def forma_campo(tipo, ficha, cmp, val)
    cp = ficha.respond_to?('campos') ? ficha.campos[cmp.to_sym] : class_mant.campos[cmp.to_sym]
    if cp[:img] && tipo == :grid
      self.respond_to?(cmp) ? method(cmp).call : nim_image(id: ficha.id, tag: cmp, w: cp[:img][:wg], h: cp[:img][:hg])
    else
      _forma_campo(tipo, cp, cmp, val)
    end
  end

  def envia_campo(cmp, val, ajax = true)
    cmp_s = cmp.to_s
    cp = @fact.campos[cmp.to_sym]

    return('') if cp[:img]

    case cp[:type]
    when :boolean
      val = false unless val
      res = "mdlCheck('#{cmp_s}',#{val});"
    when :div
      if cp[:grid_sel]
        res = "setSelectionGridLocal('#{cmp}', #{@fact[cmp].to_json});"
        @ajax_post << res if ajax
        return res
      else
        res = ''
      end
    when :datetime
      res = '$("#_f_' + cmp_s + '").val(' + (val ? val.strftime('%d-%m-%Y').to_json : '""') + ');'
      res << '$("#_h_' + cmp_s + '").val(' + (val ? val.strftime('%H:%M' + (cp[:seg] ? ':%S' : '')).to_json : '""') + ');'
    when :upload
      # No hacer nada
      res = ''
    else
      if cp[:type] == :text && cp[:rich]
        res = '$("#' + cmp_s + ' .ql-editor").html(' + val.to_json + ');'
      else
        res = '$("#' + cmp_s + '").val(' + forma_campo(cp[:auto_tipo] || :form, @fact, cmp_s, val).to_json + ')'
        res << '.attr("dbid",' + val.to_s + ')' if cmp_s.ends_with?('_id') and val
        res << ';'
      end
    end

    @ajax << res if ajax
    res
  end

  def call_on(c, val)
    cs = c.to_sym
    v = @fact.campos[cs]
    hay_on = false
    if self.respond_to?(v[:on].to_s)
      hay_on = true
      val_ant = val.dup rescue val
      method(v[:on]).arity == 0 ? method(v[:on]).call() : method(v[:on]).call(cs)
    end

    fun = ('on_' + c).to_sym
    if self.respond_to?(fun)
      unless hay_on
        val_ant = val.dup rescue val
        hay_on = true
      end
      method(fun).call
    end

    if self.class.nimbus_hooks and self.class.nimbus_hooks[fun]
      unless hay_on
        val_ant = val.dup rescue val
        hay_on = true
      end
      self.class.nimbus_hooks[fun].each {|f|
        method(f).call
      }
    end

    if hay_on
      val = @fact[cs]
      return [val_ant != val, val]
    else
      return [false, val]
    end
  end

  def sincro_ficha(h={})
    vcg = []
    vc = [nil]
    while vc != []
      vc = []
      @fact.campos.each {|cs, ch|
        c = cs.to_s
        if vcg.include?(cs)
          vc.delete_if {|cv| cv[0] == cs}
          next
        end

        v = @fact[cs]
        va = @fant[cs]
        if v != va
          vc << [cs, v]
          vcg << cs

          if v.is_a? HashForGrids
            sincro_grid(cs, v, va) if va
          else
            res, v = call_on(c, v)

            if h[:ajax] and ch[:form] and (res or c != h[:exclude])
              envia_campo(c, v)
            end
          end
        end
      }
      h.delete :exclude
      vc.each {|cv|
        @fant[cv[0]] = cv[1]
      }
    end
  end

  def sincro_grid(cmp, v, va)
    celdas = []
    cambios = true
    while cambios
      cambios = false
      v[:data].each_with_index {|r, i|
        v[:cols].each_with_index {|c, j|
          name = c[:name]
          next if celdas.index{|z| z[0] == r[0] and z[1] == name}
          val = r[j+1]
          if val != va[:data][i][j+1]
            cambios = true
            #celdas << [r[0], name, val]
            celdas << [r[0], name, _forma_campo(:form, c, c[:name], val)]
            fun = "on_#{cmp}_#{name}"
            method(fun).call(r[0], val) if self.respond_to?(fun)
            va[:data][i][j+1] = val
          end
        }
      }
    end
    @ajax_post << "setDataGridLocal('#{cmp}',#{celdas.to_json});" unless celdas.empty?
  end

  def envia_ficha(dirty = false)
    @fact.campos.each {|c, v|
      envia_campo(c, @fact[c]) if v[:form]
      v[:val_ini] = @fact[c] if dirty && v[:dirty] && v[:type] != :div
    }
  end

  #### VALIDAR

  def raw_val(c, v)
    cp = @fact.campos[c.to_sym]

    case cp[:type]
      when :integer, :float, :decimal
        return v.gsub('.', '').gsub(',', '.')
      when :string
        return v.upcase if cp[:may]
      when :boolean
        return v == 'true'
    end

    return v
  end

  def procesa_vali(err)
    if err.nil? or err == ''
      @last_error = [nil, :blando, false]
    elsif err.is_a? String
      @last_error = [err, :duro, false]
    else  # Se supone que es un hash con dos claves: :msg (con el texto del error) y :tipo (:duro o :blando)
      @last_error = [err[:msg], err[:tipo] || :blando, err[:reponer]]
    end
  end

  def valida_campo(campo, tipo)
    err = nil
    t1 = t2 = :blando
    fun = 'vali_' << campo

    if self.respond_to?(fun)
      err, t1 = procesa_vali(method(fun).call)
    end

    if @fact.respond_to?(fun)
      e, t2 = procesa_vali(@fact.method(fun).call)
      if e != nil
        if err.nil?
          err = e
        else
          err << '<br>' + e
        end
      end
    end

    (tipo == :duro and t1 == :blando and t2 == :blando) ? nil : err
  end

  def validar_local_cell
    cmp = params[:cmp].to_sym
    row = params[:row]
    col = params[:col]
    val = params[:val]
    if val
      case @fact[cmp].col(col)[:type]
        when :references
          val = val.to_i
        when :integer
          val = val.gsub('.', '').gsub(',', '.').to_i
        when :decimal
          val = val.gsub('.', '').gsub(',', '.').to_d
        when :date
          val = val.to_date
        when :time
          val = val.to_time
        when :boolean
          val = (val == 'true')
      end
    end
    @fact[cmp].data(row, col, val)
    #@fant[cmp].data(row, col, val)

    fun = "vali_#{cmp}_#{col}"

    err, t1 = procesa_vali(method(fun).call(row, val)) if self.respond_to?(fun)
    mensaje(err) if err

    fun = "on_#{cmp}_#{col}"
    method(fun).call(row, val) if self.respond_to?(fun)

    if err && @last_error[2]  # Hay que reponer el valor anterior del campo (cuando se cierre el mensaje)
      @fact[cmp].data(row, col, @fant[cmp].data(row, col))
      @fant[cmp].data(row, col, nil)
    else
      # Para que no se vuelva a enviar el campo en sincro_ficha
      @fant[cmp].data(row, col, val)
    end

    #@ajax << 'hayCambios=true;'
  end

  def validar_cell
    clm = class_mant
    campo = ''
    valor = ''
    params.each {|p, v|
      next if ['sel', 'id', 'oper', 'controller', 'action', 'nocallback'].include?(p)
      campo = p
      valor = v
      break
    }

    @fact = clm.find_by id: params[:id]
    if @fact.nil?
      #render text: nt('errors.messages.record_inex')
      render plain: nt('errors.messages.record_inex')
      return
    end

    set_parent
    fact_clone

    #@fact.method(campo + '=').call(params[:sel] ? params[:sel] : raw_val(campo, valor))
    @fact[campo] = params[:sel] ? params[:sel] : raw_val(campo, valor)

    err = valida_campo(campo, :all)

    if err.nil?
      if params[:nocallback]
        @fact.update_column(campo, valor)
      else
        @fact.save
      end
      render plain: ''
    else
      render plain: err
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'crea_grid(opts)', mark: :rdoc}

  # Método para crear un grid dinámicamente.
  #
  # <b>Parámetros</b>
  #
  # * *opts* (Hash)
  #
  # <b>Opciones Hash (opts):</b>
  #
  # * *:cmp* es un campo definido con <tt>{type: :div}</tt>
  #
  # * *:modo* (Symbol) <em>(Default: :sel)</em> -- Los posibles valores son:
  #   * <b>:sel</b> En este modo no se puede editar, solo seleccionar registros.
  #     El método, además de crear el grid, sincroniza la seleción de fila (o filas si
  #     está a _true_ la opción _multiselect_) con el servidor. En el campo asociado
  #     tendremos siempre disponible el id de la fila seleccionada (o un array de ids
  #     si hay multiselección). Para acceder lo haremos con <tt>@fact.cmp</tt>
  #   * <b>:ed</b> El grid será editable. En este modo se pueden definir
  #     métodos _vali_ y _on_ para cada columna.
  #     La nomenclatura será <tt>vali_cmp_columna</tt> o <tt>on_cmp_columna</tt>.
  #     Ambos métodos recibirán como argumentos el id de la fila y el valor
  #     de la celda correspondiente.
  #
  #     La sincronización con el servidor se realiza reflejando en tiempo real el
  #     estado de cada celda. Para acceder a los datos usaremos <tt>@fact.cmp.data(id, col)</tt>
  #     donde _id_ es el id de la fila y _col_  el nombre de la columna.
  #     Para dar valor a una celda usaremos <tt>@fact.cmpx.data(id, col, val)</tt>
  #     Los argumentos son los mismo que antes, más _val_, que es el valor que queremos
  #     asignar.
  #
  #     Asociados a @fact.cmp tenemos dos métodos más: <tt>@fact.cmp.col(col)</tt> que nos devuelve
  #     el hash de la definición de la columna _col_ y <tt>@fact.cmp.max_id</tt> que nos devuelve
  #     el máximo id usado en la colección de datos. Esto es útil para poder generar nuevos
  #     ids en el caso de insertar nuevas filas.
  #
  #     Para insertar una nueva fila por código, o bien lo hacemos con el valor de retorno
  #     del método new_cmp (que es llamado al pulsar el botón de inertar nueva fila) o,
  #     si queremos insertar filas en otros métodos tendremos que usar el método
  #     <tt>grid_add_row(cmp, pos, data)</tt> donde _cmp_ es el campo, _pos_ es la
  #     posición donde queremos insertar la fila (-1 para insertar por el final) y _data_ es
  #     un array con los valores de fila a insertar.
  #     Igualmente, para borrar una fila por código se puede usar el método <tt>grid_del_row(id)</tt>
  #     donde _id_ es el id de la fila a borrar. Esto sería para borrar filas 'a traición',
  #     las filas que borra el usuario y que se nos notifican en <tt>vali_borra_cmp</tt> se borran
  #     automáticamente (sin necesidad de usar este método) en el caso de que vali_borra_cmp
  #     devuelva nil.
  #
  #     Para barrer los datos habría que hacer:
  #       @fact.cmp.each_row {|fila, new, edit, i|
  #         # 'fila' es un array con los datos de la fila que toque
  #         # 'new' es un booleano que indica si la fila es nueva (insertada)
  #         # 'edit' es un booleano que indica si la fila ha sido editada (alguna de sus celdas)
  #         # 'i' es el índice de la fila (0,1,2...)
  #       }
  #
  #     Y para barrer los registros borrados:
  #       @fact.cmp.each_del {|fila, new, edit, i|
  #         # 'fila' es un array con los datos de la fila que toque
  #         # 'new' es un booleano que indica si la fila es nueva (insertada)
  #         # 'edit' es un booleano que indica si la fila ha sido editada (alguna de sus celdas)
  #         # 'i' es el índice de la fila (0,1,2...)
  #       }
  #
  # * *:sel* (Symbol, nil) <em>(Default: nil)</em> -- Solo válido en modo edición.
  #   Los posibles valores son:
  #   * <b>:row</b> El servidor será notificado al seleccionar una fila.
  #   * <b>:cel</b> El servidor será notificado al seleccionar una celda. Por defecto todas
  #     las celdas dispararán la notificación. Se pueden excluir celdas poniendo en la
  #     definición de su columna "sel: false" o restringir que una celda (columna) sólo
  #     notifique ante un determinado evento. En este caso tendríamos que poner en la
  #     definición de la columna: "sel: '<evento>'" para que sólo se notifique en el evento <evento>.
  #     Por ejemplo: "sel: 'click'" o "sel: 'keydown'".
  #   * <b>:celx</b> El servidor será notificado al seleccionar una celda. Por defecto ninguna
  #     celda disparará la notificación salvo aquellas que lo indiquen explícitamente
  #     en la definición de su columna. Así, "sel: true" en una columna indicará que notifica
  #     su selección ante cualquier evento. Como en el caso anterior, se puede restringir la
  #     notificación sólo a eventos concretos: "sel: '<evento>'".
  #   * <b>nil</b> El servidor no será notificado en ninguna selección.
  #   La notificación se pasará al método <tt>sel_cmp</tt> que recibirá
  #   como argumentos el id de la fila, el nombre de la columna y el evento
  #   que ha provocado la selección. Este último puede valer: "prog" si la
  #   la selección se ha hecho programáticamente, "click" si ha sido por la
  #   pulsación del ratón o por la tecla <ENTER>, "keydown" si ha sido con el teclado, pero
  #   no con <ENTER> (cursores, tabulador, etc.). Si existe el método <tt>sel_</tt>
  #   también será llamado y recibirá como primer argumento el nombre del campo (cmp) y como
  #   argumentos siguientes los mismos que el caso anterior (rowid, col, evento). 
  #
  # * *:del* (Boolean) <em>(Default: true)</em> -- Sólo válido en modo edición. Indica si
  #   se permiten borrar filas. En caso afirmativo antes del borrado se
  #   llamará al método <tt>vali_borra_cmp</tt> que recibirá como argumento el
  #   id de la fila a borrar y retornará una cadena con un error si no se
  #   permite el borrado o nil si se permite. Si no existe el método se
  #   entiende que se permite borrar cualquier fila sin condiciones.
  #
  # * *:ins* (Symbol, nil) <em>(Deafault: :end)</em> -- Sólo válido en modo edición.
  #   Sirve para permitir la inserción de nuevas filas. Los posibles valores son:
  #   * <b>:pos</b> La inserción será posicional (entre dos filas), en este caso no
  #     se permitirá la ordenación por columnas.
  #   * <b>:end</b> La inserción sólo se permitirá al final del grid.
  #   * <b>nil</b> No se permitirá insertar nuevas filas.
  #   Cuando se solicite la inserción de una nueva fila se llamará al método
  #   <tt>new_cmp</tt> y recibirá como argumento la posición física donde se
  #   va a insertar la fila. Como valor de retorno debe devolver un array
  #   con los valores de la fila a insertar. Si no existe el método, la
  #   fila se inertará con todas las celdas vacías y con id igual al
  #   máximo de los existentes más uno (o el siguiente en orden alfabético
  #   si los ids son cadenas).
  #
  # * *:search* (Boolean) <em>(Default: false)</em> -- Indica si aparece o no
  #   por defecto la barra de búsqueda en el grid.
  #
  # * *:bsearch* (Boolean)  <em>(Default: false)</em> -- Indica si aparece o no
  #   un botón para mostrar/ocultar la barra de búsqueda en el grid.
  #
  # * *:bcollapse* (Boolean) <em>(Default: false)</em> -- Indica si aparece o no
  #   un botón para mostrar/ocultar el grid cmpleto.
  #
  # * *:cols* (Array) -- Es un array de hashes conteniendo información de cada columna.
  #   Cada hash admite todas las claves soportadas por jqGrid en
  #   colModel[http://www.trirand.com/jqgridwiki/doku.php?id=wiki:colmodel_options].
  #   Las más importantes, y las añadidas por nimbus son:
  #
  #   * *:name* (String) -- Es el nombre de la columna. Si una columna es de tipo _id_
  #     haciendo referencia a otra tabla, su nombre debe acabar por "_id"
  #     y especificar el nombre del modelo con la clave _:ref_.
  #     Si no se especifica _:ref_ se asumirá como modelo el nombre de la columna
  #     sin el _id_ final capitalizado. Para poner filtros a este tipo de campos
  #     se usará el mismo método que para campos normales (set_auto_comp_filter)
  #     con la salvedad de que como nombre de campo le pasaremos:
  #     cmp_id_columna (siendo _id_ el id de la fila y _columna_ el
  #     nombre de la columna). Por ejemplo en una fila con id=123 y con una
  #     columna llamada pais_id (haciendo referencia a la tabla de países)
  #     usaríamos <tt>set_auto_comp_filter('cmp_123_pais_id', 'el_filtro_que_sea')</tt>
  #   * *:ref* (String) -- Explicada en el apartado anterior. (Sólo válida para campos _id_)
  #   * *:label* (String) -- El título de la columna. Si no existe se usará <em>:name</em>.
  #   * *:type* (Symbol) <em>(Default: :string)</em> -- Es el tipo de dato
  #     (:boolean, :string, :integer, :decimal, :date, :time, :datetime).
  #     Los campos de tipo _id_ no necesitan tipo explícito (no hace falta usar esta clave)
  #   * *:manti* (Integer) <em>(Default: 7)</em> -- Sólo para tipos numéricos. Indica la mantisa.
  #   * *:signo* (Boolean) <em>(Default: false)</em> -- Sólo para tipos numéricos.
  #     Indica si se admiten negativos.
  #   * *:decim* (Integer) <em>(Default: 2)</em> -- Sólo para el type :decimal.
  #     Indica el número de decimales.
  #   * *:align* (String) -- Posibles valores: 'left', 'center', 'right'
  #     Por defecto se adapta al _type_ por lo que no sería necesario
  #     darle valor, salvo que queramos un comportamiento especial.
  #   * *:width* (Integer) <em>(Default: 150)</em> -- Anchura de la columna.
  #   * *:sel* (Boolean, String) -- Indica el comportamiento ante la notificación que
  #     recibirá el servidor al seleccionar una celda de esta columna. Para los detalles,
  #     ver la ayuda de la opción _sel_ del nivel anterior. Sus posibles valores son:
  #     _true_, _false_, 'click', 'keydown', 'prog'. Notar que la pulsación de la
  #     tecla <ENTER> se notificará como evento 'click'.
  #
  #
  # * *:grid* (Hash) -- Opciones específicas para el grid. Admite todas las
  #   referidas en grid_options[http://www.trirand.com/jqgridwiki/doku.php?id=wiki:options].
  #   Las más interesantes serían:
  #   * *:caption* (String) -- Título del grid. Añade una barra
  #     de título y un botón para colapsar el grid.
  #   * *:height* (Integer) <em>(Default: 150)</em> -- Indica la altura del grid.
  #   * *:hidegrid* (Boolean) -- Establece si aparece o no el botón de colapsar.
  #     Sólo válido si hay _:caption_.
  #   * *:multiselect* (Boolean) <em>(Default: false)</em> --  Permite seleccionar múltiples filas.
  #     En este caso se añade al grid una primera columna con
  #     checks para indicar la selección.
  #   * *:multiSort* (Boolean) <em>(Default: false)</em> -- Permite ordenar por varias columnas.
  #   * *:shrinkToFit* (Boolean) <em>(Default: false)</em> -- Si es true, se ajustarán las anchuras
  #     de las columnas para caber en la anchura del grid.
  #
  # * *:data* (Array) -- Es un array de arrays con los datos (puede ser un array simple si sólo
  #   hay una fila de datos). Cada array contendrá n+1 elementos, donde n es
  #   número de columnas que se han definido en _:cols_. El elemento adicional,
  #   que tiene que ser el primero del array, contendrá el id de la fila.
  ##

  def crea_grid(opts)
    cmp = opts[:cmp].to_sym
    return unless cmp

    modo = opts[:modo] ? opts[:modo].to_sym : :sel
    opts[:ins] = :end unless opts.key?(:ins)
    opts[:del] = true if opts[:del].nil?

    opts[:add_prop] ||= []
    opts[:grid] ||= {}

    opts[:cols].each {|c|
      if c[:name].to_s.ends_with?('_id')
        c[:type] = :references
        c[:ref] ||= c[:name][0..-4].capitalize
        opts[:add_prop] << '_' + c[:name]
      end
      c[:searchoptions] ||= {}
      c[:editoptions] ||= {}
      c[:editable] = true if c[:editable].nil?
      c[:sortable] = false if opts[:ins] == :pos
      c[:type] ||= :string
      c[:type] = c[:type].to_sym
      case c[:type]
        when :boolean
          c[:manti] ||= 6
          c[:align] ||= 'center'
          #c[:formatter] ||= 'checkbox'
          c[:formatter] ||= '~format_check~'
          c[:unformat] ||= '~unformat_check~'
          c[:editoptions][:value] ||= 'true:false'
          c[:edittype] ||= 'checkbox'
          c[:searchoptions][:sopt] ||= ['eq']
        when :integer, :decimal
          c[:manti] ||= 7
          c[:decim] ||= (c[:type] == :integer ? 0 : 2)
          c[:signo] = false if c[:signo].nil?
          c[:editoptions][:dataInit] ||= "~function(e){numero(e,#{eval_cad(c[:manti])},#{eval_cad(c[:decim])},#{c[:signo]})}~"
          c[:searchoptions][:dataInit] ||= c[:editoptions][:dataInit]
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','in','ni','nu','nn']
          c[:sortfunc] ||= '~sortNumero~'
          c[:align] ||= 'right'
        when :date
          c[:manti] ||= 10
          c[:sorttype] ||= 'date'
          c[:formatter] ||= 'date'
          c[:editoptions][:dataInit] ||= '~function(e){date_pick(e)}~'
          c[:searchoptions][:dataInit] ||= c[:editoptions][:dataInit]
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          #c[:sortfunc] ||= '~sortDate~'
        when :time
          c[:manti] ||= 8
          c[:editoptions][:dataInit] ||= '~function(e){$(e).entrytime(' + (c[:seg] ? 'true,' : 'false,') + (c[:nil] ? 'true' : 'false') + ')}~'
          c[:searchoptions][:dataInit] ||= c[:editoptions][:dataInit]
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
        when :datetime
          c[:manti] ||= 19
          c[:sorttype] ||= 'date'
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          c[:formatter] = 'date'
          format = "d-m-Y H:i#{c[:seg] ? ':s' : ''}"
          c[:formatoptions] ||= {srcformat: format, newformat: format}
        when :references
          c[:manti] ||= 30
          mt = c[:ref].split('::')
          c[:controller] = (mt.size == 1 ? c[:ref].constantize.table_name : mt[0].downcase + '/' + mt[1].downcase.pluralize)
          #sal << " go='go_#{cs}'" if self.respond_to?('go_' + cs)
          #sal << " new='new_#{cs}'" if self.respond_to?('new_' + cs)
          c[:editoptions] = {dataInit:  "~function(e){autoCompGridLocal(e,'#{c[:ref]}','#{c[:controller]}','#{cmp}','#{c[:name]}');}~"}
          c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
        when :text
          c[:manti] ||= 30
          c[:edittype] ||= 'textarea'
          c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
        when :img
          c[:manti] ||= 8
          c[:sortable] = false if c[:sortable].nil?
          c[:search] = false if c[:search].nil?
          c[:editable] = false
        else
          if c[:sel]
            c[:manti] ||= 6
            c[:formatter] ||= 'select'
            c[:edittype] ||= 'select'
            c[:editoptions][:value] ||= c[:sel]
            c[:align] ||= 'center'
            c[:searchoptions][:sopt] ||= ['eq', 'ne', 'in', 'ni', 'nu', 'nn']
          else
            c[:manti] ||= 30
            c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
          end
      end

      c[:width] ||= 8 * [c[:manti].to_i, (c[:label] || c[:name]).size].max
    }

    data = opts[:data]
    data_grid = []
    if data and data.present?
      data = [data] unless data[0].class == Array
      opts.delete(:data)
      data.each {|r|
        h = {id: r[0]}
        opts[:cols].each_with_index {|c, i|
          h[c[:name]] = _forma_campo(:lgrid, c, c[:name], r[i+1])
          h['_' + c[:name]] = r[i+1] if c[:name].ends_with?('_id')
        }
        data_grid << h
      }
    end

    if opts[:subgrid]
      opts[:subgrid][:cols].each {|c|
        c[:type] ||= :string
        c[:type] = c[:type].to_sym
        case c[:type]
          when :boolean
            c[:manti] ||= 6
            c[:align] ||= 'center'
            c[:formatter] ||= '~format_check~'
            c[:unformat] ||= '~unformat_check~'
          when :integer, :decimal
            c[:manti] ||= 7
            c[:decim] ||= (c[:type] == :integer ? 0 : 2)
            c[:signo] = false if c[:signo].nil?
            c[:sortfunc] ||= '~sortNumero~'
            c[:align] ||= 'right'
          when :date
            c[:manti] ||= 10
            c[:sorttype] ||= 'date'
            c[:formatter] ||= 'date'
          when :time
            c[:manti] ||= 8
          when :datetime
            c[:manti] ||= 19
            c[:sorttype] ||= 'date'
            c[:formatter] = 'date'
            format = "d-m-Y H:i#{c[:seg] ? ':s' : ''}"
            c[:formatoptions] ||= {srcformat: format, newformat: format}
          when :img
            c[:manti] ||= 8
            c[:sortable] = false
          else
            if c[:sel]
              c[:manti] ||= 6
              c[:formatter] ||= 'select'
              c[:align] ||= 'center'
            else
              c[:manti] ||= 30
            end
        end
        c[:width] ||= 8 * [c[:manti].to_i, (c[:label] || c[:name]).size].max
      }

      opts[:subgrid][:data] ||= {}
      sg_data = opts[:subgrid][:data].deep_dup if opts[:export]
      opts[:subgrid][:data].each {|k, v|
        opts[:subgrid][:data][k] = []
        if v && v.present?
          v = [v] unless v[0].class == Array
          v.each {|r|
            h = {id: r[0]}
            opts[:subgrid][:cols].each.with_index(1){|c, i| h[c[:name]] = _forma_campo(:lgrid, c, c[:name], r[i])}
            opts[:subgrid][:data][k] << h
          }
        end
      }
    end

    @ajax_post << "creaGridLocal(#{opts.to_json.gsub('"~', '').gsub('~"', '')}, #{data_grid.to_json});"

    case modo
      when :ed
        @fact[cmp] = HashForGrids.new(opts[:cols], data, opts[:export])
        @fant[cmp] = nil if @fant
      else
        @fact.campos[cmp][:grid_info] = {cols: opts[:cols], data: data, sg_cols: opts.dig(:subgrid, :cols), sg_data: sg_data, export: opts[:export]} if opts[:export]
        @fact.campos[cmp][:grid_sel] = {sgm: (opts[:subgrid] ? (opts.dig(:subgrid, :grid, :multiselect) ? true : false) : nil), gm: opts[:grid][:multiselect]}
        @fact.campos[cmp][:val_ini] = @fact[cmp].deep_dup
        @ajax_post << "setSelectionGridLocal('#{cmp}', #{@fact[cmp].to_json});"
    end
  end

  # Método para añadir filas a un grid existente
  #
  # cmp: Es el campo X sobre el que está creado el grid
  #
  # data: Es un array de arrays con los datos (puede ser un array simple si sólo
  #       hay una fila de datos). Cada array contendrá n+1 elementos, donde n es
  #       número de columnas que se han definido en 'cols'. El elemento adicional,
  #       que tiene que ser el primero del array, contendrá el id de la fila.
  #       Este id es el que se devolverá al campo X en caso de que la fila sea
  #       seleccionada.

  def add_data_grid(cmp, data)
    data = [data] unless data[0].class == Array
    @ajax << "addDataGridLocal('#{cmp}', #{data.to_json});"
  end

  def del_data_grid(cmp, id)
    @ajax << "delDataGridLocal('#{cmp}', #{id});"
    if @fact[cmp]
      if @fact[cmp].is_a?(Array)
        @fact[cmp].delete(id)
        @fact[cmp] = nil if @fact[cmp].empty?
      else
        @fact[cmp] = nil if @fact[cmp] == id
      end
    end
  end

  def grid_local_ed_select
    fun = "sel_"
    if respond_to?(fun)
      case  method(fun).arity
      when 0
        method(fun).call
      when 1
        method(fun).call(params[:cmp])
      when 2
        method(fun).call(params[:cmp], params[:row])
      when 3
        method(fun).call(params[:cmp], params[:row], params[:col])
      else
        method(fun).call(params[:cmp], params[:row], params[:col], params[:event])
      end
    end

    fun = "sel_#{params[:cmp]}"
    if respond_to?(fun)
      case  method(fun).arity
      when 0
        method(fun).call
      when 1
        method(fun).call(params[:row])
      when 2
        method(fun).call(params[:row], params[:col])
      else
        method(fun).call(params[:row], params[:col], params[:event])
      end
    end
  end

  def grid_add_row(cmp, pos, data)
    cmp = cmp.to_sym
    h = {}
    @fact[cmp][:cols].each_with_index {|c, i|
      h[c[:name]] = _forma_campo(:lgrid, c, c[:name], data[i + 1])
      h['_' + c[:name]] = data[i + 1] if c[:name].ends_with?('_id')
    }
    @ajax << "$('#g_#{cmp}').jqGrid('addRowData','#{data[0]}',#{h.to_json}"
    @ajax << ",'before',#{@fact[cmp][:data][pos][0]}" if pos >= 0
    @ajax << ");"

    @ajax << "$('##{cmp} .ui-jqgrid-bdiv').scrollTop(1000000);" if pos == -1

    #@ajax << 'hayCambios=true;'

    @fact[cmp].add_row(pos, data)
    @fant[cmp].add_row(pos, data) if @fant

    # Poner en edición la primera columna editable de la fila recién añadida
    fce = 0
    @fact[cmp][:cols].each_with_index {|c, i|
      if c[:editable]
        fce = i
        break
      end
    }

    @ajax << "$('#g_#{cmp}').jqGrid('editCell',#{pos == -1 ? @fact[cmp][:data].size : pos + 1},#{fce},true);"
  end

  def grid_local_ins
    cmp = params[:cmp].to_sym
    pos = params[:pos].to_i

    fun = "new_#{cmp}"
    if self.respond_to?(fun)
      data = self.method(fun).call(pos)
      return if data.nil? or data.empty?
    else
      data = [@fact[cmp].max_id.next]
    end

    grid_add_row(cmp, pos, data)
  end

  def grid_del_row(cmp, row)
    cmp = cmp.to_sym
    @ajax << "$('#g_#{cmp}').jqGrid('delRowData','#{row}');"
    # Las dos líneas que siguen son para apañar un bug de jqGrid al borrar la ultima línea de datos
    #@ajax << "$('#g_#{cmp}').jqGrid('resetSelection');"
    @ajax << "$('#g_#{cmp}').trigger('reloadGrid', [{current:true}]);"

    #@ajax << 'hayCambios=true;'

    @fact[cmp].del_row(row)
    @fant[cmp].del_row(row) if @fant
  end

  def grid_local_del
    cmp = params[:cmp].to_sym
    row = params[:row]

    fun = "vali_borra_#{cmp}"
    if self.respond_to?(fun)
      res = self.method(fun).call(row)
      if res
        mensaje res
        return
      end
    end
    grid_del_row(params[:cmp], row)
  end

  def grid_local_select
    begin
      campo = params[:cmp]
      sel = (params[:sel] == 'true')
      gs = @fact.campos[campo.to_sym][:grid_sel]
    rescue
      logger.fatal '######## ERROR #############'
      logger.fatal 'grid_local_select: No existe el campo o no tiene asociados datos :grid_sel'
      logger.fatal "Usuario: #{@usu.codigo}" if @usu
      logger.fatal "Parámetros: #{params}"
      return
    end

    if !gs[:gm] && gs[:sgm].nil?
      # No hay subgrid y la selección es single
      @fact[campo] = sel ? params[:row].to_i : nil
    else
      @fact[campo] = [] unless @fact[campo]
      subg = params[:subg] ? params[:subg].to_i : nil
      if params[:row] == ''
        if subg
          # Deseleccionar todos los registros del subgrid
          @fact[campo].delete_if{|c| c.is_a?(Array) && c[0] == subg}
        else
          # Deseleccionar todos los registros del grid padre
          @fact[campo].delete_if{|c| !c.is_a?(Array)}
        end
      elsif params[:row].is_a? Array
        @fact[campo] += params[:row].map{|c| subg ? [subg, c.to_i] : c.to_i}
      else
        row = params[:row].to_i
        if subg
          @fact[campo].delete_if{|c| c.is_a?(Array) && c[0] == subg} unless gs[:sgm]
          row = [subg, params[:row].to_i]
        else
          @fact[campo].delete_if{|c| !c.is_a?(Array)} unless gs[:gm]
          row = params[:row].to_i
        end
        sel ? @fact[campo] << row : @fact[campo].delete(row)
      end
      @fact[campo].uniq!
    end

    @fant[campo.to_sym] = @fact[campo].deep_dup
    fun = "sel_#{campo}"
    self.method(fun).call(params[:row]) if self.respond_to?(fun)
    call_nimbus_hook "on_#{campo}"
  end

  # Método para calcular dos arrays: uno de estilos y otro de tipos
  # Para usar en exportaciones a excel
  # Es llamado en la exportación de grids embebidos (un poco más abajo)
  # y desde el controlador de 'bus'

  def array_estilos_tipos_axlsx(cols, wb)
    lsty = {
      d: wb.styles.add_style({format_code: 'dd-mm-yyyy'}),
      t: wb.styles.add_style({format_code: 'HH:MM:SS'}),
      dt: wb.styles.add_style({format_code: 'dd-mm-yyyy HH:MM:SS'}),
      i: wb.styles.add_style({format_code: '#,##0'})
    }
    sty = []
    typ = []
    cols.each {|c|
      next if c[:hidden]

      case c[:type].to_sym
        when :string
          typ << :string
          sty << nil
        when :date
          typ << :date
          sty << lsty[:d]
        when :time
          typ << :time
          sty << lsty[:t]
        when :datetime
          typ << :time
          sty << lsty[:dt]
        when :integer
          typ << nil
          sty << lsty[:i]
        when :decimal
          typ << nil
          dec = c[:decim] || 2
          lsty[dec] = wb.styles.add_style({format_code: "#,##0.#{'0'*dec}"}) unless lsty[dec]
          sty << lsty[dec]
        else
          typ << nil
          sty << nil
      end
    }

    [sty, typ]
  end

  def grid_local_export
    return unless @v

    ids = params[:ids]
    unless ids
      mensaje 'No hay datos para exportar'
      return
    end

    cmp = params[:cmp].to_sym

    # Depende de si el grid es :ed o :sel los datos están en una clave u otra.
    clv = @fact.campos[cmp][:grid_info] ? :grid_info : :value
    cols = @fact.campos[cmp][clv][:cols]
    data = @fact.campos[cmp][clv][:data]
    nc = cols.size
    if params[:subg] == 'true'
      nc += @fact.campos[cmp][clv][:sg_cols].size
      cols += @fact.campos[cmp][clv][:sg_cols]
      data = []
      @fact.campos[cmp][clv][:data].each {|r|
        sd = @fact.campos[cmp][clv][:sg_data][r[0]]
        sd.present? ? sd.each {|l| data << r + l[1..-1]} : data << r
      }
    end

    xls = Axlsx::Package.new
    wb = xls.workbook
    sh = wb.add_worksheet(:name => "Hoja1")

    sty, typ = array_estilos_tipos_axlsx(cols, wb)

    # Primera fila (Cabecera)
    sh.add_row(cols.select{|v| !v[:hidden]}.map{|v| v[:label] || v[:name]})

    #data.each {|r| sh.add_row(r[1..nc].map.with_index {|d, i| forma_campo_axlsx(cols[i], cols[i][:name], d)}, types: typ, style: sty) if ids.include?(r[0].to_s)}
    data.each {|r|
      next unless ids.include?(r[0].to_s)
      row = []
      r[1..nc].each.with_index {|d, i|
        row << forma_campo_axlsx(cols[i], cols[i][:name], d) unless cols[i][:hidden]
      }
      sh.add_row(row, types: typ, style: sty)
    }

    # Fijar la fila de cabecera para repetir en cada página
    wb.add_defined_name("Hoja1!$1:$1", :local_sheet_id => sh.index, :name => '_xlnm.Print_Titles')

    file_name = "/tmp/nim#{@v.id}.xlsx"
    xls.serialize(file_name)
    @ajax << "window.location.href='/nim_download';"
    flash[:file] = file_name
    flash[:file_cli] = @fact.campos[cmp][clv][:export] + '.xlsx'
    flash[:rm] = true
  end

  def get_fact_from_marshal
    @fact = @dat[:fact]

    # La siguiente línea es muy importante. No sé cuales son los motivos exactos
    # pero es necesaria para que la clase a la que pertenece @fact se inicialice correctamente
    # cuando el request es tratado por un nuevo worker (puma) que no ha usado aún dicha clase.
    # Aunque la clase está cargada (en production todas las clases están cargadas), parece que
    # algo interno no está activado hasta que no se hace un new por primera vez.
    # No es algo habitual (en development o en production con un solo worker no se necesitaría nunca),
    # pero en production, con varios workers en paralelo podrían darse errores aleatorios si no está
    # esta línea. Así que.... NO QUITARLA AUNQUE PAREZCA ESTÚPIDA.
    @fact.class.new
  end

  def fix_formulario
    # Damos el foco al campo que ya lo tenía. Esto es para provocar el evento "focus" (como si
    # entráramos de nuevo a dicho campo) para que se inicialicen los datos oportunos en el caso
    # de que algún "on" haya modificado el valor del campo con el foco
    @ajax << '$(":focus").focus();'

    if @fact && class_mant.mant?
      dirty = false
      @fact.campos.each {|c, v|
        val = @fact[c]
        if val.is_a? HashForGrids
          if val[:data] != val[:data_ini]
            dirty = true
            break
          end
        elsif v[:dirty]
          if v[:type] == :div
            # Se pueden ocasionar falsos positivos si hay subgrids, pero no es importante.
            v1 = val.is_a?(Array) ? val.flatten.sort : [val].compact
            v2 = v[:val_ini].is_a?(Array) ? v[:val_ini].flatten.sort : [v[:val_ini]].compact
            if v1 != v2
              dirty = true
              break
            end
          elsif val != v[:val_ini]
            dirty = true
            break
          end
        end
      }

      @ajax << "hayCambios=#{dirty || @fact.changed?};"
    end
  end

  def validar
    get_fact_from_marshal
    @g = @dat[:persistencia]
    fact_clone

    ini_ajax

    campo = params[:campo] || ''
    cs = @fact.campos[campo.to_sym]
    if cs.nil?
      logger.fatal '######## ERROR #############'
      logger.fatal 'Validar: No existe el campo'
      logger.fatal "Usuario: #{@usu.codigo}" if @usu
      logger.fatal "Parámetros: #{params}"
      head :no_content
      return
    end

    valor = params[:valor]

    # Control por si han intentado hackear un campo 'ro' forzando su habilitación desde la consola web
    if cs[:ro] == :all
      envia_campo campo, @fact[campo]
      render_ajax
      return
    end

    if cs[:img]
      if valor == '*' # Es un borrado de imagen
        @fact[campo] = '*'
        render js: "$('##{campo}_img').attr('src','');"
      else
        # Es una asignación de imagen que viene del submit del form asociado. La respuesta va al iframe asociado al campo imagen
        # Si tiene la clave "firma" entonces no hay frame asociado y la imagen viene codificada en base64 en "valor"

        file_base = "/tmp/nimImg-#{@v.id}-#{campo}"
        token = Time.now.strftime('%d%H%M%S') # Token para añadir al URL de nim_send_file para forzar el envío si se repite la misma imagen (y ha cambiado)
        `rm -f #{file_base}.*`
        if cs[:img][:firma]
          @fact[campo] = "#{file_base}.png"
          File.write(@fact[campo], Base64.decode64(valor[valor.index(',')+1..-1]), mode: 'wb')
          @ajax << %Q($("##{campo}_img").attr("src", "/nim_send_file?file=#{@fact[campo]}&#{token}"))
          render_ajax
        else
          return unless params[campo] # Por si llega un submit sin fichero para upload

          @fact[campo] = "#{file_base}.#{params[campo].tempfile.path.split('.')[-1]}"
          `cp #{params[campo].tempfile.path} #{@fact[campo]}`

          render html: %Q(
            <script>
              $(window).load(function(){$("##{campo}_img",parent.document).attr('src', '/nim_send_file?file=#{@fact[campo]}&#{token}')})
            </script>
          ).html_safe, layout: 'basico'
        end
      end

      @v.save
      return
    end

    if campo.ends_with?('_id') and params[:src] # Autocompletado sin id elegido (probable introducción rápida de texto)
      par = {term: valor}
      CGI::parse(URI::parse(params[:src]).query).each {|k, v| par[k.to_sym] = v[0]}
      res = _auto(par)
      #if res.size == 1  # Se ha encontrado un registro único
      if res.size > 0  # Se ha encontrado algún registro
        valor = res[0][:id]
        @ajax << "$('##{campo}').val(#{res[0][:value].to_json}).attr('dbid',#{valor});"
      else
        valor = ''
        @ajax << "$('##{campo}').val('').attr('dbid',null);"
      end
    end

    if cs[:type] == :upload
      self.method("on_#{campo}").call(params[campo]) if self.respond_to?("on_#{campo}")
      valor = nil
    else
      @fact[campo] = raw_val(campo, valor)
      valor = @fact[campo].dup rescue @fact[campo]
    end

    ## Validación

    err = valida_campo(campo, :all)

    if err.nil?
      @ajax << '$("#' + campo + '").removeClass("ui-state-error");'
    else
      h = {msg: err}
      if @last_error[2]  # Hay que reponer el valor anterior del campo (cuando se cierre el mensaje)
        @fact[campo] = @fant[campo.to_sym]
        h[:js] = envia_campo(campo, @fact[campo], false) + "$('##{campo}').focus()"
      else
        @ajax << '$("#' + campo + '").focus();'
        @ajax << '$("#' + campo + '").addClass("ui-state-error");'
      end
      mensaje h
    end

    if @fact[campo] == valor
      sincro_ficha :ajax => true, :exclude => campo
    else
      sincro_ficha :ajax => true
    end

    fix_formulario

    if cs[:type] == :upload
      # Si el tipo es upload el render se realiza en el iframe asociado y por lo tanto
      # para procesar @ajax hay que que hacerlo en el ámbito de su padre (la ficha)
      render html: %Q(
          <script>
            $(window).load(function(){window.parent.eval(#{(@ajax + @ajax_post).to_json});})
          </script>
        ).html_safe, layout: 'basico'
    else
      render_ajax
    end

    @v.save
  end

  def fon_server
    unless params[:fon] && self.respond_to?(params[:fon])
      head :no_content
      return
    end

    ini_ajax
    if params[:vista]
      @g = @dat[:persistencia]
      if @dat[:fact]
        get_fact_from_marshal
        fact_clone
      end
    end
    method(params[:fon]).call
    sincro_ficha :ajax => true if @fact
    unless performed?
      fix_formulario unless params[:nofix]
      render_ajax
    end

    @v.save if @v && params[:fon] != 'p2p_req'
  end

  def pinta_exception(e, msg=nil)
    logger.fatal '######## ERROR #############'
    logger.fatal "Usu: #{@usu.codigo}" if @usu
    logger.fatal e.message
    (0..10).each{|i| logger.fatal e.backtrace[i]}
    logger.fatal '############################'
    mensaje(msg) if msg
  end

  def borrar
    if @dat[:prm] != 'p'
      head :no_content
      return
    end

    ini_ajax

    get_fact_from_marshal
    @g = @dat[:persistencia]
    err = vali_borra if self.respond_to?('vali_borra')
    if err
      mensaje(err) unless err == '@'
    else
      call_nimbus_hook :before_borra

      @fact.destroy

      if @usu.audit
        Auditoria.create usuario_id: @usu.id, fecha: Nimbus.now, controlador: params[:controller], accion: 'B', rid: @fact.id
      end

      # Borrar los datos asociados
      `rm -rf #{Nimbus::DataPath}/#{class_modelo}/#{@fact.id}`

      call_nimbus_hook :after_borra

      grid_reload
      @ajax << 'hayCambios=false;'
      #@ajax << "window.location.replace('/' + _controlador + '/0/edit?head=#{@dat[:head]}');"
      @ajax << 'if(parent == self){window.close();location.replace("about:blank")}else parent.editInForm(0);'
    end

    render_ajax
    @v.save
  end

  def reponer_dirty
    @fact.campos.each {|c, v|
      val = @fact[c]
      if val.is_a? HashForGrids
        val[:data_ini] = val[:data].deep_dup
      elsif val.is_a? Array # Es el caso de los grid de selección
        v[:val_ini] = val.deep_dup if v[:dirty]
      else
        v[:val_ini] = val if v[:dirty]
      end
    }
    @ajax << 'hayCambios=false;'
  end

  def grabar(ajx = true)
    if @dat[:prm] == 'c'
      head :no_content
      return
    end

    if ajx
      get_fact_from_marshal
      @g = @dat[:persistencia]
      fact_clone
      ini_ajax
    end

    clm = class_mant
    err = ''
    last_c = nil

    begin
      cmps_img = [] # Crear un vector con los campos de imagen modificados
      @fact.campos.each {|cs, v|
        c = cs.to_s

        cmps_img << cs if v[:img] && @fact[c]

        valor = @fact[c]
        if v[:type] == :div && valor.is_a?(HashForGrids)
          e = nil
          valor[:data].each {|r|
            valor[:cols].each_with_index {|col, i|
              fun = "vali_#{c}_#{col[:name]}"
              er, t = procesa_vali(method(fun).call(r[0], r[i+1])) if self.respond_to?(fun)
              err << '<br>' + er if t == :duro
            }
          }
        else
          if v[:req]
            #valor = @fact[c]
            #(valor.nil? or ([:string, :text].include?(v[:type]) and not c.ends_with?('_id') and valor.strip == '')) ? e = "Campo #{nt(v[:label])} requerido" : e = nil
            e = @fact[c].blank? ? "Campo #{nt(v[:label])} requerido" : nil
          else
            e = nil
          end
          e = valida_campo(c, :duro) unless e
        end

        if e != nil
          err << '<br>' + e
          @ajax << '$("#' + c + '").addClass("ui-state-error");' if v[:form]
          last_c = c
        end
      }

      if err == ''
        # Asignar los campos "rich"
        if params[:rich]
          params[:rich].each {|k, v| @fact[k.to_sym] = v if @fact.campos.has_key?(k.to_sym)}
        end

        err = vali_save if self.respond_to?('vali_save')
        err ||= ''
      end

      if err == ''
        call_nimbus_hook :before_save

        @fact.save if @fact.respond_to?('save') # El if es por los 'procs' (que no tienen modelo subyacente)

        if @usu.audit
          Auditoria.create usuario_id: @usu.id, fecha: Nimbus.now, controlador: @dat[:audit_ctrl], accion: 'G', rid: (clm.mant? ? @fact.id : nil)
        end

        # Tratar campos imagen
        if clm.mant?
          clmod = class_modelo.to_s
          cmps_img.each {|c|
            path = "#{Nimbus::DataPath}/#{clmod}/#{@fact.id}/_imgs"

            # Borrar imágenes previas
            `rm -f #{path}/#{c}.*`

            unless @fact[c] == '*' # el valor asterisco es borrar la imagen, cosa que se ha hecho en la línea anterior
              ia = @fact[c].split('.')
              FileUtils.mkdir_p(path)
              `mv #{@fact[c]} #{path}/#{c}.#{ia[1]}`
            end

            @fact[c] = nil
          }

          reponer_dirty

          #Refrescar el grid si procede
          grid_reload

          if @dat[:grabar_y_alta] == true || params[:_new] || @dat[:grabar_y_alta] == :new && @fant[:id].nil? # Entrar en una ficha nueva después de grabar
            @ajax << "parent.newFicha(#{@fact.id});"
          else
            if @fant[:id].nil?
              # Bloquear el registro si procede
              add_nim_lock if clm.nim_lock
              #Actualizar id para el acceso al histórico
              @ajax << "_factId=#{@fact.id};"

              sincro_hijos
            end

            #Activar botones necesarios (Grabar/Borrar)
            #@ajax << 'statusBotones({borrar: true});'
            status_botones borrar: true, osp: true
          end
        end

        begin
          call_nimbus_hook :after_save
        rescue Exception => e
          pinta_exception(e, 'Error: after_save')
        end
      else
        # Si la cadena de error vale '@' No se pinta nada (y además no se ha grabado el registro). Es un convenio para vali_save
        unless err == '@'
          @ajax << '$("#' + last_c + '").focus();' if last_c
          mensaje tit: nt('errores_en_el_registro'), msg: err
        end
      end
    rescue ActiveRecord::RecordNotUnique
      mensaje 'Grabación cancelada. Ya existe la clave'
    rescue Exception => e
      pinta_exception(e, 'Error interno')
    end

    if ajx
      sincro_ficha :ajax => true
      @v.save
      render_ajax
    end
  end

  # Método para hacer una grabación de @fact manual y con las acciones oportunas
  def grabar_manual
    id = @fact.id
    @fact.save
    sincro_hijos unless id
    grid_reload
    #@ajax << 'statusBotones({borrar: true});'
    status_botones borrar: true, osp: true
    reponer_dirty
  end

  def add_nim_lock
    b = Bloqueo.create controlador: params[:controller], ctrlid: @fact.id, empre_id: @dat[:eid], clave: forma_campo_id(class_modelo, @fact.id, :lock), idindex: @dat[:idindex], created_by_id: @usu.id, created_at: Nimbus.now
    @ajax << "_nimlock=#{b.id};"
  end

  # Método para destruir una vista cuando se abandona la página

  def destroy_vista
    #Vista.where('id in (?)', params[:vista]).delete_all
    Vista.where(id: params[:vista]).delete_all

    # Borrar todas las imágenes temporales que queden
    `rm -f /tmp/nimImg-#{params[:vista]}-*`

    # Eliminar bloqueos si procede
    if params[:nimlock]
      #Bloqueo.where('id in (?)', params[:nimlock]).delete_all
      Bloqueo.transaction {
        blq = Bloqueo.lock.find_by(id: params[:nimlock])
        if blq
          if blq.activo
            blq.activo = false
            blq.save
          else
            blq.destroy
          end
        end
      }
    end

    head :no_content
  end

  def bus_call
    get_fact_from_marshal

    cmp = (params[:cmpid] ? params[:cmpid] : params[:id]).to_sym
    if params[:cmp] # Casos de campos (columnas) de grids editables
      v = @fact[params[:cmp]].col(params[:col])
    else  # Casos de campos normales de mantenimientos
      v = @fact.campos[cmp]
    end

    flash[:mod] = v[:ref].to_s
    flash[:ctr] = params[:controller]
    flash[:ctr] += "_#{params[:col]}" if params[:col]
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    #flash[:wh] = @dat[:auto_comp][cmp] if @dat[:auto_comp] and @dat[:auto_comp][cmp]
    flash[:wh] = "##{@v.id}##{cmp}" if @dat[:auto_comp] and @dat[:auto_comp][cmp]
    flash[:pref] = v[:bus] if v[:bus]
    flash[:rld] = v[:rld] if v[:rld]
    msel = v[:ref].constantize.auto_comp_mselect
    flash[:msel] = msel if msel != ['*']

    @ajax << 'var w = window.open("/bus", "_blank", "width=700, height=500"); w._autoCompField = bus_input_selected;'
  end

  def bus_call_pk
    clm = class_mant
    clmod = class_modelo
    flash[:mod] = clmod.to_s
    flash[:ctr] = params[:controller]
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    #flash[:wh] = @dat[:auto_comp][:_pk_input] if @dat[:auto_comp] and @dat[:auto_comp][:_pk_input]
    flash[:wh] = "##{@v.id}#_pk_input" if @dat[:auto_comp] and @dat[:auto_comp][:_pk_input]
    msel = clmod.auto_comp_mselect
    flash[:msel] = msel if msel != ['*']
    permanente = self.respond_to?(:busqueda_global_permanente) ? busqueda_global_permanente : false
    flash[:tipo] = 'mant' + (permanente ? '*' : '')
    flash[:pref] = clm.nim_bus_plantilla if clm.nim_bus_plantilla
    flash[:rld] = clm.nim_bus_rld if clm.nim_bus_rld

    #@ajax << 'var w = window.open("/bus", "_blank", "width=700, height=500"); w._autoCompField = "mant";'
    @ajax << 'openWinBus();'
  end

  # Métodos para el manejo de la cuota de disco

  def nimbus_table_cuota(cuota, usado)
    '<table>' +
    "<tr><td>Cuota de disco total:</td><td style='padding-left: 10px;text-align: right'>#{number_to_human_size(cuota)}</td</tr>" +
    "<tr><td></td></tr>" +
    "<tr><td>Cuota de disco usada:</td><td style='padding-left: 10px;text-align: right'>#{number_to_human_size(usado)}</td</tr>" +
    "<tr><td></td></tr>" +
    "<tr><td>Cuota de disco libre:</td><td style='padding-left: 10px;text-align: right'>#{number_to_human_size(cuota - usado)}</td</tr>" +
    "<tr><td></td></tr>" +
    "<tr><td>% de ocupación:</td><td style='padding-left: 10px;text-align: right'>#{number_with_precision(usado.to_f/cuota*100, separator: ',', precision: 1)}%</td</tr>" +
    "</table>"
  end

  def nimbus_cuota_disco
    @mensaje = {
      tit: 'Situación de la ocupación en disco',
      msg: Nimbus::Config[:cuota_disco] ? nimbus_table_cuota(Nimbus::Config[:cuota_disco], `du -bs #{Nimbus::DataPath}`.to_i) : 'No hay restricciones de uso'
    }
    render html: '', layout: 'mensaje'
  end

  def nimbus_upload_check
    tam = params[:tam].to_i
    cuota = Nimbus::Config[:cuota_disco]
    usado = `du -bs #{Nimbus::DataPath}`.to_i
    if cuota && tam + usado > cuota
      @ajax << "nimbusUploadStatus=1;"
      mensaje "Está intentando subir archivos con un tamaño de #{number_to_human_size(tam)}.<br>" +
              "Con eso se superaría la cuota de disco que tiene asignada.<hr>" +
              "La situación actual es la siguiente:<br><br>" +
              nimbus_table_cuota(cuota, usado) +
              "<hr>Considere subir menos archivos o más pequeños."
    else
      @ajax << "nimbusUploadStatus=0;"
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'nimbus_cuota_check(tam)', mark: :rdoc}
  #
  # Devuelve _true_ o _false_ en función de si el tamaño _tam_ (en bytes) cabe o no 
  # en el disco teniedo en cuenta la cuota asignada a la gestión/cliente.
  #
  ##
  def nimbus_cuota_check(tam)
    cuota = Nimbus::Config[:cuota_disco]
    usado = `du -bs #{Nimbus::DataPath}`.to_i
    (cuota && tam + usado > cuota) ? false : true
  end

  def nimbusd(met, par)
    @ajax << "nimbusd('#{met}',#{par.to_json});"
  end

  def gen_form(h={})
    clm = class_mant

    sal = ''
    prim = true
    tab_dlg = h[:tab] ? :tab : :dlg

    @fact.campos.each{|c, v|
      cs = c.to_s
      next if v[tab_dlg].nil? or v[tab_dlg] != h[tab_dlg] or !v[:visible]

      ro = v[:ro]
      manti = v[:manti]
      decim = v[:decim]
      if v[:size]
        size = v[:size].to_s
      elsif v[:type] == :integer or v[:type] == :decimal
        size = (manti + decim + manti/3 + 1).to_s
      else
        size = manti.to_s
      end
      manti = manti.to_s

      plus = ''
      if ro == :all or ro == params[:action].to_sym or v[:rol] == :origen
        if cs.ends_with?('_id') or v[:rol]
          plus << ' readonly tabindex=-1'
        else
          plus << ' disabled'
        end
      end

      plus << " title='#{nt(v[:title])}'" if v[:title] and ![:boolean, :upload].include?(v[:type])
      plus << " #{v[:attr]}" if v[:attr]

      sal << '</div>' unless prim or v[:span] # Cerrar el div mdl-cell si procede

      sal << '</div>' if !prim && !v[:span] && (v[:hr] || v[:br]) # Cerrar el div mdl-grid si procede

      if v[:hr]
        case v[:hr].class.to_s
          when 'String'
            sal << "<div id='hr-#{c}' class='nim-hr-div'><label class='nim-hr-label'>#{nt(v[:hr])}</label><hr></div>"
          when 'Hash'
            sal << "<div id='hr-#{c}' class='#{v[:hr][:class_div] ? v[:hr][:class_div] : 'nim-hr-div'}'><label class='#{v[:hr][:class_label] ? v[:hr][:class_label] : 'nim-hr-label'}'>#{nt(v[:hr][:label])}</label><hr></div>"
          else
            sal << "<hr id='hr-#{c}'>"
        end
      end

      sal << '<div class="mdl-grid">' if prim || !v[:span] && (v[:hr] || v[:br])
      sal << '<br>' if v[:span] and v[:inline] and v[:br]

      # La clase nim-grupo sólo es a efectos de poder seleccionar todos estos elementos (no afecta al estilo)
      # Las clases nim-group, nim-group-span, nim-group-inline y nim-group-span-inline son las que definen el estilo
      div_attr = 'class="nim-grupo nim-group'
      div_attr << '-span' if v[:span]
      div_attr << '-inline' if v[:inline]
      div_attr << ' nim-datetime' if v[:type] == :datetime
      div_attr << '"'
      if v[:pw] || v[:ml]
        div_attr << ' style="'
        div_attr << "width: #{v[:pw]}%;" if v[:pw]
        # El margen izquierdo (ml) lo imitamos con el borde izquierdo en blanco
        # porque si usamos margin-left el div ocuparía más y los % (pw) no cuadrarían (el último elemento del inline se bajaría de fila)
        div_attr << "border-left-style: solid;border-left-color: white;border-left-width: #{v[:ml]}px" if v[:ml]
        div_attr << '"'
      end

      if prim or !v[:span]
        sal << (v[:gcols] == 0 ? '<div style="display: none">' : "<div class='mdl-cell mdl-cell--#{v[:gcols]}-col #{v[:class]}' #{v[:cell_attr]}>")
      end

      prim = false

      if v[:type] == :boolean
        sal << "<div #{div_attr} title='#{nt(v[:title])}'>"
        sal << '<label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect" for="' + cs + '">'
        sal << '<input id="' + cs + '" type="checkbox" class="mdl-checkbox__input" onchange="vali_check($(this))"' + plus + '/>'
        sal << '<span class="mdl-checkbox__label">' + nt(v[:label]) + '</span>'
        sal << '</label>'
        sal << '</div>'
      elsif v[:type] == :text
        if v[:rich]
          sty = v[:rich].is_a?(Hash) && v[:rich][:height] ? " style='height:#{v[:rich][:height]}px'" : ''
          sal << "<label class='nim-label-rich'>#{nt(v[:label])}</label><div id='#{cs}' class='nq-contenedor-style'#{sty}></div>"
        else
          sal << '<div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">'
          sal << '<textarea class="nim-textarea mdl-textfield__input" type="text" id="' + cs + '" cols=' + size + ' rows=' + v[:rows].to_s + ' onchange="validar($(this))"' + plus + '>'
          sal << '</textarea>'
          sal << '<label class="mdl-textfield__label">' + nt(v[:label]) + '</label>'
          sal << '</div>'
        end
      elsif v[:code]
        sal << "<div #{div_attr}>"
        sal << '<input class="nim-input" id="' + cs + '" maxlength=' + size + ' onchange="vali_code($(this),' + manti + ',\'' + v[:code][:prefijo] + '\',\'' + v[:code][:relleno] + '\')" required style="max-width: ' + size + 'em"' + plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif v[:sel]
        sal << "<div #{div_attr}>"
        sal << '<select class="nim-select" id="' + cs + '" required onchange="validar($(this))"' + plus + '>'
        v[:sel].each{|k, tex|
          sal << '<option value="' + k.to_s + '">' + nt(tex) + '</option>'
        }
        sal << '</select>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif cs.ends_with?('_id')
        sal << "<div #{div_attr}>"
        sal << '<input class="nim-input" id="' + cs + '" required style="max-width: ' + size + 'em"'
        sal << ' menu="N"' if v.include?(:menu) and !v[:menu]
        sal << ' dialogo="' + h[:dlg] + '"' if h[:dlg]
        sal << " go='go_#{cs}'" if self.respond_to?('go_' + cs)
        sal << " new='new_#{cs}'" if self.respond_to?('new_' + cs)
        sal << plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif v[:type] == :div
        if v[:div]
          if v[:div][:tit]
            sal << "<div id='#{cs}' style='padding: 3px;background-color: var(--color-1);color: var(--color-1_f);text-align: #{v[:div][:ali] || :center}'>"
            tit = v[:div][:may] ? nt(v[:div][:tit]).upcase : nt(v[:div][:tit])
            sal << tit.html_safe
          end
        else
          sal << "<div id='#{cs}' style='overflow: auto'>"
          clm.hijos.each_with_index {|hijo, i|
            if hijo[:tab].to_s == cs
              sal << "<iframe id='hijo_#{i}' height='#{hijo[:height] ? hijo[:height] : 'auto'}'></iframe>"
              break
            end
          }
        end
        sal << '</div>'
      elsif v[:img] && @v   # Si no hay @v es la edición de una ficha histórica (edith)
        if clm.mant? && @fact.id == 0
          imagen = ''
        elsif self.respond_to?(c)
          plus << ' disabled' unless plus.include?(' disabled')
          imagen = method(c).call.to_s
        else
          imagen = nim_image(tag: c, hid: "#{cs}_img", w: v[:img][:w] || v[:img][:width], h: v[:img][:h] || v[:img][:height])
        end
        if v[:img][:firma]
          sal << "<div id='#{cs}' style='text-align: left;overflow: auto' onclick='nimFirma(this)'>"
          sal << "<label class='nim-label-img'>#{nt(v[:label])}</label><br>"
          sal << imagen
          sal << '</div>'
        else
          sal << '<div style="text-align: left;overflow: auto">'
          sal << view_context.form_tag("/#{params[:controller]}/validar?vista=#{@v.id}&campo=#{cs}", multipart: true, target: "#{cs}_iframe")
          sal << "<input id='#{cs}' name='#{cs}' type='file' accept='image/*' class='nim-input-img' #{plus}/>"
          sal << "<label class='nim-label-img' for='#{cs}'>#{nt(v[:label])}</label><br>"
          sal << imagen
          sal << '</form>'
          sal << "<iframe name='#{cs}_iframe' style='display: none'></iframe>"
          sal << '</div>'
        end
      elsif v[:type] == :upload
        if @v && (!clm.mant? || @fact.id != 0)
          sal << "<div title='#{nt(v[:title])}'>"
          sal << view_context.form_tag("/#{params[:controller]}/validar?vista=#{@v.id}&campo=#{cs}", multipart: true, target: "#{cs}_iframe")
          sal << "<input id='#{cs}_input' name='#{cs + (v[:multi] ? '[]' : '')}' #{v[:multi] ? 'multiple' : ''} type='file' class='nim-input-img' #{plus}/>"
          sal << "<label id='#{cs}' class='nim-label-upload' for='#{cs}_input'>#{nt(v[:label])}</label><br>"
          sal << '</form>'
          sal << "<iframe name='#{cs}_iframe' style='display: none'></iframe>"
          sal << '</div>'
        end
      elsif v[:type] == :datetime
        sal << "<div id='#{cs}' #{div_attr}>"
        sal << '<div style="display: inline-block">'
        sal << '<input class="nim-input" id="_f_' + cs + '" autocomplete="off" required style="max-width: ' + size + 'em"'
        sal << plus + '/>'
        sal << '<label class="nim-label" for="_f_' + cs + '">' + nt(v[:label]) + '</label>'
        sal << '</div>'
        sal << '<div style="display: inline-block">'
        sal << '<input class="nim-input" id="_h_' + cs + '" required style="max-width: 5em"'
        sal << plus + '/>'
        sal << '<label class="nim-label" for="_h_' + cs + '"></label>'
        sal << '</div>'
        sal << '</div>'
      else
        clase = 'nim-input'
        if v[:rol]
          clase << ' nim-rol'
          if v[:rol].is_a? Hash
            plus << ' rol="custom"'
            plus << " rol-icon='#{v[:rol][:icon]}'"
            plus << " rol-title='#{v[:rol][:title]}'"
            plus << " rol-accion='#{v[:rol][:accion]}'"
          else
            plus << " rol='#{v[:rol]}'"
            if v[:rol] == :map
              v[:map] ||= cs
              plus << " map='nim-map-#{v[:map]}'"
            end
          end
        end
        clase << " nim-map-#{v[:map]}" if v[:map]
        clase << ' nim-may' if v[:may]

        sal << "<div #{div_attr}>"
        sal << '<input class="' + clase + '" id="' + cs + '" required onchange="validar($(this))" style="max-width: ' + size + 'em"'
        sal << " maxlength=#{size}" if v[:type] == :string
        sal << ' autocomplete="off"'
        sal << plus + '/>'
        sal << '<label class="nim-label" for="' + cs + '">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      end
    }
    sal << '</div>' if sal != ''   # Fin de <div class="mdl-cell">
    sal << '</div>' if sal != ''   # Fin de <div class="mdl-grid">

    sal.html_safe
  end

  def gen_js
    # return unless @v  # Si no hay vista no generar nada (históricos)

    clm = class_mant
    sal = ''

    if clm.mant? and @fact.id == 0
      sal << '$(":input").attr("disabled", true);'
      sal << '$("#_d-input-pk_").css("display", "block");'
      sal << '$("#_input-pk_").attr("disabled", false);'
      return sal.html_safe
    end

    @fact.campos.each{|c, v|
      next unless v[:form] && v[:visible]

      if block_given?
        plus = yield(c)
      else
        plus = ''
      end

      next if plus == 'stop'

      cs = c.to_s
      if cs.ends_with?('_id')
        sal << 'auto_comp("#' + cs + '","/application/auto?mod=' + v[:ref]
        sal << '&type=' + v[:auto_tipo].to_s if v[:auto_tipo]
        sal << '&eid=' + @e.id.to_s if @e
        sal << '&jid=' + @j.id.to_s if @j
        sal << '&vista=' + @v.id.to_s if @v
        sal << '&cmp=' + cs
        sal << '","' + v[:ref]
        mt = v[:ref].split('::')
        sal << '","' + (mt.size == 1 ? v[:ref].constantize.table_name : mt[0].downcase + '/' + mt[1].downcase.pluralize) + '");'
        sal << "$('##{cs}').data('menu', #{v[:menu].to_json});" if v[:menu].present?
      elsif v[:img] && @v
        sal << "#{cs}.addEventListener('change', nimbusUpload);"
      elsif v[:type] == :text && v[:rich]
        sal << "nimQuill('#{cs}');$('##{cs}').resizable({handles: 's'});"
      elsif v[:type] == :upload
        sal << "#{cs}_input.addEventListener('change', nimbusUpload);"
      elsif v[:mask]
        #sal << '$("#' + cs + '").mask("' + v[:mask] + '",{placeholder: " "});'
        sal << '$("#' + cs + '").mask("' + v[:mask] + '");'
      elsif v[:type] == :date
        sal << 'date_pick("#' + cs + '",' + v[:date_opts].to_json + ');'
        sal << "$('##{cs}').datepicker('disable');" if v[:ro] == :all or v[:ro] == params[:action].to_sym
      elsif v[:type] == :time
        sal << '$("#' + cs + '").entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true);' : 'false);')
      elsif v[:type] == :datetime
        sal << 'date_pick("#_f_' + cs + '",' + v[:date_opts].to_json + ');'
        sal << "$('#_f_#{cs}').datepicker('disable');" if v[:ro] == :all or v[:ro] == params[:action].to_sym
        sal << '$("#_h_' + cs + '").entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true);' : 'false);')
      elsif (v[:type] == :integer || v[:type] == :decimal) && !v[:sel]
        sal << "numero('##{cs}',#{v[:manti]},#{v[:decim]},#{v[:signo]},#{v[:nil]});"
      end
    }

    sal.html_safe
  end

  helper_method :gen_form
  helper_method :gen_js
  helper_method :nim_path_image
end
