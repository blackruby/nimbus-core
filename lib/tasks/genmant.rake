# Script para crear un nuevo modelo y el mantenimiento
# asociado. Se basa en las especificaciones dadas
# en nimbus/esquemas/

namespace :nimbus do
  desc 'Generar mantenimientos a partir de los esquemas definidos'
  task :genmant, [:file, :opt] => :environment do |task, args|

    def trata_def(tipo, fic, modulo, ar)
      mod = fic[fic.rindex('/')+1..-5]
      path = fic[0..fic.rindex('/')].gsub('esquemas', '.')
      modc = mod.capitalize
      modp = mod.pluralize
      modcp = modc.pluralize
      moduloc = modulo.capitalize
      if modulo == ''
        namesp = ''
        table = modp
        tableh = 'h_' + modp
      else
        namesp = moduloc + '::'
        table = modulo + '_' + modp
        tableh = modulo + '_h_' + modp
      end

      return if tipo == :new and File.exists?("#{path}app/controllers/#{modulo}/#{modp}_controller.rb")

      begin
        puts "Procesando #{fic}..."
        prop = {mig: true, histo: true, tipo: :mant}
        h = '['
        open(fic, 'r').each {|l|
          l.strip!
          next if l == ''
          if l[0] == '#'
            if l[1] == '{'
              prop = prop.merge(eval(l[1..-1]))
            end
            next
          end
          h << l
        }
        h << ']'
        cmps = eval(h)

        modelo = StringIO.new
        modelo_asoc = StringIO.new
        controller = StringIO.new
        mig = StringIO.new
        pk = []

        modelo.puts("class #{namesp}#{modc} < ActiveRecord::Base")
        modelo.puts('  @propiedades = {')

        controller.puts("class #{namesp}#{modcp}Mod < #{namesp}#{modc}")
        controller.puts('  @campos = {')

        mig.puts("class Create#{moduloc}#{modcp} < ActiveRecord::Migration")
        mig.puts('=begin') unless prop[:mig]
        mig.puts('  def change')
        mig.puts('    col = lambda {|t|')

        refs = []
        cmps.each { |cmp|
          cmpn = cmp[:cmp]

          # Actualizar el locale
          ar[:loc].each_key {|l|
            ls = l.to_s
            if cmp[:locale] and cmp[:locale][l]
              if ar[:loc][l][ls][cmpn] and ar[:loc][l][ls][cmpn][0] != '#'
                puts('  Ya existe la clave ' + cmpn + ' en el locale "' + ls + '"') if ar[:loc][l][ls][cmpn] != cmp[:locale][l]
              else
                ar[:loc][l][ls][cmpn] = cmp[:locale][l]
              end
            else
              ar[:loc][l][ls][cmpn] = '#' + cmpn.humanize unless ar[:loc][l][ls][cmpn]
            end
          }

          ty = cmp[:type].to_s
          ty = 'string' if ty == ''
          mig.puts("        t.#{ty} :#{cmpn}")

          if ty == 'references'
            if cmp[:ref].nil?
              ns = ['empresa', 'ejercicio', 'divisa'].include?(cmpn) ? '' : namesp
              cl = ns + cmpn.capitalize
            else
              cl = cmp[:ref]
            end
            modelo_asoc.puts("  belongs_to :#{cmpn}, :class_name => '#{cl}'")
            cmpn << '_id'
          end

          cpk = cmp[:pk]
          if cpk != nil
            if cpk.class == Fixnum and pk[cpk].nil?
              pk[cpk] = cmpn
            else
              pk << cmpn
            end
          end

          if cmp[:manti].nil?
            if cmpn == 'codigo'
              cmp[:manti] = 5
            else
              case ty
                when 'boolean'
                  cmp[:manti] = 6
                when 'integer'
                  cmp[:manti] = 7
                when 'decimal'
                  cmp[:manti] = 7
                when 'date'
                  cmp[:manti] = 8
                when 'text'
                  cmp[:manti] = 50
                else
                  cmp[:manti] = 30
              end
            end
          end

          cmp[:decim] = 2 if cmp[:decim].nil? and ty == 'decimal'

          modelo.print("    #{cmpn}: {")
          if cmp[:manti].class == String
            modelo.print('manti: \'' + cmp[:manti] + '\'')
          else
            modelo.print('manti: ' + cmp[:manti].to_s)
          end
          if cmp[:decim]
            if cmp[:manti].class == String
              modelo.print('decim: \'' + cmp[:decim] + '\'')
            else
              modelo.print(', decim: ' + cmp[:decim].to_s)
            end
          end

          modelo.print(', pk: ' + cmp[:pk].to_s) if cmp[:pk]
          modelo.print(', nil: ' + cmp[:nil].to_s) if cmp[:nil]
          modelo.print(', ro: :' + cmp[:ro].to_s) if cmp[:ro]
          modelo.print(', signo: ' + cmp[:signo].to_s) if cmp[:signo]
          modelo.print(', req: ' + cmp[:req].to_s) if cmp[:req]
          modelo.print(', may: ' + cmp[:may].to_s) if cmp[:may]
          modelo.print(', rows: ' + cmp[:rows].to_s) if cmp[:rows]
          modelo.print(', code: ' + cmp[:code].to_s) if cmp[:code]
          modelo.print(', sel: ' + cmp[:sel].to_s) if cmp[:sel]
          modelo.print(', mask: \'' + cmp[:mask].to_s + '\'') if cmp[:mask]
          modelo.puts('},')

          if cmp[:tab] or cmp[:grid]
            controller.print("    #{cmpn}: {")
            controller.print('tab: \'' + cmp[:tab] + '\'') if cmp[:tab]
            if cmp[:grid]
              controller.print(', ') if cmp[:tab]
              controller.print('grid: ' + cmp[:grid].to_s)
            end
            controller.print(', size: ' + cmp[:size].to_s) if cmp[:size]
            controller.print(', gcols: ' + cmp[:gcols].to_s) if cmp[:gcols]
            controller.print(', hr: ' + cmp[:hr].to_s) if cmp[:hr]
            controller.puts('},')
          end
        }

        # Borrar la tabla y la migración (si procede)
        if tipo == :all
          begin
            ActiveRecord::Migration.drop_table(table)
          rescue
          end
          begin
            ActiveRecord::Migration.drop_table(tableh)
          rescue
          end
          begin
            version = Dir.glob("#{path}db/migrate/*_create_#{table}.rb")[0]
            us = version.rindex('/') + 1
            version = version[us..version.index('_', us)-1]
            ActiveRecord::Base.connection.execute("delete from schema_migrations where version = '#{version}'")
          rescue
          end
          `cd #{path}db/migrate; git rm *_create_#{table}.rb`
        end

        # Generar la migración
        mig.puts('    }')
        mig.puts
        mig.puts("    create_table(:#{table}) {|t| col.call(t)}")
        if pk != []
          vc = ''
          pk.each {|c| vc << "'#{c}'," unless c.nil?}
          vc.chop!
          mig.puts
          mig.puts("    add_index '#{table}', [#{vc}], unique: true, name: '#{table}_nimpk'")
        end
        if prop[:histo]
          mig.puts
          mig.puts("    create_table(:#{tableh}) {|t|")
          mig.puts('      col.call(t)')
          mig.puts('      t.integer :idid')
          mig.puts('      t.references :created_by')
          mig.puts('      t.timestamp :created_at')
          mig.puts('    }')
        end
        mig.puts('  end')
        mig.puts('=end') unless prop[:mig]
        mig.puts('end')
        mig.rewind
        File.write("#{path}db/migrate/#{ar[:version].strftime('%Y%m%d%H%M%S')}_create_#{table}.rb", mig.read) if tipo != 'ctr'
        ar[:version] += 1

        # Generar el modelo
        modelo.puts('  }')
        if modelo_asoc.pos != 0
          modelo.puts
          modelo_asoc.rewind
          modelo.puts(modelo_asoc.read)
        end
        modelo.puts
        modelo.puts('  after_save :control_histo') if prop[:histo]
        modelo.puts('  #after_initialize :ini_campos')
        modelo.puts
        modelo.puts('  #def ini_campos')
        modelo.puts('  #end')
        modelo.puts('end')
        modelo.puts
        modelo.puts("class #{namesp}#{modc} < ActiveRecord::Base")
        modelo.puts('  include Modelo')
        modelo.puts('end')
        if prop[:histo]
          modelo.puts
          modelo.puts("class #{namesp}H#{modc} < ActiveRecord::Base")
          modelo.puts("  belongs_to :created_by, :class_name => 'Usuario'")
          modelo.puts('end')
        end
        modelo.rewind

        File.write("#{path}app/models/#{modulo}/#{mod}.rb", modelo.read) if tipo != 'ctr'

        # Generar el controlador
        controller.puts('  }')
        controller.puts
        controller.puts('  #@hijos = []')
        controller.puts
        controller.puts('  #after_initialize :ini_campos_ctrl')
        controller.puts
        controller.puts('  #def ini_campos_ctrl')
        controller.puts('  #end')
        controller.puts('end')
        controller.puts
        controller.puts("class #{namesp}#{modcp}Mod < #{namesp}#{modc}")
        controller.puts('  include MantMod')
        controller.puts('end')
        controller.puts
        controller.puts("class #{namesp}#{modcp}Controller < ApplicationController")
        controller.puts('end')
        controller.rewind

        File.write("#{path}app/controllers/#{modulo}/#{modp}_controller.rb", controller.read)

        # Generar las vistas
        f = "#{path}app/views/#{modulo}/#{modp}"
        begin
          Dir.mkdir(f)
          #FileUtils.cp('modulos/nimbus-core/privado/views/index.html.erb', f)
          #FileUtils.cp('modulos/nimbus-core/privado/views/_form.html.erb', f)
        rescue
          #puts('  Ya existe el directorio de vistas. Se respetará su contenido')
        end

        # Generar las rutas
        if tipo != 'ctr'
          f = "#{path}config/routes.rb"
          r = File.read(f)
          cad = "'#{modp}'"
          if r.index(cad).nil?
            ifc = r.index(']')
            cad.insert(0, ',') if r[ifc - 1] != '['
            File.write(f, r.insert(ifc, cad))
          end
        end

      #rescue
        #puts "Error al procesar #{fic}"
      end
    end

    def busca_esquemas(path, modulo, ar)
      Dir.glob(path + '/*').each {|fic|
        next if File.directory?(fic)
        next unless fic.ends_with?('.def')

        trata_def(:new, fic, modulo, ar)
      }
    end

    ########### MAIN

    Dir.chdir(Rails.root)

    # Hash conteniendo todos los datos globales necesarios en las funciones auxiliares
    ar = {version: Time.now, loc: {}}

    locales = I18n.available_locales

    locales.each {|l|
      ls = l.to_s
      ar[:loc][l] = YAML.load(File.read("modulos/idiomas/config/locales/nimbus_#{ls}.yml"))
      ar[:loc][l][ls] ||= {}
    }

    f = args[:file]
    if f
      unless File.exists?(f)
        puts
        puts 'No existe el esquema'
        puts
        exit(1)
      end

      if args[:opt] != 'ctr' and args[:opt] != 'all'
        puts
        puts 'Especifica opción [ctr, all]'
        puts
        exit(1)
      end
      if f.start_with?('esquemas/') or f.start_with?('modulos/nimbus-core/')
        mod = ''
      elsif File.directory?(f[0..f.rindex('/')-1].gsub('esquemas', '.git'))
        mod = f[8..f.index('/', 8)-1]
      else
        mod = ''
      end
      trata_def(args[:opt], f, mod, ar)
    else
      busca_esquemas('esquemas', '', ar)
      Dir.glob('modulos/*/esquemas').each {|d|
        nmod = d[8..d.rindex('/')-1]
        mod = (nmod != 'nimbus-core' and File.directory?(d[0..d.rindex('/')] + '.git')) ? nmod : ''
        busca_esquemas(d, mod, ar)
      }
    end


    # Actualizar ficheros de idioma
    locales.each {|l|
      ar[:loc][l][l.to_s] = ar[:loc][l][l.to_s].sort.to_h # Ordenamos el locale en orden alfabético de claves
      File.write("modulos/idiomas/config/locales/nimbus_#{l.to_s}.yml", YAML.dump(ar[:loc][l]))
    }

    if args[:opt] != 'ctr'
      # Ejecutar migraciones
      Rake::Task['db:migrate'].invoke
    end
  end
end
