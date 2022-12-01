# Script para importar valores de configuración. opt puede ser h para ayuda ([h])
#
require 'csv'

namespace :nimbus do
  desc 'Importación de valores de configuración (poner rake importconf[h] para ayuda)'
  task :importconf, [:opt] => :environment do |_task, args|
    ActiveRecord::Base.logger.level = Logger::INFO

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
          @wh << "'#{@pka[@nk]}'"
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

    if args[:opt]
      puts
      puts 'Sintaxis: rake nimbus:importconf[h]'
      puts 
      puts '  Esta tarea procesa todos los ficheros con extensión "csv" que se encuentren'
      puts "  en la carpeta #{path_i}"
      puts '  El nombre de cada fichero es irrelevante.'
      puts '  La primera línea de cada fichero debe de contener los nombres de los campos'
      puts '  a importar. Si un campo es de tipo "id" se puede poner como nombre de la'
      puts '  columna el nombre sin "_id" y eso implicará que en la 3ª fila, en vez del'
      puts '  valor numérico del id, habrá que poner su clave primaria completa separada por "~".'
      puts '  La segunda línea contendrá los tipos de cada dato referenciado en la primera'
      puts '  línea (boolean, string, integer, decimal, date, time, id:Modelo). El caso'
      puts '  id:Modelo es para los campos "references" y hay que sustituir "Modelo" por'
      puts '  el modelo concreto (p.ej: id:Venta::Cliente).'
      puts '  La tercera línea contendrá los datos a importar.'
      puts '  Si el primer campo es "empresa", la importación se hará en el campo "param"'
      puts '  del modelo Empresa; si el primer campo es "Ejercicio", la importación se hará'
      puts '  sobre el campo "param" del modelo "Ejercicio"; si el primer campo no es ninguno'
      puts '  de los anteriores, se dará un error.'
      puts '  Según se vayan procesando los ficheros se pintará su nombre. Si hay algún'
      puts '  error, saldrá a continuación en rojo y se abortará la importación de ese fichero.'
      puts '  Si hay algún campo references que no se ha podido resolver saldrá el nombre del'
      puts '  campo en amarillo, se asignará un nil, pero se seguirá con la importación.'
      puts '  Si la importación ha acabado con éxito se pintará un "Ok" en verde.'
      puts
      exit 0
    end

    def pinta(msg, lvl = :f)
      # lvl => f: fallo, w: warning, o: Ok
      clr = {o: 32, f: 31, w: 33}
      print " \e[#{clr[lvl]}m#{msg}\e[0m"
      puts if lvl != :w
    end

    Dir.glob("#{path_i}/*").each {|fic|
      next unless fic[-4..-1].downcase == ('.csv')

      print fic.split('/')[-1]

      csv = CSV.read(fic)

      if csv.size != 3
        pinta 'Hay más de tres líneas.'
        next
      end

      if csv[0][0] == 'empresa'
        reg = Empresa.find_by codigo: csv[2][0]
        if reg.nil?
          pinta 'No existe la empresa'
          next
        end
      elsif csv[0][0] == 'ejercicio'
        em_ej = csv[2][0].split('~')
        reg = Ejercicio.ljoin(:empresa).where('ta.codigo = ? AND ejercicios.codigo = ?', em_ej[0], em_ej[1])[0]
        if reg.nil?
          pinta 'No existe el ejercicio'
          next
        end
      else
        pinta 'El primer campo no es ni empresa ni ejercicio'
        next
      end

      ok = true
      csv[1][1..-1].each.with_index(1) {|ty, i|
        k = csv[0][i].to_sym
        if csv[2][i].nil?
          reg.param[k] = nil
        elsif ty == 'boolean'
          reg.param[k] = csv[2][i].upcase == 'T' ? true : false
        elsif ty == 'string'
          reg.param[k] = csv[2][i]
        elsif ty == 'integer'
          reg.param[k] = csv[2][i].to_i
        elsif ty == 'decimal'
          reg.param[k] = csv[2][i].to_d
        elsif ty == 'date'
          reg.param[k] = csv[2][i].to_date
        elsif ty == 'time'
          reg.param[k] = csv[2][i].to_datetime
        elsif ty.starts_with?('id:')
          begin
            mod_col = ty[3..-1].constantize
            tab_col = mod_col.table_name
          rescue
            pinta "Modelo #{ty[3..-1]} desconocido"
            ok = false
            break
          end
          @wh = ''
          @upd = ''
          @nk = 0
          @deep = 0
          @pka = csv[2][i].split('~')
          @alias = 'a'
          pk_a(mod_col, 'a', 1)
          begin
            reg.param["#{k}_id".to_sym] = sql_exe("SELECT a.id FROM #{tab_col} a #{@upd} WHERE #{@wh}")[0]['id']
          rescue
            reg.param["#{k}_id".to_sym] = nil
            pinta k.to_s, :w
          end
        else
          pinta "tipo #{ty} desconocido"
          ok = false
          break
        end
      }

      if ok
        reg.save
        pinta 'Ok', :o
      end
    }
  end
end
