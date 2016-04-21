# Poner i18n por defecto

I18n.config.enforce_available_locales = false
I18n.default_locale = :es


# Nombre de la cookie de sesión (sobreescribe el de config/initializers/session_store.rb)
Rails.application.config.session_store :cookie_store, key: '_' + Rails.app_class.to_s.split(':')[0].downcase + '_session'
# Formato SQL para el schema
Rails.application.config.active_record.schema_format = :sql

# Nuevo formato de fecha

Date::DATE_FORMATS[:sp] = '%d-%m-%Y'

module Nimbus
  # Variable global para activar/desactivar mensajes de debug
  Debug = false

  # Nombre de la cookie de empresa/ejercicio
  CookieEmEj = ('_' + Rails.app_class.to_s.split(':')[0].downcase + '_emej').to_sym
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
  def data(id=nil, col=nil, val='~nil~')
    return self[:data] unless id

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

    self[:data].each {|row|
      if id == row[0]
        if pos
          val == '~nil~' ? row[pos] : row[pos] = val
          return row[pos]
        else
          return row
        end
      end
    }
    nil
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

      @campos ||= {}
      @hijos ||= []
      @dialogos ||= []
      @menu_r ||= []
      @menu_l ||= []
      @col_model = []
      @columnas = []
      @campos_X = []

      @dialogos.each {|d|
        if d[:menu]
          h = {label: d[:menu], accion: d[:id], tipo: 'dlg'}
          h[:id] = d[:menu_id] if d[:menu_id]
          @menu_r << h
        end
      }

      @grid ||= {}
      @grid[:ew] ||= :w
      @grid[:gcols].is_a?(Fixnum) ? @grid[:gcols] = [@grid[:gcols]] : @grid[:gcols] ||= [5]
      @grid[:gcols][1] ||= (@grid[:gcols][0] - 1)*7/11 + 1
      @grid[:gcols][2] ||= 4
      @grid[:visible] = true if @grid[:visible].nil?
      @grid[:height] ||= 250
      @grid[:rowNum] ||= 100
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

      @refs_ids = [] #Contiene las distintas clases asociadas a los id's que van apareciendo (para calcular bien el index)
      @campos.each {|c, v|
        ini_campo(c, v, nil)
      }

      if @mant
        @titulo ||= self.table_name
        @view = self.superclass.table_name != self.table_name

        self.superclass.column_names.each{|c|
          cs = c.to_sym
          unless c == 'id' or @campos.include?(cs)
            @campos[cs] = self.superclass.propiedades[cs]
            @campos[cs] ||= {}
            @campos[cs][:type] = self.superclass.columns_hash[c].type
          end
        }

        after_initialize :_ini_campos_ctrl
      else
        @titulo ||= self.to_s[0..-4]
        @view = false

        self.class_eval('def initialize;_ini_campos_ctrl;end')
      end

      @titulo = nt(@titulo)
    end

    def ini_campo(c, v, context)
      campo = c.to_s
      if @mant
        cmo = self.superclass.columns_hash[campo]
        cm = self.columns_hash[campo]
        cm_p = self.superclass.propiedades[c]
        v.merge!(cm_p) {|k, ov, nv| ov} if cm_p
      else
        cm = nil
      end

      if cm.nil? and self.method_defined?(campo) or cm and cmo.nil?
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

      v[:type] ||= cm.type unless cm.nil?
      v[:type] ||= :string
      v[:type] = v[:type].to_sym

      v[:label] ||= campo.ends_with?('_id') ? campo[0..-4] : campo

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

        @col_model << v[:grid]
        #@columnas << v[:grid][:index]
        @columnas << campo

        v[:grid][:editable] = !v[:ro] if v[:grid][:editable].nil?
        v[:grid][:editoptions] ||= {}
        v[:grid][:searchoptions] ||= {}
        v[:grid][:formatoptions] ||= {}
      end

      case v[:type]
        when :boolean
          v[:manti] ||= 6
          if hay_grid
            v[:grid][:edittype] ||= 'checkbox'
            v[:grid][:align] ||= 'center'
            #v[:grid][:formatter] ||= '~format_check~'
            #v[:grid][:unformat] ||= '~unformat_check~'
            v[:grid][:formatter] ||= 'checkbox'
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
      v[:size] ||= v[:manti]

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

    def col_model
      @col_model
    end

    def col_model_html(cm)
      cm.to_json.gsub('"~', '').gsub('~"', '')
    end

    def campos
      @campos
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
  end

  ### Métodos de instancia

