# Poner i18n por defecto

I18n.config.enforce_available_locales = false
I18n.default_locale = :es

# Formato SQL para el schema

Rails.application.config.active_record.schema_format = :sql

# Nuevo formato de fecha

Date::DATE_FORMATS[:sp] = '%d-%m-%Y'

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
end

# Método para traducir personalizado
def nt(tex)
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

  return('#' + tex.humanize) if r.start_with?('translation missing')
  r[0] == '#' ? r[1..-1] : r
end

# Extensiones en ActiveRecord (para control histórico)

class ActiveRecord::Base
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
    h.created_by_id = 1
    h.created_at = Time.now
    h.idid = id
    self.class.column_names.each {|c|
      next if c == 'id'
      h.method(c+'=').call(self.method(c).call)
    }
    h.save
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
      @col_model = []
      @columnas = []
      @campos_f = []
      @campos_X = []

      @grid ||= {}
      @grid[:ew] ||= :w
      @grid[:gcols].is_a?(Fixnum) ? @grid[:gcols] = [@grid[:gcols]] : @grid[:gcols] ||= [5]
      @grid[:gcols][1] ||= (@grid[:gcols][0] - 1)*7/11 + 1
      @grid[:gcols][2] ||= 4
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

      refs_ids = [] #Contiene las distintas clases asociadas a los id's que van apareciendo (para calcular bien el index)
      @campos.each {|c, v|
        campo = c.to_s
        if @mant
          cmo = self.superclass.columns_hash[campo]
          cm = self.columns_hash[campo]
          cm_p = self.superclass.propiedades[c]
          v.merge!(cm_p) {|k, ov, nv| ov} if cm_p
          @view = self.superclass.table_name != self.table_name
        else
          cm = nil
          @view = false
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

        @campos_f << campo if v[:tab]

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
              if refs_ids.include?(ref)
                ###pref =campo[0..-4].pluralize + '_' + self.superclass.table_name
                pref =campo[0..-4].pluralize + '_' + self.table_name
              else
                pref = ref.table_name
                refs_ids << ref
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
            v[:grid][:formatter] ||= '~format_check~'
            v[:grid][:unformat] ||= '~unformat_check~'
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
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','bw','bn','in','ni','ew','en','cn','nc','nu','nn']

            if campo.ends_with?('_id')
              v[:grid][:editoptions][:dataInit] ||= "~function(e){auto_comp_grid(e,'" + v[:ref] + "');}~"
            elsif v[:sel]
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
            v[:grid][:searchoptions][:dataInit] ||= '~function(e){numero(e,' + v[:manti].to_s + ',' + v[:decim].to_s + ',' + v[:signo].to_s + ')}~'
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
            v[:grid][:searchoptions][:dataInit] ||= '~function(e){date_pick(e,' + v[:date_opts].to_json + ')}~'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          end
        when :text
          v[:manti] ||= 50
          v[:rows] ||= 5
          if hay_grid
            v[:grid][:edittype] ||= 'textarea'
            v[:grid][:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','bw','bn','in','ni','ew','en','cn','nc','nu','nn']
          end
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
          add_campo_x(campo, v)
        end
      }

      if @mant
        #@titulo ||= self.superclass.to_s.pluralize
        @titulo ||= self.table_name

        self.superclass.column_names.each{|c|
          cs = c.to_sym
          unless c == 'id' or @campos.include?(cs)
            @campos[cs] = self.superclass.propiedades[cs]
            @campos[cs][:type] = self.superclass.columns_hash[c].type
          end
        }

        after_initialize :_ini_campos_ctrl
      else
        @titulo = self.to_s[0..-4]
      end
    end

    def add_campo_x(campo, v)
      @campos_X << campo
      v[:X] = true

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
        else
          ini = "''"
          conv = '.to_s'
      end
      ini = 'nil' if v[:nil]

      p = eval("Proc.new {def #{campo}=(v);@#{campo}=(v.nil? ? #{ini} : v#{conv});end}")
      self.class_eval(&p)
      p = eval("Proc.new {def #{campo};@#{campo};end}")
      self.class_eval(&p)
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

    def add_campo(c, v)
      campo = c.to_s
      v[:label] ||= campo.ends_with?('_id') ? campo[0..-4] : campo
      @campos[c] = v
      @campos_f << campo if v[:tab]
      add_campo_x(campo, v)
    end

    def campos_f
      @campos_f
    end

    def campos_X
      @campos_X
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
  end

  ### Métodos de instancia

  def _ini_campos_ctrl
    cmps = self.class.campos
    self.class.campos_X.each {|c|
      ch = cmps[c.to_sym]
      unless ch[:nil] or c.ends_with?('_id')
        case ch[:type]
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
    }
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
=begin
      cad_emp = ''
      cl = self
      loop {
        if cl.column_names.include?('empresa_id')
          cad_emp << 'empresa' unless cad_emp.empty?
          break
        elsif cl.pk[0].ends_with?('_id')
          cad_emp << cl.pk[0][0..-4] + '.'
          cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
        else
          break
        end
      }
      self.class_eval("def empresa;#{cad_emp};end") unless cad_emp.empty?

      if (self.to_s != 'Ejercicio')
        cad_eje = ''
        cl = self
        loop {
          if cl.column_names.include?('ejercicio_id')
            cad_eje << 'ejercicio' unless cad_eje.empty?
            break
          elsif cl.pk[0].ends_with?('_id')
            cad_eje << cl.pk[0][0..-4] + '.'
            cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).options[:class_name].constantize
          else
            break
          end
        }
        self.class_eval("def ejercicio;#{cad_eje};end") unless cad_eje.empty?
      end
=end

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

    def hijo?
      !column_names.include?('empresa_id') and !column_names.include?('ejercicio_id') and @pk[0].ends_with?('_id')
    end
  end

  ### Métodos de instancia

  def auto_comp_label(tipo=:form)
    t = ''
    self.class.auto_comp_data[:campos].reverse_each {|c|
      t << self[c] + ' '
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
        t << self[c] + ' '
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
              ini = 'Date.today'
            when :time
              ini = 'Time.now'
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
