# Poner i18n por defecto

I18n.config.enforce_available_locales = false
I18n.default_locale = :es

# A partir de Rails 5.1 la configuración por defecto será la que está comentada
# La otra es para que el comportamiento sea como antes

#Rails.application.config.active_record.time_zone_aware_types = [:datetime, :time]
Rails.application.config.active_record.time_zone_aware_types = [:datetime]


# Nombre de la cookie de sesión (sobreescribe el de config/initializers/session_store.rb)
Rails.application.config.session_store :cookie_store, key: '_' + Rails.app_class.to_s.split(':')[0].downcase + '_session'
# Formato SQL para el schema
Rails.application.config.active_record.schema_format = :sql

# Nuevo formato de fecha

Date::DATE_FORMATS[:sp] = '%d-%m-%Y'

module Nimbus
  # Constante global para activar/desactivar mensajes de debug
  Debug = false

  # Nombre de la cookie de empresa/ejercicio
  CookieEmEj = ('_' + Rails.app_class.to_s.split(':')[0].downcase + '_emej').to_sym

  # Cálculo de los módulos 'puros' disponibles
  Modulos = Dir.glob('modulos/*').select{|m| m != 'modulos/idiomas' and m != 'modulos/nimbus-core'} + ['.']

  def self.load_adds(fi)
    f = fi.split('/')
    iapp = f.index('app')
    fic = '/' + f[iapp..-1].join('/')[0..-4] + '_add.rb'
    rails_root = Rails.root.to_s
    Modulos.each {|m|
      p = rails_root + '/' + m + fic
      if File.exists? p
        Rails.env == 'development' ? require_dependency(p) : load(p)
      end
    }

    # Tratamientos especiales en el caso de que sea un controlador

    if f[iapp + 1] == 'controllers'
      # Cálculo de las vistas

      ctr_name = f[-1][0..f[-1].index('_controller')-1]
      mod = f[-2] == 'controllers' ? '' : f[-2]
      ctr = ((mod == '' ? '' : mod.capitalize + '::') + ctr_name.capitalize + 'Controller').constantize

      def self.procesa_vistas(tipo, rails_root, f, iapp, ctr_name, ctr, mod)
        views = []
        ruta = "/app/views/#{mod}/#{ctr_name}/#{tipo}.html.erb"

        fic = f[0..iapp-1].join('/') + '/' + ruta
        views << fic if File.exists?(fic)

        Modulos.each {|m|
          next if m == f[iapp-2] + '/' + f[iapp-1]
          fic = rails_root + '/' + m + ruta
          views << fic if File.exists?(fic)
        }

        ctr.set_nimbus_views tipo, views
      end

      procesa_vistas(:ficha, rails_root, f, iapp, ctr_name, ctr, mod)
      procesa_vistas(:grid, rails_root, f, iapp, ctr_name, ctr, mod)

      # Reordenamiento del hash de campos (@campos) para posicionar los tags 'post'
      begin
        ctr_mod = ((mod == '' ? '' : mod.capitalize + '::') + ctr_name.capitalize + 'Mod').constantize
        cmpa = []
        post = false
        ctr_mod.campos.each {|k, v|
          if v[:post]
            post = true
          else
            cmpa << [k, v]
          end
        }

        if post
          ctr_mod.campos.each {|k, v|
            if v[:post]
              i = cmpa.index {|c| c[0] == v[:post].to_sym}
              i ? cmpa.insert(i+1, [k, v]) : cmpa << [k, v]
            end
          }
          ctr_mod.campos = cmpa.to_h
        end
      rescue
      end
    end
  end

  # Array con los parámetros de los campos de un mantenimiento que necesitan doble eval (integer, boolean, symbol)
  ParamsDobleEval = [:manti, :decim, :visible, :ro]

  def self.contexto(hsh, cntxt)
    hsh.each {|k, v|
      # parámetros de tipo integer, sym y booleanos (necesitan doble eval)
      ParamsDobleEval.each {|p|
        v[p] = eval(nim_eval(v[p], cntxt)) if v[p].is_a?(String)
      }

      # parámetros de tipo string
      [:mask].each {|p|
        v[p] = nim_eval(v[p], cntxt) if v[p]
      }

      #Parámetros anidados
      if v[:code]
        [:prefijo, :relleno].each {|p|
          v[:code][p] = nim_eval(v[:code][p], cntxt)
        }
      end
    }
  end
end

#Cambiar inflections por defecto a español

class String
  alias :pluralize_org :pluralize
  alias :singularize_org :singularize

  def pluralize(l=:es)
    pluralize_org(l)
  end

  def singularize(l=:es)
    singularize_org(l)
  end

  # Método para proporcionar el modelo asociado a un nombre de table (con posible módulo)
  def model
    sp = self.split('_')
    mod = sp.size > 1 ? sp[0].capitalize + '::' : ''
    (mod + sp[-1].singularize.capitalize).constantize
  end
end

