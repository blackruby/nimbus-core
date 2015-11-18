class Contador < ActiveRecord::Base
# Método para asignar contadores

  def self.next(mod, cmp, h={})
    cmp = cmp.to_s
    tab = mod.table_name
    filt = ''
    ord = ''
    clv = ''
    h.each{|k, v|
      filt << " and #{k}='#{v}'"
      ord << "#{k},"
      clv << "#{v}~"
    }
    ord << cmp
    clv.chop!

    fc = self.find_by modelo: mod.to_s, campo: cmp, clave: clv
    fc = self.create(modelo: mod.to_s, campo: cmp, clave: clv, valor: 0) unless fc
    c = fc.valor + 1
    fc.valor = ActiveRecord::Base.connection.execute("(select #{c} co where not exists(select 1 from #{tab} where #{cmp}=#{c} #{filt})) union (select #{cmp}+1 co from #{tab} t1 where #{cmp}>=#{c} #{filt} and not exists(select 1 from #{tab} where #{cmp}=t1.#{cmp}+1 #{filt}) order by #{ord} limit 1)")[0]['co'].to_i
    fc.save
    return(fc.valor)
  end
end
