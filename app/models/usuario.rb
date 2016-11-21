class Usuario < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 15},
    nombre: {},
    email: {},
    password_salt: {},
    password_hash: {},
    password_fec_mod: {},
    admin: {},
    timeout: {manti: 6, nil: true},
    empresa_def_id: {ro: :all},
    ejercicio_def_id: {ro: :all},
    pref: {},
  }

  serialize :pref

  belongs_to :empresa_def, :class_name => 'Empresa'
  belongs_to :ejercicio_def, :class_name => 'Ejercicio'

  after_save :control_histo
  after_initialize :ini_campos

  def ini_campos
    self.pref ||= {}
    self.pref[:permisos] ||= {emp: [], prf: [], usu: [], ctr: {}}
  end

  def self.load_menu
    hmenu = YAML.load(File.read('modulos/nimbus-core/menu.yml'))
    Dir.glob('modulos/*/menu.yml').each {|m|
      next if m == 'modulos/nimbus-core/menu.yml'
      hmenu.merge!(YAML.load(File.read(m)))
    }
    hmenu.deep_merge!(YAML.load(File.read('menu.yml'))) if File.exists?('menu.yml')

    return hmenu
  end

  def self.asigna_permiso(ctrl, st, emp, dest)
    ctrl = URI(ctrl).path[1..-1]

    if dest[ctrl]
      emp.each_with_index {|e, i|
        next if e[0] == -1
        if dest[ctrl][e[0]]
          dest[ctrl][e[0]] = st[i] if 'pbcx'.index(st[i]) < 'pbcx'.index(dest[ctrl][e[0]])
        else
          dest[ctrl][e[0]] = st[i] if st[i] != 'x'
        end
      }
    else
      ste = {}
      emp.each_with_index {|e, i| ste[e[0]] = st[i] if st[i] != 'x' and e[0] != -1}
      dest[ctrl] = ste unless ste.empty?
    end
  end

  def self._calcula_permisos(menu, path, emp, prm, prf, dest)
    menu.each {|k, v|
      next if k.starts_with? 'tag_'

      st = []
      emp.each_with_index {|e, i|
        st[i] = prf[e[2]] ? (prf[e[2]][path + k] || prm[i]) : 'x'
      }

      if v.class == Hash
        _calcula_permisos(v, path + k + '/', emp, st, prf, dest)
      else # Es una opción normal
        asigna_permiso(v, st, emp, dest)

        begin
          unless v.starts_with?('/gi/')
            ps = URI(v).path.split('/')
            cl = ps.size == 3 ? ps[1].capitalize + '::' + ps[2].capitalize : ps[1].capitalize
            (cl + 'Controller').constantize # Para forzar el "lazy load" del controlador asociado
            cl = (cl + 'Mod').constantize
            cl.menu_l.each {|m|
              st2 = []
              emp.each_with_index {|e, i|
                st2[i] = prf[e[2]] ? (prf[e[2]][path + k + '/' + m[:label]] || prm[i]) : 'x'
              }
              asigna_permiso(m[:url], st2, emp, dest)
            }
          end
        rescue
        end
=begin
        ctrl = v[1..-1]
        if dest[ctrl]
          emp.each_with_index {|e, i|
            next if e[0] == -1
            if dest[ctrl][e[0]]
              dest[ctrl][e[0]] = st[i] if 'pbcx'.index(st[i]) < 'pbcx'.index(dest[ctrl][e[0]])
            else
              dest[ctrl][e[0]] = st[i] if st[i] != 'x'
            end
          }
        else
          ste = {}
          emp.each_with_index {|e, i| ste[e[0]] = st[i] if st[i] != 'x' and e[0] != -1}
          dest[ctrl] = ste unless ste.empty?
        end
=end
      end
    }
  end

  def self.calcula_permisos(usu, menu=nil, pf=nil)
    return if usu.admin

    menu = load_menu unless menu
    pf = {0 => {}} unless pf

    usu.pref[:permisos][:ctr] = {}
    usu.pref[:permisos][:emp].each {|e|
      unless pf[e[2]]
        p = Perfil.find(e[2])
        pf[e[2]] = p.data if p
      end
    }
    usu.pref[:permisos][:ctr] = {}
    _calcula_permisos(menu, '/', usu.pref[:permisos][:emp], usu.pref[:permisos][:emp].map{|e| e[1]}, pf, usu.pref[:permisos][:ctr])

    return [menu, pf]
  end
end

class Usuario < ActiveRecord::Base
  include Modelo
end

class HUsuario < ActiveRecord::Base
  belongs_to :created_by, :class_name => 'Usuario'
  serialize :pref
end