# Método para traducir personalizado
def nt(tex, h={})
  return('') if tex.nil? or tex == ''

  begin
    r = I18n.t(tex, h)
    if r.start_with?('translation missing')
      r = I18n.t(tex.downcase, h)
      if r.start_with?('translation missing')
        if tex[-1] == 's'
          r = I18n.t(tex.singularize, h).pluralize(I18n.locale)
        elsif tex.ends_with?('_id')
          r = I18n.t(tex[0..-4], h)
        end
      end
    end

    return((Nimbus::Debug ? '#' : '') + tex.humanize) if r.start_with?('translation missing')
    r[0] == '#' ? r[1..-1] : r
  rescue
    return '####'
  end
end

# Método para evaluar cadenas literales como si fueran de dobles comillas (con #{} en su interior) dentro de un contexto (binding)
def nim_eval(cad, cntxt)
  cad.is_a?(String) ? eval('%~' + cad.gsub('~', '\~') + '~', cntxt) : cad
end

# Método para ejecutar sentencias SQL (abreviado)

def sql_exe(cad)
  ActiveRecord::Base.connection.execute(cad)
end

# Método para generar left joins. Recibe como argumentos el modelo
# y un número variable (o un array) de campos de la forma
# [tabla[.tabla[...]]] (ej.: cliente.pais)
# cada tabla intermedia puede ir seguida de un valor para el alias
# entre paréntesis. ej.: cliente(cli).pais(p)
# Si no especifican alias se usarán unos automáticos de la forma
# 'ta', 'tb', 'tc'... (saltándose 'to' por ser una palabra reservada de postgreSQL)
# devuelve un hash con dos claves:
# ':cad' que es una cadena ya construida con los joins y
# ':tab' que es otro hash cuyas claves son las tablas usadas en el
# join y los valores de los alias utilizados

def ljoin_parse(modelo, *columns)
  cad_join = ''
  tab_proc = {}
  ali_auto = 'sz' # Para que el primer alias automático sea 'ta'
  columns.flatten.compact.each {|col|
    mod = modelo
    ali = mod.table_name
    tab_ex = ''
    col.to_s.split('.').each {|tab|
      ali_ant = ali
      ip = tab.index('(')
      if ip
        ali = tab[ip+1..tab.index(')')-1]
        tab = tab[0..ip-1]
      end
      mod = mod.reflect_on_association(tab).klass
      tab_ex << '.' unless tab_ex.empty?
      tab_ex << tab
      if tab_proc.include?(tab_ex)
        ali = tab_proc[tab_ex]
        next
      end

      unless ip
        # Para saltarse el alias 'to' que no vale por ser una palabra reservada de postgreSQL
        if ali_auto == 'tn'
          ali_auto = 'tp'
          ali = 'tp'
        else
          ali = ali_auto.next!.dup
        end
      end

      cad_join << ' LEFT JOIN ' + mod.table_name + ' ' + ali + ' ON ' + ali + '.id=' + ali_ant + '.' + tab + '_id'

      tab_proc[tab_ex] = ali
    }
  }

  {cad: cad_join, alias: tab_proc}
end

# Método para generar select de múltiples tablas con sus left join correspondientes

def mselect_parse(modelo, *columns)
  tn = modelo.table_name
  cols = columns.flatten.compact
  ljp = ljoin_parse(modelo, cols.map {|col| col.split('.')[0..-2].join('.')})
  cad_sel = ''
  tab_alias = {}
  cols.each {|col|
    sp = col.split('.')
    tab = sp[0..-2].map{|t| t.gsub(/\(.*\)/, '')}.join('.')
    cad_sel << ',' unless cad_sel.empty?
    if tab.empty?
      cmp_db = tn + '.' + sp[-1]
    else
      cmp_db = ljp[:alias][tab] + '.' + sp[-1] + (sp[-1].include?(' ') ? '' : ' ' + ljp[:alias][tab] + '_' + sp[-1])
    end
    cad_sel << cmp_db
    cmp_db_s = cmp_db.split(' ')
    cmp_puro = sp[-1].split(' ')[0]
    tab_alias[(tab.empty? ? '' : tab + '.') + cmp_puro] = {cmp_db: cmp_db_s[0], alias: cmp_db_s.size > 1 ? cmp_db_s[1] : cmp_puro}
  }
  {cad_sel: cad_sel, cad_join: ljp[:cad], alias_tab: ljp[:alias], alias_cmp: tab_alias}
end

# Extensiones a ActiveRecord::Base

