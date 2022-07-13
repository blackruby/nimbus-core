# Configuración general (development y production)

# No volcar el esquema sql
Rails.application.config.active_record.dump_schema_after_migration = false

# Poner i18n por defecto

I18n.config.enforce_available_locales = false
I18n.default_locale = :es

# A partir de Rails 5.1 la configuración por defecto será la que está comentada
# La otra es para que el comportamiento sea como antes
#Rails.application.config.active_record.time_zone_aware_types = [:datetime, :time]
Rails.application.config.active_record.time_zone_aware_types = [:datetime]


# Formato SQL para el schema
Rails.application.config.active_record.schema_format = :sql

# Nuevo formato de fecha

Date::DATE_FORMATS[:sp] = '%d-%m-%Y'

module Nimbus
  # Constante global para activar/desactivar mensajes de debug
  Debug = false

  # Nombre de la cookie de sesión y de empresa/ejercicio
  Rails.application.config.session_store :cookie_store, key: '_' + Gestion + '_session'
  CookieEmEj = ('_' + Gestion + '_emej').to_sym

  # Adecuación de valores de configuración

  Config[:db] ||= {}
  Config[:db][:development] ||= {}
  Config[:db][:production] ||= {}
  Config[:db][:development][:database] ||= Config[:db][:database] || Gestion
  Config[:db][:production][:database] ||= Config[:db][:database] || Gestion
  Config[:db][:development][:pool] ||= Config[:db][:pool] || 2
  Config[:db][:production][:pool] ||= Config[:db][:pool] || 5

  Config[:puma] ||= {}
  Config[:puma][:port] ||= 3000
  if Rails.env == 'development'
    Config[:puma][:min_threads] = 1
    Config[:puma][:max_threads] = Config[:db][:development][:pool]
    Config[:puma][:workers] = 0
  else
    Config[:puma][:min_threads] ||= 1
    Config[:puma][:max_threads] ||= Config[:db][:production][:pool]
    Config[:puma][:workers] ||= 0
  end

  if Config[:p2p].is_a?(Integer)
    Config[:p2p] = {tot: Config[:p2p]}
  elsif Config[:p2p].is_a?(Hash)
    Config[:p2p][:tot] ||= Config[:p2p].values.reduce(:+) + 20
  else
    Config[:p2p] = {tot: 50}
  end

  # Si no hay valor, será ilimitado, si lo hay y es inválido se asignará 5GB, en cualquier otro caso 
  # se adaptará el valor según las unidades especificadas.
  if Config[:cuota_disco]
    unit = Config[:cuota_disco].to_s.upcase.scan(/[A-Z]+/).to_a
    case unit.size
    when 0
      fact = 1
    when 1
      case unit[0]
      when 'B'
        fact = 1
      when 'K', 'KB'
        fact = 1024
      when 'M', 'MB'
        fact = 1024**2
      when 'G', 'GB'
        fact = 1024**3
      when 'T', 'TB'
        fact = 1024**4
      else
        fact = nil
      end
    else
      fact = nil
    end
    Config[:cuota_disco] = fact ? Config[:cuota_disco].to_i * fact : 5 * 1024**3
  end

  # Obtención de un hash de los meses para campos tipo 'select'
  def self.mes_sel
    I18n.t('date.month_names')[1..-1].map.with_index {|m,i| [i+1, m.capitalize]}.to_h
  end

  def self.add_context_menu(ctr, v)
    if v[:ref]
      if v[:menu]
        v[:ref].constantize.auto_comp_menu.each {|m|
          v[:menu] << m
        }
      end
      mdl_ctr = "#{v[:ref]}::Controller"
      ctr.instance_eval("include #{mdl_ctr}") if Object.const_defined?(mdl_ctr) && !ctr.included_modules.include?(mdl_ctr.constantize)
    end
  end

  Home = Rails.root.to_s

  def self.const_loaded(cl, fi)
    f = fi.split('/')
    iapp = f.index('app')
    return unless iapp
    
    tipo = f[iapp + 1]

    # Hacer los includes correspondientes por si no están hechos
    cl.class_eval('include Modelo') if tipo == 'models' && cl < ActiveRecord::Base && cl.superclass == ActiveRecord::Base && !cl.include?(Modelo)
    cl.class_eval('include Historico') if tipo == 'models_h' && !cl.include?(Historico)

    # Cargar _adds
    add = '/' + f[iapp..-1].join('/')[0..-4] + '_add.rb'
    ModulosCli.each {|m|
      p = Home + '/' + m + add
      load(p) if File.exist? p
    }

    if tipo == 'controllers'
      return unless f[-1].ends_with? '_controller.rb'

      ruta_v = '/' + f[iapp..-1].join('/').sub('/controllers/', '/views/').sub('_controller.rb', '')

      procesa_vistas = ->(tipo) {
        views = []
        ruta = "#{ruta_v}/#{tipo}.html.erb"

        ModulosCli.each {|m|
          next if m == f[iapp-2] + '/' + f[iapp-1]
          fic = Home + '/' + m + ruta
          views << fic if File.exist?(fic)
        }

        if views.present?
          fic = f[0..iapp-1].join('/') + '/' + ruta
          views.unshift(fic) if File.exist?(fic)
          cl.set_nimbus_views(tipo, views)
        end
      }

      procesa_vistas.call(:ficha)
      procesa_vistas.call(:grid)

      # Reordenamiento del hash de campos (@campos) para posicionar los tags 'post'
      ctr_mod = cl.to_s.sub('Controller', 'Mod')
      if const_defined?(ctr_mod)
        ctr_mod = ctr_mod.constantize
        cmpa = []
        post = false
        ctr_mod.campos.each {|k, v|
          if v[:post]
            post = true
          else
            cmpa << [k, v]
          end

          # Hacer include del module "Controller" si existe y añadir las opciones del menú contextual (auto_comp_menu) a v[:menu]
          begin
            add_context_menu(cl, v) if v[:ref]
          rescue => e
            Rails.logger.fatal "###### Fallo al procesar el campo '#{k}' del controlador #{cl}"
            Rails.logger.fatal e.message
            Rails.logger.fatal e.backtrace.join("\n")
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
      end
    end
  end

  def self.load_adds(fi)
    # Mantenemos el método por si hay alguna llamada "legacy"
  end

  # Array con los parámetros de los campos de un mantenimiento que necesitan doble eval (integer, boolean, symbol)
  ParamsDobleEval = [:manti, :decim, :visible, :ro, :signo]

  def self.contexto(hsh, cntxt)
    hsh.each {|k, v|
      # parámetros de tipo integer, sym y booleanos (necesitan doble eval)
      ParamsDobleEval.each {|p|
        v[p] = eval(nim_eval(v[p], cntxt)) if v[p].is_a?(String)
        v[p] = 0 if v[p].nil? and (p == :manti or p == :decim)
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

  # Método para transliterar la hora recibida como argumento a UTC (no convertida sino transliterada)
  # Si la hora recibida fuera 19:10CEST esta función devolvería 19:10UTC
  def self.time(t)
    t ? Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec): nil
  end

  # Método para obtener la hora actual pero en UTC (no convertida sino transliterada)
  # Si la hora del sistema fuera 19:10CEST esta función devolvería 19:10UTC
  # Lo recomendable es usarla siempre para no tener líos con los time zones
  def self.now
    #t = Time.now
    #Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec)
    self.time(Time.now)
  end

  # Método para adecuar un valor a algo razonable. Su uso de momento está restringido
  # a valores de tipo time (datetime, etc.) convirtiendo el valor de la zona horaria
  # que sea a la de por defecto, pero sin alterar los datos (hora, min, sec)
  # En los demás casos devuelve el valor inalterado. Esto es importante en la genaración
  # de xlsx para que no haga conversiones no deseadas en las horas.
  def self.nimval(val)
    if val.is_a?(Time) or val.is_a?(DateTime)
      Time.new(val.year, val.month, val.day, val.hour, val.min, val.sec)
    else
      val
    end
  end
end

# Añadir el método to_d a NilClass

class NilClass
  def to_d
    0.to_d
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

  # Para mantener compatibilidad con Rails 5 y anteriores
if Rails.version >= '6'
  class Date
    alias :to_s_org :to_s

    def to_s(l=nil)
      l == :sp || l == :es ? self.strftime('%d-%m-%Y') : to_s_org
    end
  end
end

# Método para traducir personalizado
def nt(tex, h={}, mis = false)
  return('') if tex.nil? or tex == ''

  begin
    r = I18n.t(tex)
    if r.start_with?('translation missing')
      r = I18n.t(tex.downcase)
      if r.start_with?('translation missing')
        if tex[-1] == 's'
          r = I18n.t(tex.singularize).pluralize(I18n.locale)
        elsif tex.ends_with?('_id')
          r = I18n.t(tex[0..-4])
        end
      end
    end

    if r.start_with?('translation missing')
      if mis
        return nil
      else
        return((Nimbus::Debug ? '#' : '') + tex.humanize)
      end
    end
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

def ljoin_parse_alias(modelo, ali_auto, *columns)
  cad_join = ''
  tab_proc = {}
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

def ljoin_parse(modelo, *columns)
  # Para que el primer alias automático sea 'ta' pasamos el alias 'sz'
  ljoin_parse_alias(modelo, 'sz', *columns)
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

  def control_histo
    return unless saved_changes?

    clh = self.class.modelo_histo
    if clh
      clh.create(self.attributes.merge({id: nil, idid: self.id, created_by_id: self.user_id, created_at: Nimbus.now}))
    end
  end

  def control_histo_b
    return unless self.id
      clh = self.class.modelo_histo
      if clh
        begin
          clh.create(clh.where('idid = ?', self.id).order(:created_at).last.attributes.merge({id: nil, idid: -self.id, created_by_id: self.user_id, created_at: Nimbus.now}))
        rescue
          # Posible error si no hubiera histórico para este registro
          # no hacer nada
        end
      end
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

  def self.fonargs(*args)
    from(table_name + '(' + args.join(',') + ') ' + table_name)
  end

=begin
  # Método para duplicar un registro incluyendo sus hijos
  def dup_in_db(campos={}, *hijos)
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
          valores << 'id' << self.user_id.to_i << "'#{Nimbus.now.to_json[1..-2]}'"
          sql_exe("INSERT INTO #{tabh_name} (#{campos.join(',')}) SELECT #{valores.join(',')} FROM #{tab_name} WHERE id IN (#{reg.map{|r| r['id']}.join(',')})")
        rescue NameError
          # No existe histórico y por lo tanto no hacer nada
        end
      }
    }
    return nueva_ficha.id
  end
