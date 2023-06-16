class ::Object
  def deep_freeze
    if self.respond_to? :each
      self.is_a?(Hash) ? self.each{|_k, v| v.deep_freeze} : self.each{|v| v.deep_freeze}
    end

    self.freeze unless self.frozen?
  end
end

module ::Nimbus
  # Constante global para activar/desactivar mensajes de debug
  Debug = false

  # Paths en función de si hay un cliente seleccionado
  Gestion = ENV['NIMBUS_CLI'] || Rails.app_class.to_s.split(':')[0].downcase
  GestionPath = ENV['NIMBUS_CLI'] ? "clientes/#{ENV['NIMBUS_CLI']}/" : ''
  DataPath = GestionPath + 'data'
  BusPath = GestionPath + 'bus'
  BusUsuPath = DataPath + '/_bus'
  GiPath = GestionPath + 'formatos'
  GiUsuPath = DataPath + '/_formatos'
  LogPath = GestionPath + 'log'

  # NO BORRAR los comentarios de IniConf y FinConf (el código entre ellos será sustituido al encriptar la aplicación)
  ##--IniConf
  Config = {}
  Dir.glob(%W(config/nimbus-core.yml config/nimbus.yml clientes/#{ENV['NIMBUS_CLI']}/config/nimbus.yml)) {|f|
    Config.merge! YAML.load(ERB.new(File.read(f)).result).deep_symbolize_keys
  }
  ##--FinConf

  # Adecuación de valores de configuración

  Config[:puma] ||= {}
  if Rails.env == 'development'
    Config[:puma][:min_threads] = 0
    Config[:puma][:max_threads] = 5
    Config[:puma][:workers] = 0
    Config[:puma][:bind] = nil
    Config[:puma][:port] = ENV['PUMA_PORT_DEV'] || Config[:puma][:port_dev] || 3000
    Config[:puma][:preload_app] = false
    Config[:puma][:queue_requests] = true
  else
    Config[:puma][:port] = ENV['PUMA_PORT'] || Config[:puma][:port] || 3000
    Config[:puma][:max_threads] = ENV['PUMA_MAX_THREADS'] || Config[:puma][:max_threads] || 5
    Config[:puma][:min_threads] = ENV['PUMA_MIN_THREADS'] || Config[:puma][:min_threads] || 0
    Config[:puma][:workers] = ENV['PUMA_WORKERS'] || Config[:puma][:workers] || 0
    Config[:puma][:bind] = ENV['PUMA_BIND'] || Config[:puma][:bind]

    if ENV['PUMA_PRELOAD_APP']
      Config[:puma][:preload_app] = (ENV['PUMA_PRELOAD_APP'].upcase == 'TRUE')
    else
      Config[:puma][:preload_app] = true unless Config[:puma].include?(:preload_app)
    end
    
    if ENV['PUMA_QUEUE_REQUESTS']
      Config[:puma][:queue_requests] = (ENV['PUMA_QUEUE_REQUESTS'].upcase == 'TRUE')
    else
      Config[:puma][:queue_requests] = true unless Config[:puma].include?(:queue_requests)
    end
  end

  Config[:db] ||= {}
  Config[:db][:development] ||= {}
  Config[:db][:development][:database] = ENV['DB_PREFIX'].to_s + (ENV['DB_DATABASE'] || Config[:db][:development][:database] || Config[:db][:database] || Gestion)
  Config[:db][:development][:pool] = ENV['DB_POOL'] || Config[:db][:development][:pool] || Config[:db][:pool] || Config[:puma][:max_threads]
  Config[:db][:development][:username] = ENV['DB_USERNAME'] || Config[:db][:development][:username] || Config[:db][:username] || 'postgres'
  Config[:db][:development][:password] = ENV['DB_PASSWORD'] || Config[:db][:development][:password] || Config[:db][:password] || 'postgres'
  Config[:db][:development][:host] = ENV['DB_HOST'] || Config[:db][:development][:host] || Config[:db][:host] || (ENV['NIMBUS_DOCKER'] ? ((Addrinfo.ip('dbhost') rescue nil) ? 'dbhost' : 'host.docker.internal') : '')
  Config[:db][:development][:port] = ENV['DB_PORT'] || Config[:db][:development][:port] || Config[:db][:port] || ''

  Config[:db][:production] ||= {}
  Config[:db][:production][:database] = ENV['DB_PREFIX'].to_s + (ENV['DB_DATABASE'] || Config[:db][:production][:database] || Config[:db][:database] || Gestion)
  Config[:db][:production][:pool] = ENV['DB_POOL'] || Config[:db][:production][:pool] || Config[:db][:pool] || Config[:puma][:max_threads]
  Config[:db][:production][:username] = ENV['DB_USERNAME'] || Config[:db][:production][:username] || Config[:db][:username] || 'postgres'
  Config[:db][:production][:password] = ENV['DB_PASSWORD'] || Config[:db][:production][:password] || Config[:db][:password] || 'postgres'
  Config[:db][:production][:host] = ENV['DB_HOST'] || Config[:db][:production][:host] || Config[:db][:host] || Config[:db][:development][:host]
  Config[:db][:production][:port] = ENV['DB_PORT'] || Config[:db][:production][:port] || Config[:db][:port] || ''

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

  # Cálculo de los módulos 'puros' disponibles
  if Config[:modulos]
    Modulos = []
    Config[:modulos].each {|m|
      mod = "modulos/#{m}"
      Modulos << mod if m != 'idiomas' && m != 'nimbus-core' && Dir.exist?(mod)
    }
  else
    Modulos = Dir.glob('modulos/*').select{|m| File.directory?(m) && m != 'modulos/idiomas' && m != 'modulos/nimbus-core'}
  end

  ModulosGlob = '{' + Modulos.join(',') + ',modulos/nimbus-core}'
  Modulos << '.'
  ModulosCli = ENV['NIMBUS_CLI'] ? Modulos + ["clientes/#{ENV['NIMBUS_CLI']}"] : Modulos
  ModulosCliGlob = '{' + ModulosCli.join(',') + ',modulos/nimbus-core}'

  # Nombre de la cookie de sesión y de empresa/ejercicio
  nombre = ENV['NIMBUS_CLI'] || (Gestion == 'nimbus' ? Config[:db][Rails.env.to_sym][:database] : Gestion)
  Rails.application.config.session_store :cookie_store, key: '_' + nombre + '_session', expire_after: 100.years
  CookieEmEj = ('_' + nombre + '_emej').to_sym

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
          #fic = f[0..iapp-1].join('/') + '/' + ruta
          #views.unshift(fic) if File.exist?(fic)
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

Nimbus::Config.deep_freeze
Nimbus.freeze

Rails.application.configure do
  # No volcar el esquema sql
  config.active_record.dump_schema_after_migration = false

  # A partir de Rails 5.1 la configuración por defecto será la que está comentada
  # La otra es para que el comportamiento sea como antes
  #Rails.application.config.active_record.time_zone_aware_types = [:datetime, :time]
  config.active_record.time_zone_aware_types = [:datetime]

  # Formato SQL para el schema
  config.active_record.schema_format = :sql

  # Configuración de todos los paths

  modulos = ::Nimbus::Modulos[0..-2]
  modulos_nc = modulos + ['modulos/nimbus-core']
  modulos_cli = modulos_nc + ["clientes/#{ENV['NIMBUS_CLI']}"] 

  ############# locales

  r = 'config/locales'
  (modulos_nc + %w(modulos/idiomas)).each {|m|
    d = m + '/' + r
    config.paths[r].unshift(d) if Dir.exist?(d)
  }
  d = modulos_cli[-1] + '/' + r
  config.paths[r] << d if Dir.exist?(d)

  ############# initializers

  r = 'config/initializers'
  modulos_nc.each {|m|
    d = m + '/' + r
    config.paths[r].unshift(d) if Dir.exist?(d)
  }
  d = modulos_cli[-1] + '/' + r
  config.paths[r] << d if Dir.exist?(d)

  ############# Resto de carpetas con precedencia fifo

  %w(app/models app/models_h app/controllers app/controllers_mod app/views app/assets vendor/assets lib/tasks).each {|r|
    modulos_cli.each {|m|
      d = m + '/' + r
      config.paths[r.split('_')[0]] << d if Dir.exist?(d)
    }
  }
    
  ############# Seeds

  r = 'db/seeds.rb'
  config.paths[r] = ['modulos/nimbus-core/db/seeds.rb']

  ############# Rutas

  r = 'config/routes.rb'
  d = modulos_cli[-1] + '/' + r
  config.paths[r].unshift(d) if File.exist?(d)
  modulos_nc.each {|d| config.paths[r] << "#{d}/#{r}"}

  ############# carpetas de migraciones

  r = 'db/migrate'
  mods = modulos_nc.map{|m| m.split('/')[1]}
  modulos_cli.each {|d|
    s = "#{d}/db/migrate"
    config.paths[r] << s if File.exist?(s)
    mods.each {|m|
      s = "#{d}/db/migrate_#{m}"
      config.paths[r] << s if File.exist?(s)
    }
  }

  ############# Fichero de log
  FileUtils.mkpath(Nimbus::LogPath)
  config.paths['log'] = "#{Nimbus::LogPath}/#{Rails.env}.log"

  rr = Rails.root.to_s

  if Rails.version >= '6' # Configuración específica para Rails 6 o superior (testeado en rails 7.0.2.2)
    # Por defecto se asumiría que esas clases serían Gi y NimbusPdf)
    Rails.autoloaders.main.inflector.inflect("gi" => "GI", "nimbus_pdf" => "NimbusPDF")
    # Evitar el eager loading de los ficheros _add. Así se cargan (load) exclusivamente
    # en Nimbus.const_loaded y no es necesario las comprobaciones antiguas en estos
    # ficheros para ver la existencia de sus clases respectivas y evitar dobles loads.
    Rails.autoloaders.main.ignore '**/*_add.rb'
    #Rails.autoloaders.main.on_load('/home/ruby/proyectos/nimbus/modulos/nimbus-core/app/controllers/paises_controller.rb') {
    Rails.autoloaders.main.on_load(:ANY) {|_cs, cl, fi| Nimbus.const_loaded(cl, fi) if fi.starts_with?(rr)}
    Rails.autoloaders.main.on_unload(:ANY) {|cs|
      unless cs.include? '::'
        cte = cs.ends_with?('Controller') ? cs.sub('Controller', 'Mod') : 'H' + cs
        Object.__send__(:remove_const, cte) if Object.const_defined?(cte)
      end
    }

    # Han cambiado este default a true y en Nimbus tiene que ser false (se admiten campos references con valor nil)
    config.active_record.belongs_to_required_by_default = false
  else
    # /usr/local/lib/ruby/gems/x.y.z/gems/railties-5.2.3/lib/rails/engine.rb
    class Rails::Engine
      def eager_load!
        config.eager_load_paths.each do |load_path|
          matcher = %r{\A#{Regexp.escape(load_path.to_s)}/(.*)\.rb\Z}
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1') unless file.ends_with? '_add.rb'
          end
        end
      end
    end

    # /usr/local/lib/ruby/gems/2.6.0/gems/activesupport-5.2.3/lib/active_support/dependencies.rb
    module ActiveSupport::Dependencies
      def load_file(path, const_paths = loadable_constants_for_path(path))
        const_paths = [const_paths].compact unless const_paths.is_a? Array
        parent_paths = const_paths.collect { |const_path| const_path[/.*(?=::)/] || ::Object }

        result = nil
        newly_defined_paths = new_constants_in(*parent_paths) do
          result = Kernel.load path
          Nimbus.const_loaded(path.split(/\/app\/\w+\//)[1][0..-4].camelize.constantize, path) if path.starts_with?(Rails.root.to_s)
        end

        autoloaded_constants.concat newly_defined_paths unless load_once_path?(path)
        autoloaded_constants.uniq!
        result
      end

      def require_or_load(file_name, const_path = nil)
        file_name = $` if file_name =~ /\.rb\z/
        expanded = File.expand_path(file_name)
        return if loaded.include?(expanded)

        ActiveSupport::Dependencies.load_interlock do
          # Maybe it got loaded while we were waiting for our lock:
          return if loaded.include?(expanded)

          # Record that we've seen this file *before* loading it to avoid an
          # infinite loop with mutual dependencies.
          loaded << expanded
          loading << expanded

          begin
            if load?
              # Enable warnings if this file has not been loaded before and
              # warnings_on_first_load is set.
              load_args = ["#{file_name}.rb"]
              load_args << const_path unless const_path.nil?

              if !warnings_on_first_load || history.include?(expanded)
                result = load_file(*load_args)
              else
                enable_warnings { result = load_file(*load_args) }
              end
            else
              result = require file_name
              Nimbus.const_loaded(file_name.split(/\/app\/\w+\//)[1].camelize.constantize, file_name+'.rb') if file_name.starts_with?(Rails.root.to_s) && (file_name.include?('/app/controllers/') || file_name.include?('/app/models'))
            end
          rescue Exception
            loaded.delete expanded
            raise
          ensure
            loading.pop
          end

          # Record history *after* loading so first load gets warnings.
          history << expanded
          result
        end
      end
    end
  end
end

# Inicializar hash de orígenes (procedencias).
$nim_origenes = {}