class ActiveRecord::Base
  # Crear un accessor para guardar temporalmente el id de usuario (y usarlo luego en históricos, etc.)

  attr_accessor :user_id

  # Extensiones en ActiveRecord (para control histórico)

  before_save :hubo_cambios

  def hubo_cambios
    @hubo_cambios = changed?
    true
  end

  def hubo_cambios?
    @hubo_cambios
  end

  def control_histo
    return unless hubo_cambios?
    cl = self.class.to_s.ends_with?('Mod') ? self.class.superclass.to_s : self.class.to_s
    cls = cl.split('::')
    clmh = (cls.size == 1 ? 'H' + cls[0] : cls[0] + '::H' + cls[1]).constantize
    h = clmh.new
    h.created_by_id = user_id
    h.created_at = Time.now
    h.idid = id
    self.class.column_names.each {|c|
      next if c == 'id'
      h.method(c+'=').call(self.method(c).call)
    }
    h.save
  end

  # Método para poder hacer LEFT JOIN. Sintaxis: ljoin('assoc[(alias)][.<idem>]', [<idem>...])

  def self.ljoin(*columns)
    joins ljoin_parse(self, columns)[:cad]
  end

  # Método para poder hacer select de campos de múltiples tablas. Los argumentos son variables (strings) o un array de cadenas.
  # Cada uno de ellos representa un campo con su 'ruta' completa. ej.: cliente.producto.sector.codigo
  # Se genererán los joins precisos para hacer la consulta. Se pueden dar alias específicos a cada tabla intermedia
  # entre paréntesis (sólo válido en la primera aparición de la tabla).
  # Si no hay alias se utilizarán 'ta', 'tb', 'tc', etc. para las sucesivas tablas (saltándose 'to' por ser una palabra reservada de postgreSQL).
  # También se puede dar un alias para el campo dejando un espacio en blanco y especificando el alias.
  # Si no se especifica una alias para el campo, se proporcionará uno automático sólo en el caso de que el campo
  # no sea de la tabla principal, y estará formado por el alias de la tabla correspondiente más un '_' y el propio campo.
  #
  # Un ejemplo completo sería:
  #
  # fichas = Modelo.mselect('codigo', 'cliente(cl).nombre', 'cliente.pais.nombre cpn', 'agente(ag).provincia(pr).nombre', 'agente.pais.nombre')
  #
  # En este caso tendríamos para las tablas los siguientes alias:
  #
  # clientes cl
  # clientes-paises ta (por no haber especificado alias explícito)
  # agentes ag
  # agentes-provincias pr
  # agentes-paises tb
  #
  # En cuanto a los alias de los campos la nomenclatura sería la siguiente:
  #
  # codigo: No tiene alias y no se le da por ser del modelo. Para acceder: fichas[i].codigo
  # cliente.nombre: No tiene alias. Se le da automáticamente cl_nombre. Para acceder: ficha[i].cl_nombre
  # cliente.pais.nombre: Tiene alias explícito. Para acceder: ficha[i].cpn
  # agente.provincia.nombre: No tiene alias. Se le da automáticamente pr_nombre. Para acceder: ficha[i].pr_nombre
  # agente.pais.nombre: No tiene alias. Se le da automáticamente tb_nombre. Para acceder: ficha[i].pr_nombre
  #
  # Si queremos usar cualquier campo de estos en la claúsula where hay que tener en cuenta que no se puede
  # usar su alias (por limitaciones del SQL) y por lo tanto habría que usar la notación alias_de_tabla.campo
  # En el ejemplo anterior, si quisiéramos usar el campo cliente.pais.nombre en el 'where' no podríamos usar
  # 'cpn', en su lugar tendríamos que usar: ta.nombre
  #
  # En la claúsula 'order' se puede usar indistintamente el alias o la notación anterior.
  #

  def self.mselect(*columns)
    r = mselect_parse(self, columns)
    select(r[:cad_sel]).joins(r[:cad_join])
  end

  # Método para duplicar un registro incluyendo sus hijos

  def dup_in_db(campos={}, *hijos)
    uid = defined?(session) ? session[:uid] : 'nada'
    nueva_ficha = self.dup
    campos.each {|k, v| nueva_ficha[k] = v}
    cl = self.class.to_s.ends_with?('Mod') ? self.class.superclass.to_s : self.class.to_s
    pk = cl.downcase + '_id'
    ActiveRecord::Base.connection.transaction {
      nueva_ficha.save
      hijos.flatten.each {|mod|
        campos = []
        valores = []
        mod.column_names.each {|c|
          next if c == 'id'
          campos << c
          valores << (c == pk ? nueva_ficha.id : c)
        }
        tab_name = mod.table_name
        reg = sql_exe("INSERT INTO #{tab_name} (#{campos.join(',')}) SELECT #{valores.join(',')} FROM #{tab_name} WHERE #{pk} = #{self.id} RETURNING id")
        next if reg.count == 0

        begin
          # Insertar los registros en el histórico (si hay histórico)
          modh = ('H' + mod.to_s).constantize
          tabh_name = modh.table_name
          campos << 'idid' << 'created_by_id' << 'created_at'
          valores << 'id' << self.user_id.to_i << "'#{Time.now.to_json[1..-2]}'"
          sql_exe("INSERT INTO #{tabh_name} (#{campos.join(',')}) SELECT #{valores.join(',')} FROM #{tab_name} WHERE id IN (#{reg.map{|r| r['id']}.join(',')})")
        rescue NameError
          # No existe histórico y por lo tanto no hacer nada
        end
      }
    }
    return nueva_ficha.id
  end
end

