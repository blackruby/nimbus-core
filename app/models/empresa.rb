unless Nimbus::Config[:excluir_empresas]

class Empresa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 5},
    nombre: {manti: 60},
    nombre_comercial: {manti: 60},
    cif: {manti: 10},
    direccion: {manti: 70},
    cod_postal: {manti: 15},
    poblacion: {manti: 50},
    provincia: {manti: 20},
    pais: {},
    telefono: {manti: 30},
    fax: {manti: 30},
    email: {manti: 70},
    web: {manti: 70},
    param: {},
  }

  belongs_to :pais, :class_name => 'Pais'

  serialize :param

  after_initialize :ini_campos

  def ini_campos
    self.param ||= {} if self.respond_to? :param
  end

  # Obtiene todos los modelos que dependen de "empresa"
  def self.modelos(met: :empresa_path, sort: :niv)
    mods = []
    Dir.glob(['modulos/*/app/models/**/*.rb', 'app/models/*.rb']) {|f|
      next if f[-7, 4] == '_add'
      begin
        fa = f.split('/')
        modulo = fa[-2] == 'models' ? '' : "#{fa[-2].capitalize}::"
        modelo = "#{modulo}#{fa[-1][0..-4].camelize}".constantize
        next unless modelo.respond_to? met
        if modelo.view?
          tipo = 'V'
        elsif modelo.superclass == ActiveRecord::Base
          tipo = ' '
        else
          tipo = '?'
        end
        mods << [modelo, modelo.method(met).call.split('.').size, tipo] if tipo == ' ' || sort != :niv
      rescue => exception
      end
    }
    mods.sort! {|a, b|
      if sort == :niv
        tam = b[1] <=> a[1]
        tam == 0 ? a[0].to_s <=> b[0].to_s : tam
      else
        a[0].to_s <=> b[0].to_s
      end
    }
    block_given? ? mods.each{|m| yield m[0], m[1], m[2]} : mods
  end

  def self.deep_data(id:, met: :empresa_path)
    cid = met == :empresa_path ? 'empresa_id' : 'ejercicio_id'
    modelos(met: met) {|mod, niv|
      modh = mod.modelo_histo
      if mod.method(met).call.empty?
        sql = mod
        sqlh = modh if modh
        te = ''
      else
        sql = mod.ljoin(mod.method(met).call + '(e)')
        sqlh = modh.ljoin(mod.method(met).call + '(e)') if modh
        te = 'e.'
      end
      sql = sql.where("#{te}#{cid} = ?", id)
      if modh
        yield mod, niv, sql, sqlh.where("#{te}#{cid} = ?", id)
      else
        yield mod, niv, sql
      end
    }
  end
end

class Empresa
  include Modelo
end

class HEmpresa < Empresa
  include Historico
end

Nimbus.load_adds __FILE__

end
