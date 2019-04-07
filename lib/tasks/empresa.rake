# Script para hacer operaciones con empresas
#

namespace :nimbus do
  desc 'Info/Dump/Delete sobre una empresa'
  task :empeje, [:emej, :opt, :id, :dir] => :environment do |_task, args|
    puts

    emej = args[:emej]
    opt = args[:opt]
    id = args[:id].to_i
    if !%w(e j).include?(emej) || !%w(info count dump del).include?(opt) || opt != 'info' && id == 0 || opt == 'dump' && args[:dir].nil?
      puts 'Sintaxis: rake nimbus:empresa[emej,opt,id,dir]'
      puts 
      puts '  Esta tarea realiza diferentes acciones relativas a los modelos que dependen'
      puts '  de Empresa o  de Ejercicio'
      puts
      puts '  Las opciones disponibles son:'
      puts
      puts '  emej: Puede valer "e" o "j" dependiendo si queremos tratar con Empresa o Ejercicio.' 
      puts '  opt: Puede valer:'
      puts '       info:  Muestra todos los modelos que dependen de Empresa/Ejercicio en función'
      puts '              de lo elegido en la opción anterior. Saca tres columnas de información:'
      puts '              Nivel: Es el número de ascendientes hasta llegar a Empresa/Ejercicio.'
      puts '              Tipo: Hay tres posibles valores:'
      puts '                    Vacío: Es un modelo normal.'
      puts '                    V: Es una vista.'
      puts '                    ?: Desconocido.'
      puts '              Modelo: Muestra el nombre del modelo.'
      puts '       count: Muestra los modelos que dependen de Empresa/Ejercicio en función de lo'
      puts '              elegido en la opción anterior y que tengan registros. Saca cuatro'
      puts '              columnas de información: Nivel, Nº de registros de la tabla, Nº de'
      puts '              registros del histórico (si hubiera) y nombre del modelo.'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id de la empresa/ejercicio de la que queremos información.'
      puts '       dump:  Vuelca todos los registros de cada modelo en archivos CSV dentro del'
      puts '              directorio especificado en el último parámetro. Los nombres de cada'
      puts '              archivo es el adecuado para poder importarlo después con "rake nimbus:import"'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id de la empresa/ejercicio de la que queremos el volcado.'
      puts '       del:   Borra todos los registros de cada modelo.'
      puts '              Para esta opción es necesario especificar el siguiente parámetro (id)'
      puts '              que indicará el id de la empresa/ejercicio de la que queremos el borrado.'
      puts '              Esta opción NO borra el propio registro de la empresa/ejercicio seleccionado.'
      puts '  id:  Indica el id de la empresa/ejercicio que queremos tratar.'
      puts '  dir: Indica el directoro donde se volcarán los archivos CSV cuando se selecciona la'
      puts '       opción "dump". El directorio debe de tener "path absoluto" (empezar por "/") y'
      puts '       tener permisos "rwx" para el usuario postgres.'
      puts
      puts 'Ejemplos:'
      puts '  rake nimbus:empeje[e,info] -> Muestra información de los modelos que dependen de Empresa.'
      puts '  rake nimbus:empeje[j,count,4] -> Muestra información del número de registros de cada modelo'
      puts '                                   que depende del ejercicio con id = 4.'
      puts '  rake nimbus:empeje[e,dump,1,/tmp/nimbus] -> Vuelca en la carpeta /tmp/nimbus los registros de'
      puts '                                              todos los modelos que dependen de la empresa con'
      puts '                                              id = 1. Los archivos generados se podrían volver' 
      puts '                                              a incorporar con "rake nimbus:import[a,nh,np]"' 
      puts '  rake nimbus:empeje[j,del,4] -> Borra los registros de cada modelo que dependa del ejercicio'
      puts '                                 con id = 4.'
      puts
      puts '  Es importante notar que para especificar las opciones, éstas tienen'
      puts '  que ir entre corchetes, separadas por comas y sin ningún espacio en blanco.'
      puts
      exit 1
    end

    if emej == 'e'
      mod = Empresa
      met = :empresa_path
    else
      mod = Ejercicio
      met = :ejercicio_path
    end

    if opt != 'info'
      reg = mod.find_by id: id
      if emej == 'e'
        puts reg ? "\e[1mEmpresa:\e[0m (#{reg.codigo}) #{reg.nombre}" : "La empresa no existe"
      else
        puts reg ? "\e[1mEmpresa:\e[0m (#{reg.empresa.codigo}) #{reg.empresa.nombre} \e[1mEjercicio:\e[0m (#{reg.codigo}) #{reg.descripcion}" : "El ejercicio no existe"
      end
      puts
      exit if reg.nil?
    end

    def pinta_info(mod, niv, n, sql, dir, op)
      print format('%5d %12s %-50s ', niv, n.to_texto, mod)
      fic = mod.to_s.split('::').map(&:underscore).join('_')
      case op
        when 'Volcado'
          sql_exe %Q(copy (#{sql.to_sql}) to '#{dir}/#{fic}.csv' (format 'csv', header true))
        when 'Borrado'
          sql.delete_all
      end
      puts op
    end

    def dump_del(op, id, met, dir = nil)
      puts 'Nivel Nº_Registros Modelo'
      puts '-' * 77
      Empresa.deep_data(id: id, met: met) {|m, niv, sql, sqlh|
        n = sql.count
        pinta_info(m, niv, n, sql, dir, op) if n > 0
        n = sqlh ? sqlh.count : 0
        pinta_info(m.modelo_histo, niv, n, sqlh, dir, op) if n > 0
      }
    end

    case opt
      when 'info'
        puts "Nivel Tipo Modelos dependientes de #{mod}"
        puts '-' * 75
        Empresa.modelos(met: met, sort: :alpha) {|m, n, t| puts format('%5d   %s  %s', n, t, m)}
      when 'count'
        puts 'Nivel Nº_Registros Nº_Registros_h Modelo'
        puts '-' * 80
        Empresa.deep_data(id: id, met: met) {|m, niv, sql, sqlh|
          n = sql.count
          nh = sqlh ? sqlh.count : 0
          puts format('%5d %12s %14s %s', niv, sql.count.to_texto, (sqlh ? nh.to_texto : '---'), m) if n > 0 || nh > 0
        }
      when 'dump'
        dump_del('Volcado', id, met, args[:dir])
      when 'del'
        print 'Esta opción borrará todos los datos de la empresa/ejercicio seleccionado. ¿Desea continuar? (s/n): '
        if STDIN.gets.chomp.upcase == 'S'
          puts
          dump_del('Borrado', id, met)
        else
          puts 'Proceso abortado.'
        end
    end
  end
end