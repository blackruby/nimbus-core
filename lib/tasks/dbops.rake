namespace :nimbus do
  desc 'Info/Dump/Delete sobre tablas dependientes de un modelo'
  task :dbops, [:mod, :opt, :id, :dir] => :environment do |_task, args|
    arl = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = Logger::INFO

    puts

    modelo_s = args[:mod]
    opt = args[:opt]
    id = args[:id].to_i
    if modelo_s.nil? || !%w(info count dump del).include?(opt) || opt != 'info' && id == 0 || opt == 'dump' && args[:dir].nil?
      puts 'Sintaxis: rake nimbus:dbops[mod,opt,id,dir]'
      puts 
      puts '  Esta tarea realiza diferentes acciones relativas a las tablas que dependen de un modelo'
      puts
      puts '  Las opciones disponibles son:'
      puts
      puts '  mod: Nombre del modelo padre (p.ej.: Empresa, Ejercicio, Bodega, Venta::Cliente, ...)'
      puts '  opt: Puede valer:'
      puts '       info:  Muestra todos los modelos que dependen del modelo elegido en la opción'
      puts '              anterior. Saca tres columnas de información:'
      puts '              Nivel: Es el número de ascendientes hasta llegar al modelo padre.'
      puts '              Tipo: Hay tres posibles valores:'
      puts '                    Vacío: Es un modelo normal.'
      puts '                    V: Es una vista.'
      puts '                    ?: Desconocido.'
      puts '              Modelo: Muestra el nombre del modelo.'
      puts '       count: Muestra los modelos que dependen del modelo padre y que tengan registros.'
      puts '              Saca cuatro columnas de información: Nivel, Nº de registros de la tabla,'
      puts '              Nº de registros del histórico (si hubiera) y nombre del modelo.'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id del modelo padre del que queremos información.'
      puts '       dump:  Vuelca todos los registros de cada modelo en archivos CSV dentro del'
      puts '              directorio especificado en el último parámetro. El nombre de cada archivo'
      puts '              es el adecuado para poder importarlo después con "rake nimbus:import[a,nh,np]"'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id del modelo padre del que queremos el volcado.'
      puts '       del:   Borra todos los registros de cada modelo que dependan del modelo padre.'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id del modelo padre del que queremos el borrado.'
      puts '              Esta opción NO borra el propio registro del modelo padre seleccionado.'
      puts '  id:  Indica el id del modelo padre que queremos tratar.'
      puts '  dir: Indica el directoro donde se volcarán los archivos CSV cuando se selecciona la'
      puts '       opción "dump". El directorio debe de tener "path absoluto" (empezar por "/") y'
      puts '       tener permisos "rwx" para el usuario postgres.'
      puts
      puts 'Ejemplos:'
      puts '  rake nimbus:dbops[Empresa,info] -> Muestra información de los modelos que dependen de Empresa.'
      puts '  rake nimbus:dbops[Ejercicio,count,4] -> Muestra información del número de registros de cada modelo'
      puts '                                          que depende del ejercicio con id = 4.'
      puts '  rake nimbus:dbops[Bodega,dump,1,/tmp/nimbus] -> Vuelca en la carpeta /tmp/nimbus los registros de'
      puts '                                                  todos los modelos que dependen de la bodega con'
      puts '                                                  id = 1. Los archivos generados se podrían volver' 
      puts '                                                  a incorporar con "rake nimbus:import[a,nh,np]"' 
      puts '  rake nimbus:dbops[Venta::Cliente,del,4] -> Borra los registros de cada modelo que dependa del'
      puts '                                             cliente con id = 4.'
      puts
      puts '  Es importante notar que para especificar las opciones, éstas tienen'
      puts '  que ir entre corchetes, separadas por comas y sin ningún espacio en blanco.'
      puts
      exit 1
    end

    modelo_s = modelo_s.downcase.split('::').map{|c| c.capitalize}.join('::') unless modelo_s[0] == modelo_s[0].upcase
    begin
      modelo = modelo_s.constantize
    rescue
      puts "No existe el modelo: #{modelo_s}"
      puts
      exit
    end

    campo = modelo_s.split('::')[-1].downcase
    campo_id = "#{campo}_id"

    mod_path = -> (cl) {
      cad_emp = []
      loop {
        if cl.pk.include?(campo_id) && cl.reflect_on_association(campo).class_name == modelo_s
          return cad_emp.join('.')
        elsif cl.pk[0] and cl.pk[0].ends_with?('_id')
          cad_emp << cl.pk[0][0..-4]
          cl = cl.reflect_on_association(cl.pk[0][0..-4].to_sym).class_name.constantize
        else
          return nil
        end
      }
    }

    mods = []
    Dir.glob(Nimbus::ModulosCliGlob + '/app/models/**/*.rb') {|f|
      next if f[-7, 4] == '_add'
      begin
        fa = f.split('/')
        modulo = fa[-2] == 'models' ? '' : "#{fa[-2].capitalize}::"
        mod = "#{modulo}#{fa[-1][0..-4].camelize}".constantize
        path = mod_path[mod]
        next if path.nil?
        if mod.view?
          tipo = 'V'
        elsif mod.superclass == ActiveRecord::Base
          tipo = ' '
        else
          tipo = '?'
        end

        if tipo == ' ' || opt == 'info'
          mods << {mod: mod, path: path, niv: path.split('.').size, tipo: tipo}

          if opt != 'info'
            modh = mod.modelo_histo
            sqlh = nil
            if path.empty?
              sql = mod
              sqlh = modh if modh
              te = ''
            else
              sql = mod.ljoin(path + '(e)')
              sqlh = modh.ljoin(path + '(e)') if modh
              te = 'e.'
            end
            
            mods[-1][:sql] = sql.where("#{te}#{campo_id} = ?", id)
            mods[-1][:sqlh] = sqlh.where("#{te}#{campo_id} = ?", id) if sqlh
          end
        end
      rescue => exception
      end
    }

    mods.sort! {|a, b|
      if opt != 'info'
        tam = b[:niv] <=> a[:niv]
        tam == 0 ? a[:mod].to_s <=> b[:mod].to_s : tam
      else
        a[:mod].to_s <=> b[:mod].to_s
      end
    }

    if opt != 'info'
      reg = modelo.mselect(modelo.auto_comp_mselect).where("#{modelo.table_name}.id = ?", id)[0]
      if reg
        puts "\e[1m#{campo.capitalize}:\e[0m #{reg.auto_comp_value(:dbops)}"
      else
        print "\e[1m#{campo.capitalize}:\e[0m No existe el regitro. ¿Desea continuar? (s/n): "
        if STDIN.gets.chomp.upcase != 'S'
          puts 'Proceso abortado.'
          exit
        end
      end

      puts
    end

    case opt
      when 'info'
        puts "Nivel Tipo Modelos dependientes de #{modelo_s}"
        puts '-' * 75
        mods.each {|m| puts format('%5d   %s  %s', m[:niv], m[:tipo], m[:mod])}
      when 'count'
        puts 'Nivel Nº_Registros Nº_Registros_h Modelo'
        puts '-' * 80
        #Empresa.deep_data(id: id, met: met) {|m, niv, sql, sqlh|
        mods.each {|m|
          n = m[:sql].count
          nh = m[:sqlh] ? m[:sqlh].count : 0
          puts format('%5d %12s %14s %s', m[:niv], n.to_sep_mil, (m[:sqlh] ? nh.to_sep_mil : '---'), m[:mod]) if n > 0 || nh > 0
        }
      else
        if opt == 'del'
          print 'Esta opción borrará todos los datos de la empresa/ejercicio seleccionado. ¿Desea continuar? (s/n): '
          if STDIN.gets.chomp.upcase != 'S'
            puts 'Proceso abortado.'
            exit
          end
        end

        puts 'Nivel Nº_Registros Modelo'
        puts '-' * 77
        mods.each {|m|
          [:sql, :sqlh].each {|sq|
            n = m[sq] ? m[sq].count : 0
            if n > 0
              mod = sq == :sql ? m[:mod].to_s : m[:mod].modelo_histo.to_s
              print format('%5d %12s %-50s ', m[:niv], n.to_sep_mil, mod)
              if opt == 'dump'
                fic = mod.split('::').map(&:underscore).join('_')
                sql_copy tab: "(#{m[sq].to_sql})", to: "#{args[:dir]}/#{fic}.csv", fin: "(format 'csv', header true)"
                puts 'Volcado'
              else
                m[sq].delete_all
                puts 'Borrado'
              end
            end
          }
        }
    end
    ActiveRecord::Base.logger.level = arl
  end
end