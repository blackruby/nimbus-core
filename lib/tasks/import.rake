# Script para importar tablas en PostgreSQL y calcular columnas '_id'
#

namespace :nimbus do
  desc 'Importación de tablas en PostgreSQL y cálculo de las columnas _id'
  task :import, [:opt, :op1, :op2] => :environment do |_task, args|

    # Método recursivo para calcular la clave primaria ampliada (pk_a)

    def pk_a(mod, tab, deep)
      @deep = deep if deep > @deep
      mod.pk.each {|k|
        if k.ends_with?('_id')
          modk = mod.reflect_on_association(k[0..-4].to_sym).options[:class_name].constantize
          tabk = modk.table_name
          @alias.next!
          @upd << " LEFT OUTER JOIN #{tabk} #{@alias} ON #{tab}.#{k} = #{@alias}.id"
          pk_a(modk, @alias.dup, deep + 1)
        else
          @wh << ' AND ' unless @wh.empty?
          @wh << "#{tab}.#{k}="
          @wh << "CAST(" if mod.columns_hash[k].type == :integer || mod.columns_hash[k].type == :decimal || mod.columns_hash[k].type == :time || mod.columns_hash[k].type == :boolean || mod.columns_hash[k].type == :date
          @wh << "split_part(#{@col},'~',#{@nk})"
          @wh << " AS INTEGER)" if mod.columns_hash[k].type == :integer
          @wh << " AS NUMERIC)" if mod.columns_hash[k].type == :decimal
          @wh << " AS TIME)" if mod.columns_hash[k].type == :time
          @wh << " AS BOOLEAN)" if mod.columns_hash[k].type == :boolean
          @wh << " AS DATE)" if mod.columns_hash[k].type == :date
          @nk += 1
        end
      }
    end

    # Ejemplo de como tienen que quedar los updates para calcular id's
    #
    # update clientes set agente_id = (select agentes.id from agentes left outer join empresas on agentes.empresa_id=empresas.id where empresas.codigo=split_part(agente,'~',1) and agentes.codigo=split_part(agente,'~',2));

    ########### MAIN

    path_i = "/nimbus-import/#{Nimbus::Gestion.downcase}"

    opt = args[:opt]
    #if !%w(c a m).include?(opt) || nh && nh != 'nh'
    if !%w(c a m).include?(opt) || ![nil, 'nh', 'np'].include?(args[:op1]) || ![nil, 'nh', 'np'].include?(args[:op2]) || args.to_a.size > 3
      puts
      puts 'Sintaxis: rake nimbus:import[c|a|m,nh|np,nh|np]'
      puts 
      puts '  Esta tarea procesa todos los ficheros con extensión "csv" que se encuentren'
      puts "  en la carpeta #{path_i}"
      puts '  El nombre de cada fichero tiene que coincidir con el modelo al que haga'
      puts '  referencia en minúsculas, y si pertenece a un módulo tiene que tener el'
      puts '  nombre del módulo como prefijo, más un underscore. ejs.:'
      puts '  pais.csv conta_cuenta.csv'
      puts '  La primera línea de cada fichero debe de contener los nombres de los campos'
      puts '  que se incluyen en cada fila del fichero. Si un campo es de tipo "id" se'
      puts '  puede poner como nombre de la columna el nombre sin "_id" y eso implicará'
      puts '  que en las filas de datos, en vez del valor numérico del id, habrá que poner'
      puts '  su clave primaria completa separada por "~".'
      puts '  Si se incluyen columnas que no existen, éstas se añadirán a la tabla para'
      puts '  poder usarlas en los archivos de postprocesado y luego serán eliminadas.'
      puts
      puts '  Las opciones disponibles son:'
      puts
      puts '  rake nimbus:import[c]'
      puts '    Crea en vacío cada una de las tablas y sus históricos y luego inserta.'
      puts '    Los campos references se calcularán tanto desde los registros ya existentes'
      puts '    como desde registros pertenecientes a otros ficheros importados en la'
      puts '    misma sesión.'
      puts
      puts '  rake nimbus:import[a]'
      puts '    Inserta nuevos registros. Si alguno ya existiera se producirá una excepción.'
      puts '    Los campos references se calcularán tanto desde los registros ya existentes'
      puts '    como desde registros pertenecientes a otros ficheros importados en la'
      puts '    misma sesión.'
      puts
      puts '  rake nimbus:import[m]'
      puts '    Inserta las filas nuevas y actualiza las que ya existan.'
      puts '    Los campos references (_id) sólo se calcularán con registros'
      puts '    ya existentes y no con otros declarados en la misma sesión.'
      puts '    Para esta opción es necesario una versión de postgres >= 9.5'
      puts
      puts '  Todas las opciones actualizan los históricos si existieran'
      puts '  salvo si ha especificado la opción "nh" como segundo argumento.'
      puts '  P.ej.: "rake nimbus:import[a,nh]" insertaría nuevos registros'
      puts '  pero no actualizaría sus históricos.'
      puts
      puts '  Si en cualquier módulo existiera un fichero llamado igual que el fichero'
      puts '  procesado pero con extensión ".rb" en la carpeta "db/import", éste será'
      puts '  ejecutado antes de borrar las columnas adicionales para poder hacer el'
      puts '  postprocesado que se desee.'
      puts '  El postprocesado no se realizará si se especifica la opción "np".'
      puts '  P.ej.: "rake nimbus:import[a,np]" insertaría nuevos registros'
      puts '  pero no postprocesaría las tablas.'
      puts
      puts '  Si no se desea actualizar históricos ni postprocesar habría que'
      puts '  especificar las dos opciones ("nh" y "np") en cualquier orden.'
      puts '  P.ej.: "rake nimbus:import[a,nh,np]"'
      puts
      puts '  Es importante notar que para especificar las opciones, éstas tienen'
      puts '  que ir entre corchetes, separadas por comas y sin ningún espacio en blanco.'
      puts
      exit 1
    end

    nh = args[:op1] == 'nh' || args[:op2] == 'nh'
    np = args[:op1] == 'np' || args[:op2] == 'np'

    if opt == 'm'
      version = sql_exe('select version()').pluck('version')[0].split[1].to_f
      if (version < 9.5)
        puts 'Para esta tarea se necesita una versión de PostgreSql >= 9.5'
        exit 1
      end
    end

    puts 'Primera vuelta: Importación de tablas.'
    puts

    tab_update = []
    drop_cols = ''
    ficheros_procesados = []

    ActiveRecord::Base.transaction do
      if opt == 'c'
        Dir.glob("#{path_i}/*.csv").each {|fic|
          mod = monta_modelo(fic)
          sql_exe("TRUNCATE #{mod.table_name} RESTART IDENTITY CASCADE")
          his = mod.modelo_histo
          sql_exe("TRUNCATE #{his.table_name} RESTART IDENTITY CASCADE") if his && !nh
        }
      end
      Dir.glob("#{path_i}/*").each {|fic|
        next unless fic[-4..-1].downcase == ('.csv')

        ficheros_procesados << fic.split('/')[-1][0..-5]

        head = nil
        File.foreach(fic) {|l| head = l.chomp; break}
        cmps = head.split(',')

        mod = monta_modelo(fic)

        cmps_o = mod.column_names

        puts mod.to_s

        tab_update << {mod: mod, cols_id: [], cols_csv: [], hay_id: cmps.include?('id')}
        tu = tab_update[-1]

        if opt == 'm'
          # Creamos una tabla auxilar para insertar los registros
          tab = "_tmp_#{mod.table_name}"
          #sql_exe("CREATE TEMP TABLE #{tab} (LIKE #{mod.table_name}) ON COMMIT DROP; ALTER TABLE #{tab} DROP COLUMN id")
          sql_exe("CREATE TEMP TABLE #{tab} (LIKE #{mod.table_name}) ON COMMIT DROP")
          sql_exe("ALTER TABLE #{tab} DROP COLUMN id") unless tu[:hay_id]
        else
          tab = mod.table_name
          tu[:last_id] = sql_exe("select last_value from #{tab}_id_seq").values[0][0]
        end

        tu[:tab] = tab

        add_cols = ''
        d_c = ''
        cmps.each {|c|
          if cmps_o.include?(c)
            tu[:cols_csv] << c
          else
            add_cols << "ADD COLUMN #{c} CHARACTER VARYING,"
            d_c << "DROP COLUMN #{c},"
          end
          if cmps_o.include?("#{c}_id")
            mod_col = mod.reflect_on_association(c.to_sym).options[:class_name].constantize
            tu[:cols_id] << c unless mod_col.pk.empty?
            tu[:cols_csv] << "#{c}_id"
          end
        }

        if add_cols != ''
          drop_cols << "ALTER TABLE #{tab} #{d_c.chop};" if opt != 'm'
          sql_exe("ALTER TABLE #{tab} " + add_cols.chop)
        end

        sql_copy("COPY #{tab} (#{head}) FROM '#{fic}' CSV HEADER")
      }

      puts
      puts 'Segunda vuelta: Generación de Ids.'
      puts

      vuelta = 1
      otra_vuelta = true

      while otra_vuelta
        otra_vuelta = false
        tab_update.each {|t|
          upd_glob = ''
          list_cmps = []
          t[:cols_id].delete_if{|col|
            mod_col = t[:mod].reflect_on_association(col.to_sym).options[:class_name].constantize
            tab_col = mod_col.table_name
            @wh = ''
            @upd = ''
            @nk = 1
            @deep = 0
            @col = t[:tab] + '.' + col
            @alias = 'a'
            pk_a(mod_col, 'a', 1)
            if @deep <= vuelta
              upd_glob << "#{col}_id=COALESCE(#{col}_id,(SELECT a.id FROM #{tab_col} a #{@upd} WHERE #{@wh})),"
              list_cmps << col
              true  # Para borrar la columna (en el delete_if)
            else
              false  # Para NO borrar la columna (en el delete_if)
            end
          }

          if upd_glob != ''
            puts t[:mod].to_s + ' (' + list_cmps.join(',') + ')'

            sql_exe("UPDATE #{t[:tab]} SET #{upd_glob.chop}")
          end

          otra_vuelta = true unless t[:cols_id].empty?
        }

        vuelta += 1
        puts
      end

      # Copiar los registros de las tablas temporales a las originales si opt es 'm'
      if opt == 'm'
        puts 'Actualizando registros desde las tablas temporales.'
        puts
        tab_update.each {|t|
          puts t[:mod].table_name
          cols = t[:cols_csv].join(',')
          t[:ids] = sql_exe(%Q{
            INSERT INTO #{t[:mod].table_name} (#{cols})
            SELECT #{cols} FROM #{t[:tab]}
            ON CONFLICT (#{t[:hay_id] ? 'id' : t[:mod].pk.join(',')}) DO UPDATE SET (#{cols}) = (#{t[:cols_csv].map{|c| 'EXCLUDED.' + c}.join(',')})
            RETURNING id
          }).pluck('id')
        }
        puts
      end

      unless np
        puts 'Postprocesado de tablas.'
        Dir.glob("**/db/import/{#{ficheros_procesados.join(',')}}.rb").each {|f|
          puts f
          load(f)
        }
      end

      if drop_cols.present?
        puts
        puts 'Eliminación de columnas auxiliares.'

        sql_exe("#{drop_cols}")
      end

      unless nh
        # Actualizar históricos
        puts
        puts 'Actualizando históricos'
        ahora = Nimbus.now
        tab_update.each {|t|
          his = t[:mod].modelo_histo
          next unless his
          puts his.table_name
          # Añado el id 0 por si la lista de id's está vacía (para que no dé un error postgres)
          wh = opt == 'm' ? "IN (#{([0] + t[:ids].to_a).join(',')})" : ">= #{t[:last_id]}"
          cols = t[:mod].column_names.join(',')
          sql_exe %Q(
            INSERT INTO #{his.table_name}
            (created_by_id, created_at, id#{cols})
            SELECT 1, '#{ahora}', #{cols}
            FROM #{t[:mod].table_name}
            WHERE id #{wh}
          )
        }
      end
    end
  end
end

def monta_modelo(fic)
  name = fic.split('/')[-1][0..-5].downcase
  name_a = name.split('_')
  if name_a.size == 1 || name_a[0] == 'h'
    name[2..-1].camelize.constantize if name_a[0] == 'h' # Para precargar la clase del modelo principal si es un histórico
    mod = name.camelize.constantize
  else
    "#{name_a[0].capitalize}::#{name_a[2..-1].join('_').camelize}".constantize if name_a[1] == 'h' # Para precargar la clase del modelo principal si es un histórico
    mod = "#{name_a[0].capitalize}::#{name_a[1..-1].join('_').camelize}".constantize
  end
  mod
end