=begin
class ActiveRecord::Base
  # Does a left join through an association. Usage:
  #
  #     Book.left_join(:category)
  #     # SELECT "books".* FROM "books"
  #     # LEFT OUTER JOIN "categories"
  #     # ON "books"."category_id" = "categories"."id"
  #
  # It also works through association's associations, like `joins` does:
  #
  #     Book.left_join(category: :master_category)

  def self.left_join(*columns)
    _do_left_join columns.compact.flatten
  end

  private

  def self._do_left_join(column, this = self) # :nodoc:
    collection = self
    if column.is_a? Array
      column.each do |col|
        collection = collection._do_left_join(col, this)
      end
    elsif column.is_a? Hash
      column.each do |key, value|
        assoc = this.reflect_on_association(key)
        raise "#{this} has no association: #{key}." unless assoc
        collection = collection._left_join(assoc)
        collection = collection._do_left_join value, assoc.klass
      end
    else
      assoc = this.reflect_on_association(column)
      raise "#{this} has no association: #{column}." unless assoc
      collection = collection._left_join(assoc)
    end
    collection
  end

  def self._left_join(assoc)
    source = assoc.active_record.arel_table
    pk = assoc.association_primary_key.to_sym
    joins source.join(assoc.klass.arel_table, Arel::Nodes::OuterJoin).on(source[assoc.foreign_key].eq(assoc.klass.arel_table[pk])).join_sources
  end
end
=end

class HashForGrids < Hash
  def initialize(cols, data)
    self[:cols] = cols
    self[:data] = data
    self[:new_edit] = Array.new(data.size) {[nil, nil]}
    self[:borrados] = []
    self[:bor_status] = []
  end

  def data(id=nil, col=nil, val='~nil~')
    return self[:data] unless id
    id = id.to_s

    pos = nil
    if col
      col = col.to_s
      self[:cols].each_with_index {|c, i|
        if c[:name] == col
          pos = i + 1
          break
        end
      }
    end

    self[:data].each_with_index {|row, i|
      if id == row[0].to_s
        if pos
          if val != '~nil~'
            row[pos] = val
            self[:new_edit][i][1] = true
          end
          return row[pos]
        else
          return row
        end
      end
    }
    nil
  end

  def col(co)
    self[:cols].each {|c| return c if c[:name] == co}
    nil
  end

  def max_id
    max = self[:data].map{|r| r[0]}.max
    max ? max : 0
  end

  def add_row(pos, data)
    self[:data].insert(pos, data)
    self[:new_edit].insert(pos, [true, nil])
  end

  def del_row(id)
    self[:data].delete_if.with_index {|r, i|
      if r[0].to_s == id.to_s
        self[:bor_status] << self[:new_edit][i]
        self[:new_edit].delete_at(i)
        self[:borrados] << r
      end
    }
  end

  def each_row
    self[:data].each_with_index {|r, i|
      yield(r, self[:new_edit][i][0], self[:new_edit][i][1], i)
    }
  end

  def each_del
    self[:borrados].each_with_index {|r, i|
      yield(r, self[:bor_status][i][0], self[:bor_status][i][1], i)
    }
  end

  def borrados
    self[:borrados]
  end
end

# Módulo MantMod para extender las clases de los controladores
#
module MantMod
  def self.included(base)
    base.extend(ClassMethods)
    base.ini_datos
  end

  ### Métodos de clase
  
  module ClassMethods
    def ini_datos
      @mant = self < ActiveRecord::Base ? true : false
      if @mant
        if self.superclass.modelo_base
          @view = true
          self.table_name = self.superclass.table_name
        else
          @view = self.superclass.table_name != self.table_name
        end
      else
        @view = false
      end

      @campos ||= {}
      @hijos ||= []
      @dialogos ||= []
      @menu_r ||= []
      @menu_l ||= []
      @tags ||= []
      @columnas = []
      @campos_X = []

=begin
      @dialogos.each {|d|
        if d[:menu]
          h = {label: d[:menu], accion: d[:id], tipo: 'dlg'}
          h[:id] = d[:menu_id] if d[:menu_id]
          @menu_r << h
        end
      }