=end

  # Método para duplicar un registro incluyendo los hijos especificados
  # La duplicación se hace directamente en la base de datos por lo que
  # no se dispara ningún callback en los hijos. En el modelo principal sí.
  def dup_in_db(campos={}, *hijos)
    nueva_ficha = self.dup
    campos.each {|k, v| nueva_ficha[k] = v}
    ActiveRecord::Base.connection.transaction {
      nueva_ficha.save
      hijos.flatten.each {|mod|
        pk = mod.pk[0]
        campos = []
        valores = []
        mod.column_names.each {|c|
          next if c == 'id'
          campos << c
          valores << (c == pk ? nueva_ficha.id : c)
        }
        tab_name = mod.table_name
        reg = sql_exe("INSERT INTO #{tab_name} (#{campos.join(',')}) SELECT #{valores.join(',')} FROM #{tab_name} WHERE #{pk} = #{self.id}")

        # Insertar los registros en el histórico (si hay histórico)
        modh = mod.modelo_histo
        if modh
          tabh_name = modh.table_name
          campos << 'idid' << 'created_by_id' << 'created_at'
          valores << 'id' << self.user_id.to_i << "'#{Nimbus.now.to_json[1..-2]}'"
          sql_exe("INSERT INTO #{tabh_name} (#{campos.join(',')}) SELECT #{valores.join(',')} FROM #{tab_name} WHERE #{pk} = #{self.id}")
        end
      }
    }
    return nueva_ficha.id
  end

  # Método para duplicar un registro incluyendo los hijos recursivamente
  # (nietos, bisnietos, etc.) según los has_many declarados en los modelos.
  # La duplicación se hace en rails por lo que todos los call_backs serán llamados.
  # "campos" es un hash cuyas claves son campos y sus valores los nuevos
  # datos que se asignarán al duplicar la ficha.
  # "hijos_excl" es un array con los hijos que se desean excluir de la
  # duplicación. La notación es, para el primer nivel, el nombre del has_many
  # y para niveles más profundos, la lista de has_many separados por ":".
  # P.ej, si quisiéramos excluir el has_many de primer nivel "apuntes" y
  # el de segundo nivel "detalles" accesible desde "lineas" de primer nivel,
  # usaríamos: dup_with_has_many({campo: valor}, %w(apuntes lineas:detalles))
  # Si sólo se desea excluir un has_many no es necesario pasar un array,
  # bastaría con pasar una cadena o symbol con el nombre del has_many.
  def dup_with_has_many(campos={}, hijos_excl=[])
    id = nil
    ActiveRecord::Base.connection.transaction {id = _dup_with_has_many(self, campos, '', (hijos_excl.is_a?(Array) ? hijos_excl.map(&:to_s) : [hijos_excl.to_s]))}
    id
  end

  private def _dup_with_has_many(ficha, campos, nivel, hijos_excl)
    nueva_ficha = ficha.dup
    campos.each {|k, v| nueva_ficha[k] = v}
    nueva_ficha.save
    ficha.class.reflect_on_all_associations(:has_many).each do |hijo|
      next if hijos_excl.include?(nivel + hijo.name.to_s)
      #cl = hijo.options[:class_name].constantize
      cl = hijo.klass
      #cl.where("#{cl.pk[0]} = #{ficha.id}").each {|f|
      cl.where("#{hijo.foreign_key} = #{ficha.id}").each {|f|
        f.user_id = ficha.user_id
        #_dup_with_has_many(f, {cl.pk[0] => nueva_ficha.id})
        _dup_with_has_many(f, {hijo.foreign_key => nueva_ficha.id}, nivel + hijo.name.to_s + ':', hijos_excl)
      }
    end
    nueva_ficha.id
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
  def initialize(cols, data, export)
    self[:cols] = cols
    self[:data] = data
    self[:export] = export
    self[:data_ini] = data.deep_dup
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
      #@mant = self < ActiveRecord::Base ? true : false
      @mant = (self < ActiveRecord::Base)
