class Contador < ActiveRecord::Base
# Método para asignar contadores

  def self.get(mod, cmp, h={})
    fc = self.find_by(modelo: mod.to_s, campo: cmp.to_s, clave: Hash[h.sort].to_s)
    fc ? fc.valor : 0
  end

  def self.set(mod, cmp, val, h={})
    begin
      fc = self.find_or_create_by(modelo: mod.to_s, campo: cmp.to_s, clave: Hash[h.sort].to_s)
    rescue ActiveRecord::RecordNotUnique
      retry
    end
    fc.valor = val
    fc.save
  end

  def self.next(mod, cmp, h={})
    cmp = cmp.to_s
    h = Hash[h.sort]
    tab = mod.table_name
    filt = ''
    ord = ''
    h.each{|k, v|
      filt << " and #{k}='#{v}'"
      ord << "#{k},"
    }
    ord << cmp

    begin
      fc = self.lock.find_or_create_by(modelo: mod.to_s, campo: cmp, clave: h.to_s) {|f| f.valor = 0}
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    fc.lock! if fc.valor == 0 # Bloquear en el caso de que haya sido creada la ficha, ya que en ese caso no se aplica el lock anterior

    c = fc.valor + 1
    fc.valor = ActiveRecord::Base.connection.execute("(select #{c} co where not exists(select 1 from #{tab} where #{cmp}=#{c} #{filt})) union (select #{cmp}+1 co from #{tab} t1 where #{cmp}>=#{c} #{filt} and not exists(select 1 from #{tab} where #{cmp}=t1.#{cmp}+1 #{filt}) order by #{ord} limit 1)")[0]['co'].to_i
    fc.save
    return(fc.valor)
  end
end