=end
      add_dialogos(@dialogos)


      @refs_ids = [] #Contiene las distintas clases asociadas a los id's que van apareciendo (para calcular bien el index)
      @campos.each {|c, v|
        ini_campo(c, v, nil)
      }

      if @mant
        @titulo ||= self.table_name

        self.superclass.column_names.each{|c|
          cs = c.to_sym
          unless c == 'id' or @campos.include?(cs)
            @campos[cs] = self.superclass.propiedades[cs].deep_dup
            @campos[cs] ||= {}
            @campos[cs][:type] = self.superclass.columns_hash[c].type
          end
        }

        @grid ||= {}
        @grid[:ew] ||= :w
        @grid[:gcols].is_a?(Fixnum) ? @grid[:gcols] = [@grid[:gcols]] : @grid[:gcols] ||= [5]
        @grid[:gcols][1] ||= (@grid[:gcols][0] - 1)*7/11 + 1
        @grid[:gcols][2] ||= 4
        @grid[:visible] = true if @grid[:visible].nil?
        @grid[:height] ||= 250
        @grid[:rowNum] ||= 50
        @grid[:cellEdit] = true if @grid[:cellEdit].nil?
        @grid[:shrinkToFit] = true if @grid[:shrinkToFit].nil?
        @grid[:multiSort] = false if @grid[:multiSort].nil?
        @grid[:scroll] = false if @grid[:scroll].nil?
        @grid[:sortorder] ||= 'asc'
        if @grid[:sortname].nil?
          @campos.each {|c, v|
            if v[:grid]
              @grid[:sortname] = (v[:grid][:index] ? v[:grid][:index] : self.table_name + '.' + c.to_s)
              break
            end
          }
        end

        after_initialize :_ini_campos_ctrl
      else
        @titulo ||= self.to_s[0..-4]

        self.class_eval('def initialize;_ini_campos_ctrl;end')
      end

      @titulo = nt(@titulo)
    end

    def add_campos(cmps)
      cmps.each {|c, v|
        if @campos[c]
          @campos[c].deep_merge!(v)
        else
          @campos[c] = v
        end
        ini_campo(c, @campos[c], nil)
      }
    end

    def add_dialogos(diag)
      @dialogos += diag if diag.object_id != @dialogos.object_id

      # Construir una entrada en @menu_r por cada diálogo que incluya la clave :menu
      # la entrada que se crea reaprovecha la clave :accion de menu_r para guardar
      # el id del diálogo para luego poder abrirlo, y la clave :side para guardar
      # la función :js que se le puede asociar a un diálogo para ser llamada
      # antes de su apertura.
      diag.each {|d|
        if d[:menu]
          h = {label: d[:menu], accion: d[:id], tipo: 'dlg'}
          h[:id] = d[:menu_id] if d[:menu_id]
          h[:side] = d[:js] if d[:js]
          @menu_r << h
        end
      }
    end

    def ini_campo(c, v, context)
      campo = c.to_s
      if @mant
        mo = self.superclass.modelo_base ? self.superclass.modelo_base : self.superclass
        #cmo = self.superclass.modelo_base ? self.superclass.modelo_base.columns_hash[campo] : self.superclass.columns_hash[campo]
        cmo = mo.columns_hash[campo]
        cm = self.columns_hash[campo]
        cm_p = self.superclass.propiedades[c]
        v.merge!(cm_p) {|k, ov, nv| ov} if cm_p
      else
        mo = nil
        cm = nil
      end

      if (cm.nil? and self.method_defined?(campo)) or (cm and cmo.nil?)
        v[:calculado] = true
        v[:ro] = :all
      else
        v[:calculado] = false
        unless v.include?(:ro)
          v[:ro] = :edit if v[:pk]
        end
      end

      v[:form] = (v[:tab] or v[:dlg])

      if campo.ends_with?('_id')
        v[:type] = :string
        if v[:ref].nil?
          v[:ref] = self.superclass.reflect_on_association(campo[0..-4].to_sym).options[:class_name] unless cm.nil?
          v[:ref] ||= campo.split('_')[0].capitalize
        end
      end

      if v[:img]
        if mo and !v[:img][:modelo]
          v[:img][:modelo] = mo.to_s
        end
        v[:img][:tag] ||= c
        v[:nil] = true
      end

      v[:type] ||= cm.type unless cm.nil?
      v[:type] ||= :string
      v[:type] = v[:type].to_sym

      v[:label] ||= campo.ends_with?('_id') ? campo[0..-4] : campo

      v[:visible] = true unless v.include?(:visible)

      hay_grid = !v[:grid].nil?
      if hay_grid
        v[:grid][:name] = campo
        v[:grid][:label] ||= v[:label]
        if v[:grid][:index].nil?
          if campo.ends_with?('_id')
            ref = v[:ref].constantize
            if @refs_ids.include?(ref)
              ###pref =campo[0..-4].pluralize + '_' + self.superclass.table_name
              pref = campo[0..-4].pluralize + '_' + self.table_name
            else
              pref = ref.table_name
              @refs_ids << ref
            end
            v[:grid][:index] = pref + '.' + ref.auto_comp_data[:campos][0]
          else
            ###v[:grid][:index] = self.superclass.table_name + '.' + campo
            v[:grid][:index] = self.table_name + '.' + campo
          end
        end

        unless @columnas.include?(campo)
          @columnas << campo
        end

        v[:grid][:editable] = !v[:ro] if v[:grid][:editable].nil?
        v[:grid][:editoptions] ||= {}
        v[:grid][:searchoptions] ||= {}
        v[:grid][:formatoptions] ||= {}
      end

      case v[:type]
        when :boolean
          v[:manti] ||= 6
          if hay_grid
            v[:grid][:align] ||= 'center'
            #v[:grid][:formatter] ||= 'checkbox'
            v[:grid][:formatter] ||= '~format_check~'
            v[:grid][:unformat] ||= '~unformat_check~'
            v[:grid][:edittype] ||= 'checkbox'
            v[:grid][:editoptions][:value] ||= 'true:false'
            v[:grid][:searchoptions][:sopt] ||= ['eq']
          end
        when :string
          if v[:code].is_a?(Hash)
            v[:code][:prefijo] ||= ''
            v[:code][:relleno] ||= '0'
            v[:code][:relleno] = v[:code][:relleno][0]
          end
          v[:may] = false if v[:may].nil?

          if v[:sel]
            v[:manti] ||= 6
          elsif v[:mask]
            v[:manti] ||= v[:mask].size
          else
            v[:manti] ||= 30
          end

          if hay_grid
            v[:grid][:editoptions][:maxlength] ||= v[:manti]
            v[:grid][:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']

            if campo.ends_with?('_id')
              v[:grid][:editoptions][:dataInit] ||= "~function(e){auto_comp_grid(e,'" + v[:ref] + "');}~"
            elsif v[:sel]
              v[:grid][:formatter] ||= 'select'
              v[:grid][:edittype] ||= 'select'
              v[:grid][:editoptions][:value] ||= v[:sel]
              v[:grid][:align] ||= 'center'
              v[:grid][:searchoptions][:sopt] ||= ['eq', 'ne', 'in', 'ni', 'nu', 'nn']
            elsif v[:mask] or v[:code] or v[:may]
              #v[:grid][:editoptions][:dataInit] ||= "~function(e){mask({elem: e,mask:'" + v[:mask] + "',may:" + v[:may].to_s + "});}~"
              v[:grid][:edittype] ||= 'custom'
              v[:grid][:editoptions][:code] ||= v[:code]
              v[:grid][:editoptions][:mask] ||= v[:mask]
              v[:grid][:editoptions][:may] ||= v[:may]
              v[:grid][:editoptions][:custom_element] ||= "~jqg_custom_element~"
              v[:grid][:editoptions][:custom_value] ||= "~jqg_custom_value~"
            end
          end
        when :integer, :decimal
          v[:manti] ||= 7
          v[:decim] ||= (v[:type] == :integer ? 0 : 2)
          v[:signo] = false if v[:signo].nil?
          if hay_grid
            v[:grid][:align] ||= 'right'
            v[:grid][:editoptions][:dataInit] ||= '~function(e){numero(e,' + v[:manti].to_s + ',' + v[:decim].to_s + ',' + v[:signo].to_s + ')}~'
            #v[:grid][:searchoptions][:dataInit] ||= '~function(e){numero(e,' + v[:manti].to_s + ',' + v[:decim].to_s + ',' + v[:signo].to_s + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','in','ni','nu','nn']
            #v[:grid][:formatter] ||= 'number'
            #v[:grid][:formatoptions][:decimalPlaces] ||= v[:decim]
            if v[:sel]
              v[:grid][:formatter] ||= 'select'
              v[:grid][:edittype] ||= 'select'
              v[:grid][:editoptions][:value] ||= v[:sel]
              v[:grid][:align] ||= 'center'
            end
          end
        when :date
          v[:manti] ||= 8
          v[:date_opts] ||= {}
          if hay_grid
            v[:grid][:align] ||= 'center'
            #v[:grid][:formatter] ||= 'date'
            v[:grid][:editoptions][:dataInit] ||= '~function(e){date_pick(e,' + v[:date_opts].to_json + ')}~'
            #v[:grid][:searchoptions][:dataInit] ||= '~function(e){date_pick(e,' + v[:date_opts].to_json + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          end
        when :time
          v[:manti] ||= 8
          if hay_grid
            v[:grid][:editoptions][:dataInit] ||= '~function(e){$(e).entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true' : 'false') + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          end
        when :text
          v[:manti] ||= 50
          v[:rows] ||= 5
          if hay_grid
            v[:grid][:edittype] ||= 'textarea'
            v[:grid][:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
          end
        when :div
          v[:nil] = true
      end

      v[:decim] ||= 0
      v[:gcols] ||= 3
      # Mejor no dar valor a 'size'. Cuando hay parámetros dependientes de emp/ej
      # aquí no tiene sentido darle valor: mejor en gen_form (application_controller)
      #v[:size] ||= v[:manti]

      # Cálculo de la anchura de las columnas
      if hay_grid and v[:grid][:width].nil?
        m = v[:manti].is_a?(Fixnum) ? v[:manti] : 0
        w = [m, v[:grid][:label].size].max
        if [:integer, :decimal, :date].include?(v[:type]) or v[:code]
          v[:grid][:width] = w*8
        else
          v[:grid][:width] = w*5
        end
      end

      # definición de los métodos de acceso para los campos X

      if cm.nil? and !v[:calculado]
        v[:X] = true

=begin
        case v[:type]
          when :boolean
            ini = 'false'
            conv = ''
          when :integer
            ini = '0'
            conv = '.to_i'
          when :decimal
            ini = '0.to_d'
            conv = '.to_d'
          when :date
            ini = 'Date.today'
            conv = '.to_date'
          when :time
            ini = 'Time.now'
            conv = '.to_time'
          when :div
            ini = 'nil'
            conv = ''
          else
            ini = "''"
            conv = '.to_s'
        end
        ini = 'nil' if v[:nil]

        met = "def #{campo}=(v);@#{campo}=(v.nil? ? #{ini} : v#{conv});end;def #{campo};@#{campo};end"
        context ? context.instance_eval(met) : self.class_eval(met)

        if campo.ends_with?('_id')
          met = "def #{campo[0..-4]};#{v[:ref]}.find_by(id: self.#{campo});end"
          context ? context.instance_eval(met) : self.class_eval(met)
        end
=end
      end
    end

    def col_model_html(cm)
      cm.to_json.gsub('"~', '').gsub('~"', '')
    end

    def campos
      @campos
    end

    def campos=(c)
      @campos = c
    end

    def columnas
      @columnas
    end

    def hijos=(v)
      @hijos = v
    end

    def hijos
      @hijos
    end

    def titulo
      @titulo
    end

    def mant?
      @mant
    end

    def view?
      @view
    end

    def grid
      @grid
    end

    def dialogos
      @dialogos
    end

    def menu_l
      @menu_l
    end

    def menu_r
      @menu_r
    end

    def tags
      @tags
    end
  end

  ### Métodos de instancia

  def val_campo(c, v)
    if v[:X] and !c.to_s.ends_with?('_id') and !v[:nil]
      case v[:type]
        when :integer
          v[:value] = 0
        when :decimal
          v[:value] = 0.0
        when :string
          v[:value] = ''
      end
    end
  end

  def _ini_campos_ctrl
    @campos = self.class.campos.deep_dup

    # Inicialización de los campos X a valores razonables cuando no pueden ser nil
    @campos.each {|c, v| val_campo(c, v)}

    ini_campos_ctrl if self.respond_to?(:ini_campos_ctrl)
  end

  def val_cast_campo(val, v)
    return nil if val.nil? and v[:nil]

    if v[:ref]
      if val.is_a?(String) && val.strip.empty?
        return nil
      else
        return val.to_i
      end
    end

    case v[:type]
      when :integer
        return val.to_i
      when :decimal
        return val.to_d
      when :date
        return(val.to_date) if val
      when :time
        return(val.to_time) if val
      when :string
        return val.to_s
    end

    return val
  end

  def method_missing(m, *args, &block)
    ms = m.to_s
    v = @campos[m]
    return v[:value] if v
    if ms.ends_with?('=')
      v = @campos[ms[0..-2].to_sym]
      if v
        v[:value] = val_cast_campo(args[0], v)
        return
      end
    else
      v = @campos[(ms + '_id').to_sym]
      return v[:ref].constantize.find_by(id: v[:value]) if v
    end
    super(m, args, block)
  end

  def [](cmp)
    return self.method(cmp).call if self.respond_to?(cmp)
    v = @campos[cmp.to_sym]
    return v[:value] if v
    v = @campos[(cmp.to_s + '_id').to_sym]
    return v[:ref].constantize.find_by(id: v[:value]) if v
    raise ArgumentError, "No existe el campo '#{cmp}'"
  end

  def []=(cmp, val)
    cmp = cmp.to_sym
    cmpi  = cmp.to_s + '='
    if self.respond_to?(cmpi)
      self.method(cmpi).call(val)
    else
      v = @campos[cmp]
      v ? v[:value] = val_cast_campo(val, v) : raise(ArgumentError, "No existe el campo '#{cmp}'")
    end
  end

  def add_campo(c, v)
    @campos[c.to_sym] = v
    self.class.ini_campo(c, v, self)
    val_campo(c, v) unless v[:value]
  end

  def campos
    @campos
  end

  # Método para poner en contexto las propiedades que dependen de él (dependencias de parámetros de empresa/ejercicio etc.)
  # Este método sobrecarga al del modelo original, pero es necesario para los procs, que no heredan de nadie
  # Al retornar "self" es encadenable en ActiveRecord si procede (sin sentido en los procs) (p.ej.: p = PaisesMod.new.contexto(binding))
  def contexto(cntxt)
    Nimbus::contexto(@campos, cntxt)
    self
  end
end

module Modelo
  def self.included(base)
    base.extend(ClassMethods)
    base.ini_datos
  end

  ### Métodos de clase

  module ClassMethods
    def ini_datos
      self.send(:attr_accessor, :parent)

      @propiedades ||= {}

      if @auto_comp_data.nil?
        h = {}
        c = []
        if column_names.include?('descripcion')
          c << 'descripcion'
          h[:orden] = 'descripcion'
        elsif column_names.include?('nombre')
          c << 'nombre'
          h[:orden] = 'nombre'
        end

        if column_names.include?('codigo')
          c << 'codigo'
          h[:orden] = 'codigo' unless h[:orden]
        end

        if c == []
          c << column_names[1]
          h[:orden] = column_names[1]
        end

        h[:campos] = c
        @auto_comp_data = h
      end

      if @auto_comp_mselect
        @auto_comp_mselect << 'id' unless @auto_comp_mselect.include?('id')
      end

      # Cálculo del vector de claves primarias (pk)
      @pk = []
      @propiedades.each {|c, h|
        cpk = h[:pk]
        if cpk != nil
          if cpk.class == Fixnum and @pk[cpk].nil?
            @pk[cpk] = c.to_s
          else
            @pk << c.to_s
          end
        end
      }
      @pk.compact!

      # Definición de funciones para acceder a la empresa y al ejercicio en cualquier modelo
      cad_emp = ''
      cl = self
      loop {
        if cl.column_names.include?('empresa_id')
          if cad_emp.empty?
            self.instance_eval("def empresa_path;'';end")
          else
            cad_emp << 'empresa'
          end
          break
        elsif cl.pk[0] and cl.pk[0].ends_with?('_id')
          cad_emp << cl.pk[0][0..-4] + '.'
          cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
        else
          cad_emp = ''
          break
        end
      }
      unless cad_emp.empty?
        self.instance_eval("def empresa_path;'#{cad_emp[0..-9]}';end")
        self.class_eval("def empresa;#{cad_emp};end")
      end

      if (self.to_s != 'Ejercicio')
        cad_eje = ''
        cl = self
        loop {
          if cl.column_names.include?('ejercicio_id')
            if cad_eje.empty?
              self.instance_eval("def ejercicio_path;'';end")
            else
              cad_eje << 'ejercicio'
            end
            break
          elsif cl.pk[0] and cl.pk[0].ends_with?('_id')
            cad_eje << cl.pk[0][0..-4] + '.'
            cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
          else
            cad_eje = ''
            break
          end
        }
        unless cad_eje.empty?
          self.instance_eval("def ejercicio_path;'#{cad_eje[0..-11]}';end")
          self.class_eval("def ejercicio;#{cad_eje};end")
        end
      end

      after_initialize :_ini_campos
    end

    def add_propiedades(cmps)
      @propiedades.deep_merge!(cmps)
    end

    def propiedades
      @propiedades
    end

    def campos
      @campos ? @campos : @propiedades
    end

    def nimbus_vista(vista)
      @modelo_base = self.superclass
      self.table_name = vista
      @propiedades = self.superclass.propiedades.deep_dup
      @pk = self.superclass.pk.deep_dup
      @auto_comp_data = self.superclass.auto_comp_data.deep_dup
      @auto_comp_mselect = self.superclass.auto_comp_mselect.deep_dup
    end

    def modelo_base
      @modelo_base
    end

    def pk
      @pk
    end

    def auto_comp_data
      @auto_comp_data
    end

    def auto_comp_mselect
      @auto_comp_mselect ? @auto_comp_mselect : ['*']
    end

    def hijo?
      !column_names.include?('empresa_id') and !column_names.include?('ejercicio_id') and @pk[0].ends_with?('_id')
    end

    def db_views
      # Contiene un array de modelos que son views en la DB asociadas a este modelo (para usar en búsquedas)
      @db_views
    end

    def propiedad(cmp, prop, cntxt=nil)
      cmp = cmp.to_sym
      prop = prop.to_sym

      res = nim_eval((@campos ? @campos : @propiedades)[cmp][prop], cntxt)
      Nimbus::ParamsDobleEval.include?(prop) && res.is_a?(String) ? eval(res) : res
    end
  end

  ### Métodos de instancia

  def auto_comp_label(tipo=:form)
    t = ''
    self.class.auto_comp_data[:campos].reverse_each {|c|
      t << self[c].to_s + ' '
    }

    t[0..-2]
  end

  def auto_comp_value(tipo=:form)
    tipo = tipo.to_sym if tipo.class == String

    if tipo == :grid
      self[self.class.auto_comp_data[:campos][0]]
    else
      t = ''
      self.class.auto_comp_data[:campos].each {|c|
        t << self[c].to_s + ' '
      }

      t[0..-2]
    end
  end

  def _ini_campos
    cl = self.class.to_s.ends_with?('Mod') ? self.class.superclass : self.class
    pr = cl.propiedades
    ch = cl.columns_hash
    cl.column_names.each {|c|
      begin
        cs = c.to_sym
        unless !pr.include?(cs) or pr[cs][:nil] or c.ends_with?('_id')
          case ch[c].type
            when :boolean
              #ini = 'false'
              ini = false
            when :integer
              #ini = '0'
              ini = 0
            when :decimal
              #ini = '0.to_d'
              ini = 0.to_d
            when :date
              #ini = 'Date.today'
              #ini = 'nil'
              ini = nil
            when :time
              #ini = 'Time.now'
              #ini = 'nil'
              ini = nil
            else
              #ini = "''"
              ini = ''
          end
          #eval("self.#{c}=#{ini} if self.#{c}.nil?")
          self[c] = ini if self[c].nil?
        end
      rescue
      end
    }
  end

  # Método para poner en contexto las propiedades que dependen de él (dependencias de parámetros de empresa/ejercicio etc.)
  # Al retornar "self" es encadenable en ActiveRecord (p.ej.: p = Pais.new.contexto(binding))
  def contexto(cntxt)
    @propiedades = self.class.propiedades.deep_dup
    Nimbus::contexto(@propiedades, cntxt)
    self
  end

  def propiedades
    if @campos
      @campos
    elsif @propiedades
      @propiedades
    else
      self.class.propiedades
    end
  end

  def campos
    propiedades
  end
end

# Módulo para hacer mixin en los modelos de históricos

module Historico
  def self.included(base)
    base.extend(ClassMethods)
    base.ini_datos
  end

  ### Métodos de clase

  module ClassMethods
    def ini_datos
      belongs_to :created_by, :class_name => 'Usuario'

      #clp = self.to_s[1..-1].constantize
      clpa = self.to_s.split('::')
      clp = clpa.size == 1 ? clpa[0][1..-1].constantize : (clpa[0] + '::' + clpa[1][1..-1]).constantize
      clp.reflect_on_all_associations(:belongs_to).each{|a| belongs_to a.name, class_name: a.options[:class_name]}
      @propiedades = clp.propiedades

      self.instance_eval("def empresa_path;'#{clp.empresa_path}';end") if clp.respond_to?(:empresa_path)
      self.instance_eval("def ejercicio_path;'#{clp.ejercicio_path}';end") if clp.respond_to?(:ejercicio_path)
    end

    def propiedades
      @propiedades
    end
  end

  ### Métodos de instancia
end
