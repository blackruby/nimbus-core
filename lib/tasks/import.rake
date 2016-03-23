# Script para importar tablas en PostgreSQL y calcular columnas '_id'
#

namespace :nimbus do
  desc 'Importación de tablas en PostgreSQL y cálculo de las columnas _id'
  task :import, [:opt] => :environment do |task, args|

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
          @wh << "CAST(" if mod.columns_hash[k].type == :integer
          @wh << "split_part(#{@col},'~',#{@nk})"
          @wh << " AS INTEGER)" if mod.columns_hash[k].type == :integer
          @nk += 1
        end
      }
    end

    # Ejemplo de como tienen que quedar los updates para calcular id's
    #
    # update clientes set agente_id = (select agentes.id from agentes left outer join empresas on agentes.empresa_id=empresas.id where empresas.codigo=split_part(agente,'~',1) and agentes.codigo=split_part(agente,'~',2));

    ########### MAIN

    add = args[:opt]
    if add
      if add != 'add'
        puts
        puts 'Sintaxis: rake nimbus:import[add]'
        puts
        exit(1)
      else
        add = true
      end
    else
      add = false
    end

    puts 'Primera vuelta: Importación de tablas.'
    puts

    tab_update = {}
    drop_cols = ''

    ActiveRecord::Base.transaction do
      Dir.glob("/nimbus-import/#{Rails.app_class.to_s.split(':')[0].downcase}/*").each {|fic|
        next unless fic[-4..-1].downcase == ('.csv')

        head = nil
        File.foreach(fic) {|l| head = l.chomp; break}
        cmps = head.split(',')

        mod = fic.split('/')[-1][0..-5].downcase.capitalize.constantize
        tab = mod.table_name
        cmps_o = mod.column_names
        his = ActiveRecord::Base.const_defined?('H' + mod.to_s)

        puts mod.to_s

        ActiveRecord::Base.connection.execute("TRUNCATE #{his ? tab + ',h_' + tab : tab} RESTART IDENTITY") unless add

        add_cols = ''
        d_c = ''
        cols = []
        cmps.each {|c|
          unless cmps_o.include?(c)
            add_cols << "ADD COLUMN #{c} CHARACTER VARYING,"
            d_c << "DROP COLUMN #{c},"
            cols << c if cmps_o.include?(c + '_id')
          end
        }

        if add_cols != ''
          tab_update[mod] = cols unless cols.empty?
          drop_cols << "ALTER TABLE #{tab} #{d_c.chop};"
          ActiveRecord::Base.connection.execute("ALTER TABLE #{tab} " + add_cols.chop)
        end

        ActiveRecord::Base.connection.execute("COPY #{tab} (#{head}) FROM '#{fic}' CSV HEADER")
      }

      puts
      puts 'Segunda vuelta: Generación de Ids.'
      puts

      vuelta = 1
      otra_vuelta = true

      while otra_vuelta
        otra_vuelta = false
        tab_update.each {|mod, cols|
          tab = mod.table_name

          upd_glob = ''
          list_cmps = []
          cols.delete_if{|col|
            mod_col = mod.reflect_on_association(col.to_sym).options[:class_name].constantize
            tab_col = mod_col.table_name
            @wh = ''
            @upd = ''
            @nk = 1
            @deep = 0
            @col = tab + '.' + col
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
            puts mod.to_s + ' (' + list_cmps.join(',') + ')'

            ActiveRecord::Base.connection.execute("UPDATE #{tab} SET #{upd_glob.chop}")
          end

          otra_vuelta = true unless cols.empty?
        }

        vuelta += 1
        puts
      end

      puts 'Eliminación de columnas auxiliares.'

      ActiveRecord::Base.connection.execute("#{drop_cols}") unless drop_cols.empty?
    end
  end
end