=begin
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
=end
      # No se da la opción (como antes) de cambiar table_name directamente en el modelo asociado al controlador
      # Así podemos aprovechar el nuevo método save personalizado en modelos para grabar vistas.
      if @mant
        @view = self.superclass.view?
        self.table_name = self.superclass.table_name if @view
      end

      @campos ||= {}
      @hijos ||= []
      @dialogos ||= []
      @menu_r ||= []
      @menu_l ||= []
      @tags ||= []
      @columnas = []
      @campos_X = []
      @nivel ||= :e # Variable para controlar el nivel (e: empresa, j: ejercicio, g: global) en el caso de procesos (en mantenimientos se ignora porque es automático)

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

=begin
        self.superclass.column_names.each{|c|
          cs = c.to_sym
          unless c == 'id' or @campos.include?(cs)
            @campos[cs] = self.superclass.propiedades[cs].deep_dup
            @campos[cs] ||= {}
            @campos[cs][:type] = self.superclass.columns_hash[c].type
          end
        }
=end

        @grid ||= {}
        @grid[:ew] ||= :w
        @grid[:gcols].is_a?(Integer) ? @grid[:gcols] = [@grid[:gcols]] : @grid[:gcols] ||= [5]
        @grid[:gcols][1] ||= (@grid[:gcols][0] - 1)*7/11 + 1
        @grid[:gcols][2] ||= 4
        @grid[:visible] = true if @grid[:visible].nil?
        @grid[:altRows] = true if @grid[:altRows].nil?
        @grid[:height] ||= 250
        @grid[:cellEdit] = false if @grid[:cellEdit].nil?
        @grid[:shrinkToFit] = true if @grid[:shrinkToFit].nil?
        @grid[:multiSort] = false if @grid[:multiSort].nil?
        @grid[:scroll] = false if @grid[:scroll].nil?
        @grid[:rowNum] ||= (@grid[:scroll] ? 100 : 50)
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
          if d[:menu_id]
            h[:id] = d[:menu_id]
          elsif d[:id]
            h[:id] = "m_#{d[:id]}"
          end
          h[:side] = d[:js] if d[:js]
          h[:dis_ro] = d[:dis_ro]
          @menu_r << h
        end
      }
    end

    def ini_campo(c, v, context)
      campo = c.to_s
      if @mant
        #mo = self.superclass.modelo_base ? self.superclass.modelo_base : self.superclass
        mo = self.modelo_base
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
        v[:menu] = [] if v[:menu].nil?
      end

      if v[:img]
        #if mo and !v[:img][:modelo]
        #  v[:img][:modelo] = mo.to_s
        #end
        #v[:img][:tag] ||= c
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
            #v[:grid][:index] = pref + '.' + ref.auto_comp_data[:campos][0]
            v[:grid][:index] = pref + '.' + ref.auto_comp_data[:campos][0].scan(/[0-9a-zA-Z_.]*/)[0].split('.')[-1]
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

            if campo.ends_with?('_id')
              v[:grid][:editoptions][:dataInit] ||= "~function(e){auto_comp_grid(e,'" + v[:ref] + "');}~"
            elsif v[:sel]
              v[:grid][:formatter] ||= 'select'
              v[:grid][:edittype] ||= 'select'
              v[:grid][:editoptions][:value] ||= v[:sel]
              v[:grid][:align] ||= 'center'

              if v[:grid][:nim_sel] == false
                # La búsqueda se hará con una entrada de texto normal
                # Incluimos las operaciones 'in' y 'ni' para poder buscar
                # varias opciones separadas por comas.
                v[:grid][:searchoptions][:sopt] ||= ['eq', 'ne', 'in', 'ni', 'nu', 'nn']
              else
                # La búsqueda se hará con una select. Es más intuitivo para
                # el usuario pero perdemos las operaciones 'in' y 'ni'.
                # Es la opción por defecto
                v[:grid][:stype] ||= 'select'
                v[:grid][:searchoptions][:sopt] ||= ['eq', 'ne', 'nu', 'nn']
                v[:grid][:searchoptions][:value] ||= {'' => 'todo'}.merge(v[:sel])
              end
            elsif v[:mask] or v[:code] or v[:may]
              #v[:grid][:editoptions][:dataInit] ||= "~function(e){mask({elem: e,mask:'" + v[:mask] + "',may:" + v[:may].to_s + "});}~"
              v[:grid][:edittype] ||= 'custom'
              v[:grid][:editoptions][:code] ||= v[:code]
              v[:grid][:editoptions][:mask] ||= v[:mask]
              v[:grid][:editoptions][:may] ||= v[:may]
              v[:grid][:editoptions][:custom_element] ||= "~jqg_custom_element~"
              v[:grid][:editoptions][:custom_value] ||= "~jqg_custom_value~"
            elsif v[:img]
              v[:grid][:sortable] = false
              v[:grid][:search] = false
              v[:editable] = false
            end

            v[:grid][:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
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
          v[:manti] ||= 10
          v[:nil] = true if v[:nil].nil?
          v[:date_opts] ||= {}
          if hay_grid
            v[:grid][:align] ||= 'center'
            #v[:grid][:formatter] ||= 'date'
            v[:grid][:editoptions][:dataInit] ||= '~function(e){date_pick(e,' + v[:date_opts].to_json + ')}~'
            #v[:grid][:searchoptions][:dataInit] ||= '~function(e){date_pick(e,' + v[:date_opts].to_json + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
            v[:grid][:searchoptions][:dataInit] = '~function(e){date_pick(e)}~'
          end
        when :time
          v[:manti] ||= 8
          if hay_grid
            v[:grid][:editoptions][:dataInit] ||= '~function(e){$(e).entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true' : 'false') + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          end
        when :datetime
          v[:manti] ||= 19
          v[:seg] = true if v[:seg].nil?
          v[:nil] = true if v[:nil].nil?
          if hay_grid
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          end
        when :text
          v[:manti] ||= 50
          v[:rows] ||= 5
          if hay_grid
            v[:grid][:edittype] ||= 'textarea'
            v[:grid][:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
            if v[:rich]
              v[:grid][:formatter] ||= '~function(v){return "<div class=\'ql-editor\' style=\'padding: 0;height: unset;max-height: 50px\'>" + v + "</div>"}~'
            end
          end
        when :div
          v[:nil] = true
        when :upload
          v[:nil] = true
      end

      v[:decim] ||= 0
      v[:gcols] ||= 3
      # Mejor no dar valor a 'size'. Cuando hay parámetros dependientes de emp/ej
      # aquí no tiene sentido darle valor: mejor en gen_form (application_controller)
      #v[:size] ||= v[:manti]

      # Cálculo de la anchura de las columnas
      if hay_grid and v[:grid][:width].nil?
        m = v[:manti].is_a?(Integer) ? v[:manti] : 0
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

    def nivel
      @nivel.to_sym
    end

    def modelo_base
      self.superclass.modelo_base
    end

    def nim_lock
      @nim_lock
    end

    def nim_bus_plantilla
      @nim_bus_plantilla
    end

    def nim_bus_rld
      @nim_bus_rld
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
    @campos.each {|c, v| val_campo(c, v) unless v[:value]}

    ini_campos_ctrl if self.respond_to?(:ini_campos_ctrl)
  end

  def val_cast_campo(val, v)
    return nil if val.nil? and v[:nil]

    if v[:ref]
      #if val.is_a?(String) && val.strip.empty?
      if val.blank?
        return nil
      else
        return val.to_i
      end
    end

    case v[:type]
      when :integer
        return val.to_i
      when :decimal
        return val.to_f
      when :date
        return(val.to_date) if val
      when :time
        if val
          t = val.is_a?(String) ? val.to_time : val
          return(t ? Time.utc(2000, 1, 1, t.hour, t.min, t.sec) : nil)
        end
      when :datetime
        if val && val.is_a?(String)
          return Nimbus.time(val.to_time)
        end
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
    begin
      return self.method(cmp).call if self.respond_to?(cmp)
    rescue => e
      raise ArgumentError, "Clase: #{self.class} Campo: #{cmp} No se puede acceder al campo."
    end

    v = @campos[cmp.to_sym]
    return v[:value] if v
    v = @campos[(cmp.to_s + '_id').to_sym]
    return v[:ref].constantize.find_by(id: v[:value]) if v
    raise ArgumentError, "Clase: #{self.class} Campo: #{cmp} No existe el campo."
  end

  def []=(cmp, val)
    cmp = cmp.to_sym
    cmpi  = cmp.to_s + '='
    if self.respond_to?(cmpi)
      self.method(cmpi).call(val)
    else
      v = @campos[cmp]
      v ? v[:value] = val_cast_campo(val, v) : raise(ArgumentError, "Clase: #{self.class} Campo: #{cmp} No existe el campo.")
    end
  end

  def add_campo(c, v)
    @campos[c.to_sym] = v
    self.class.ini_campo(c, v, self)
    val_campo(c, v) unless v[:value]
    # Hacer include del module "Controller" si existe y añadir las opciones del menú contextual (auto_comp_menu) a v[:menu]
    # self.class vale xxxMod así que inferimos la clase del controlador: xxxController
    Nimbus.add_context_menu("#{self.class.to_s[0..-4]}Controller".constantize, v) if v[:ref]
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

      @auto_comp_menu ||= []

      #if @auto_comp_mselect
      #  @auto_comp_mselect << 'id' unless @auto_comp_mselect.include?('id')
      #end

      # Cálculo del vector de claves primarias (pk)
      @pk = []
      @propiedades.each {|c, h|
        cpk = h[:pk]
        if cpk != nil
          if cpk.is_a?(Integer) && @pk[cpk].nil?
            @pk[cpk] = c.to_s
          else
            @pk << c.to_s
          end
        end
      }
      @pk.compact!

      # Definición de funciones para acceder a la empresa y al ejercicio en cualquier modelo
      unless self.respond_to?('empresa_path')
        cad_emp = ''
        cl = self
        loop {
          #if cl.column_names.include?('empresa_id')
          if cl.pk.include?('empresa_id')
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
      end

      unless self.to_s == 'Ejercicio' or self.respond_to?('ejercicio_path')
        cad_eje = ''
        cl = self
        loop {
          #if cl.column_names.include?('ejercicio_id')
          if cl.pk.include?('ejercicio_id')
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

      # El siguiente bloque sólo hay que hacerlo la primera vez que se invoca ini_datos
      # lo sabemos porque no existe el método de instancia :parent
      # ini_datos es llamado más veces cuando se añaden propiedades (add_propiedades)
      unless self.instance_methods.include?(:parent)
        self.send(:attr_accessor, :parent)
        after_initialize :_ini_campos
        # Tratamiento automático de históricos. Así no es necesario registrar callbacks en la definición del modelo
        after_save :control_histo
        after_destroy :control_histo_b
      end
    end

    def add_propiedades(cmps)
      @propiedades.deep_merge!(cmps)
      ini_datos
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
      @auto_comp_menu = self.superclass.auto_comp_menu.deep_dup
      @view = true
      # Sobrecargar el método "save" para poder grabar en el modelo base
      self.class_eval(%q(
        def save
          cl = self.class.modelo_base
          if (self.id)
            f = cl.find(self.id)
          else
            f = cl.new
          end
          cl.column_names.each {|c| f[c] = self[c]}
          f.user_id = self.user_id
          f.save
          self.id = f.id
        end

        def destroy
          self.class.modelo_base.destroy(self.id) if (self.id)
        end
      ))
    end

    def modelo_base
      @modelo_base || self
    end

    def modelo_histo
      begin
        cls = modelo_base.to_s.split('::')
        (cls.size == 1 ? 'H' + cls[0] : cls[0] + '::H' + cls[1]).constantize
      rescue
        nil
      end
    end

    def pk
      @pk
    end

    def auto_comp_data
      @auto_comp_data
    end

    def auto_comp_mselect
      #@auto_comp_mselect ? @auto_comp_mselect : ['*']
      if @auto_comp_mselect
        @auto_comp_mselect + (@auto_comp_mselect.include?('id') ? [] : ['id'])
      else
        ['*']
      end
    end

    def auto_comp_menu
      @auto_comp_menu
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

    def modelo_bus
      @modelo_bus
    end

    def view?
      @view
    end

    def historico?
      false
    end

    # El siguiente método sirve para devolver el nombre del controlador "asociado" a un modelo.
    # Esto es para poder controlar si un modelo tiene permiso de acceso (fundamentalmente para las búsquedas)
    # La idea es comprobar si su controlador asociado tiene permiso (total, sólo lectura o sin borrado)
    # El controlador asociado se infiere a partir del nombre de la tabla del modelo base
    # salvo que se defina en la clase del modelo una variable (@ctrl_for_perms) con otro controlador.
    # La notación del nombre del controlador, si pertenece a un módulo sería, por ejemplo, 'conta/asientos'

    def ctrl_for_perms
      if @ctrl_for_perms
        @ctrl_for_perms
      else
        mb = modelo_base
        mb.name.include?('::') ? mb.table_name.sub('_', '/') : mb.table_name
      end 
    end
  end

  ### Métodos de instancia

  def auto_comp_label(tipo=:form)
    t = ''
    self.class.auto_comp_data[:campos].reverse_each {|c|
      t << self[c].to_s + ' '
    }

    #t[0..-2]
    t.strip!
    t.empty? ? '------' : t
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

=begin
  def save
    if self.class.view?
      cl = self.class.modelo_base
      if (self.id)
        f = cl.find(self.id)
      else
        f = cl.new
      end
      cl.column_names.each {|c| f[c] = self[c]}
      f.user_id = self.user_id
      f.save
      f.id
    else
      super
    end
  end
=end
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
      belongs_to :created_by, :class_name => '::Usuario'

      if self.superclass == ActiveRecord::Base
        # Es el caso antiguo (se mantiene por compatibilidad)
        # En este caso heredamos todas las asociociones belongs_to
        # y heredamos los métodos de acceso a empresa y ejercicio.
        clpa = self.to_s.split('::')
        clp = clpa.size == 1 ? clpa[0][1..-1].constantize : (clpa[0] + '::' + clpa[1][1..-1]).constantize
        @propiedades = clp.propiedades
        clp.reflect_on_all_associations(:belongs_to).each{|a| belongs_to a.name, class_name: a.options[:class_name]}

        self.instance_eval("def empresa_path;'#{clp.empresa_path}';end") if clp.respond_to?(:empresa_path)
        self.instance_eval("def ejercicio_path;'#{clp.ejercicio_path}';end") if clp.respond_to?(:ejercicio_path)
      else
        # Caso nuevo (el modelo histórico hereda del modelo base)
        # En este caso solo hay que cambiar el nombre de la tabla (las asociaciones, etc. se heredan)
        # y asignar el hash de propiedades del padre
        @ctrl_for_perms ||= self.table_name.gsub('_', '/')

        t = self.table_name.split('_')
        self.table_name = (t.size == 1 ? "h_#{t[0]}" : "#{t[0]}_h_#{t[1..-1].join('_')}")

        @propiedades = self.superclass.propiedades
        @pk = self.superclass.pk
        @auto_comp_data = self.superclass.auto_comp_data
        @auto_comp_mselect = self.superclass.auto_comp_mselect
        @auto_comp_menu = self.superclass.auto_comp_menu

        # Desactivar los callbacks
        self.reset_callbacks(:initialize)
        self.reset_callbacks(:validate)
        self.reset_callbacks(:create)
        self.reset_callbacks(:save)
      end
    end

    def propiedades
      @propiedades
    end

    def db_views
      # Contiene un array de modelos que son views en la DB asociadas a este modelo (para usar en búsquedas)
      @db_views
    end

    def modelo_bus
      @modelo_bus
    end

    def historico?
      true
    end
  end

  ### Métodos de instancia
end