=begin
  def val_campo(c, v)
    c = c.to_s
    unless v[:nil] or c.ends_with?('_id')
      case v[:type]
        when :boolean
          ini = 'false'
        when :integer
          ini = '0'
        when :decimal
          ini = '0.to_d'
        when :date
          ini = 'Date.today'
        when :time
          ini = 'Time.now'
        else
          ini = "''"
      end
      eval("self.#{c}=#{ini} if self.#{c}.nil?")
    end
  end
=end

  def _ini_campos_ctrl
    @campos = self.class.campos.deep_dup

    # Inicialización de los campos X a valores razonables cuando no pueden ser nil
    #@campos.each {|c, v| val_campo(c, v) if v[:X]}

    ini_campos_ctrl if self.respond_to?(:ini_campos_ctrl)
  end

  def val_cast_campo(val, ty, ni)
    return nil if val.nil? and ni

    case ty
      when :integer
        return val.to_i
      when :decimal
        return val.to_d
      when :date
        return val.to_date
      when :time
        return val.to_time
      else
        return val
    end
  end

  def method_missing(m, *args, &block)
    ms = m.to_s
    v = @campos[m]
    return v[:value] if v
    if ms.ends_with?('=')
      v = @campos[ms[0..-2].to_sym]
      if v
        v[:value] = val_cast_campo(args[0], v[:type], v[:nil])
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
      v ? v[:value] = val_cast_campo(val, v[:type], v[:nil]) : raise(ArgumentError, "No existe el campo '#{cmp}'")
    end
  end

  def add_campo(c, v)
    @campos[c.to_sym] = v
    self.class.ini_campo(c, v, self)
    #val_campo(c, v)
  end

  def campos
    @campos
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
          cad_emp << 'empresa' unless cad_emp.empty?
          break
        elsif cl.pk[0] and cl.pk[0].ends_with?('_id')
          cad_emp << cl.pk[0][0..-4] + '.'
          cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
        else
          cad_emp = ''
          break
        end
      }
      self.class_eval("def empresa;#{cad_emp};end;def empresa_path;'#{cad_emp}';end") unless cad_emp.empty?

      if (self.to_s != 'Ejercicio')
        cad_eje = ''
        cl = self
        loop {
          if cl.column_names.include?('ejercicio_id')
            cad_eje << 'ejercicio' unless cad_eje.empty?
            break
          elsif cl.pk[0] and cl.pk[0].ends_with?('_id')
            cad_eje << cl.pk[0][0..-4] + '.'
            cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
          else
            cad_eje = ''
            break
          end
        }
        self.class_eval("def ejercicio;#{cad_eje};end;def ejercicio_path;'#{cad_eje}';end") unless cad_eje.empty?
      end

      after_initialize :_ini_campos
    end

    def propiedades
      @propiedades
    end

    def pk
      @pk
    end

    def auto_comp_data
      @auto_comp_data
    end

    def auto_comp_mselect
      @auto_comp_mselect ? @auto_comp_mselect : '*'
    end

    def hijo?
      !column_names.include?('empresa_id') and !column_names.include?('ejercicio_id') and @pk[0].ends_with?('_id')
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
              ini = 'false'
            when :integer
              ini = '0'
            when :decimal
              ini = '0.to_d'
            when :date
              #ini = 'Date.today'
              ini = 'nil'
            when :time
              #ini = 'Time.now'
              ini = 'nil'
            else
              ini = "''"
          end
          eval("self.#{c}=#{ini} if self.#{c}.nil?")
        end
      rescue
      end
    }
  end
end
