# Script para crear un nuevo modelo y el mantenimiento
# asociado. Se basa en las especificaciones dadas
# en nimbus/esquemas/

namespace :nimbus do
  desc 'Generar mantenimientos a partir de los esquemas definidos'
  task :genmant, [:file] => :environment do |task, args|
    def trata_def(tipo, fic, modulo, ar)
      mod = Pathname(fic).basename.to_s[0..-5]
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

      return if tipo == :new and File.exists?("app/controllers/#{modulo}/#{modp}_controller.rb")

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

        cont = 0
        refs = []
        cmps.each { |cmp|
          cmpn = cmp[:cmp]

          # Actualizar el locale
          ar[:loc].each_key {|l|
            ls = l.to_s
            if cmp[:locale] and cmp[:locale][l]
              if ar[:loc][l][ls][cmpn] and ar[:loc][l][ls][cmpn][0] != '#'
                puts '  Ya existe la clave ' + cmpn + ' en el locale "' + ls + '"'
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

          manti = 'manti: '
          if cmpn == 'codigo'
            manti << '5'
          else
            case ty
              when 'boolean'
                manti << '6'
              when 'integer'
                manti << '7'
              when 'decimal'
                manti << '7, decim: 2'
              when 'date'
                manti << '8'
              when 'text'
                manti << '50'
              else
                manti << '30'
            end
          end

          modelo.puts("    #{cmpn}: {#{manti}#{cmp[:pk] ? ', pk: ' + cmp[:pk].to_s : ''}},")

          controller.puts("    #{cmpn}: {div: 'g1'#{cont<5 ? ', grid:{}' : ''}},") unless ['empresa_id', 'ejercicio_id'].include?(cmpn)
          cont += 1
        }

        # Borrar la tabla y la migración (si procede)
        if tipo == :reg
          begin
            ActiveRecord::Migration.drop_table(table)
          rescue
          end
          begin
            ActiveRecord::Migration.drop_table(tableh)
          rescue
          end
          `rm -f db/migrate/*_create_#{table}.rb`
          `rm -f nimbus/migrate/#{modulo}/*_create_#{table}.rb`
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
          mig.puts("    add_index '#{table}', [#{vc}], unique: true")
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
        File.write("db/migrate/#{ar[:version].strftime('%Y%m%d%H%M%S')}_create_#{table}.rb", mig.read)
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

        File.write("app/models/#{modulo}/#{mod}.rb", modelo.read)

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

        File.write("app/controllers/#{modulo}/#{modp}_controller.rb", controller.read)

        # Generar las vistas
        f = "app/views/#{modulo}/#{modp}"
        begin
          Dir.mkdir(f)
          #FileUtils.cp('app/views/shared/new.html.erb', f)
          #FileUtils.cp('app/views/shared/edit.html.erb', f)
          FileUtils.cp('nimbus/views/index.html.erb', f)
          FileUtils.cp('nimbus/views/_form.html.erb', f)
        rescue
          puts('  Ya existe el directorio de vistas. Se respetará su contenido')
        end

        # Generar las rutas
        f = "nimbus/rutas/#{modulo == '' ? 'nimbus' : modulo}.rb"
        r = File.read(f)
        cad = "'#{modp}'"
        if r.index(cad).nil?
          ifc = r.index(']')
          cad.insert(0, ',') if r[ifc - 1] != '['
          File.write(f, r.insert(ifc, cad))
        end

        ar[:modulos] << modulo unless ar[:modulos].include?(modulo)
      #rescue
        #puts "Error al procesar #{fic}"
      end
    end

    def busca_esquemas(path, modulo, ar)
      Dir.glob(path + '/*').each {|fic|
        ficb = Pathname(fic).basename.to_s

        if File.directory?(fic)
          next if modulo != ''

          # Crear, si es necesario las carpetas asociadas al módulo
          ['app/controllers/', 'app/views/', 'nimbus/migrate/'].each {|f|
            f << ficb
            Dir.mkdir(f) unless File.exists?(f)
          }
          f = "app/models/#{ficb}"
          unless File.exists?(f)
            Dir.mkdir(f)
            File.write(f + '.rb', "module #{ficb.capitalize}\n  def self.table_name_prefix\n    '#{ficb}_'\n  end\nend\n")
          end

          fi = "nimbus/rutas/#{ficb}.rb"
          unless File.exists?(fi)
            File.open(fi, 'w') { |f|
              f.puts "modulo = '#{ficb}'"
              f.puts
              f.puts "[].each{|c|"
              f.puts '  get "#{modulo}/#{c}" => "#{modulo}/#{c}#index"'
              f.puts '  get "#{modulo}/#{c}/new" => "#{modulo}/#{c}#new"'
              f.puts '  get "#{modulo}/#{c}/:id/edit" => "#{modulo}/#{c}#edit"'
              f.puts "  ['validar', 'validar_cell', 'list', 'grabar', 'borrar', 'cancelar'].each {|m|"
              f.puts '    post "#{modulo}/#{c}/#{m}" => "#{modulo}/#{c}##{m}"'
              f.puts '  }'
              f.puts '}'
            }
          end

          busca_esquemas(fic, ficb, ar)
        end

        next unless fic.ends_with?('.def')

        trata_def(:new, fic, modulo, ar)
      }
    end

    ########### MAIN

    Dir.chdir(Rails.root)

    # Hash conteniendo todos los datos globales necesarios en las funciones auxiliares
    ar = {modulos: [], version: Time.now, loc: {}}

    locales = I18n.available_locales

    locales.each {|l|
      ls = l.to_s
      ar[:loc][l] = YAML.load(File.read("modulos/idiomas/config/locales/nimbus_#{ls}.yml"))
      ar[:loc][l][ls] ||= {}
    }

    f = args[:file]
    if f
      f << '.def' unless f.ends_with?('.def')
      trata_def(:reg, "nimbus/esquemas/#{f}", f.include?('/') ? f.split('/')[0] : '', ar)
    else
      busca_esquemas('nimbus/esquemas', '', ar)
    end


    # Actualizar ficheros de idioma
    locales.each {|l|
      ar[:loc][l][l.to_s] = ar[:loc][l][l.to_s].sort.to_h # Ordenamos el locale en orden alfabético de claves
      File.write("config/locales/nimbus_#{l.to_s}.yml", YAML.dump(ar[:loc][l]))
    }

    # Ejecutar migraciones
    Rake::Task['db:migrate'].invoke

    # Mover migraciones a sus carpetas de módulos
    ar[:modulos].each {|m|
      `mv db/migrate/*_#{m}_* nimbus/migrate/#{m} >/dev/null 2>&1`
    }
  end
end
