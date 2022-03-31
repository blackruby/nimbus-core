unless Nimbus::Config[:excluir_usuarios]

class Usuario < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 30},
    nombre: {},
    email: {},
    password_salt: {bus_hide: true},
    password_hash: {bus_hide: true},
    password_fec_mod: {},
    admin: {},
    timeout: {manti: 6, nil: true},
    empresa_def_id: {ro: :all},
    ejercicio_def_id: {ro: :all},
    fecha_baja: {},
    num_dias_validez_pass: {manti: 3, nil: true},
    ips: {manti: 80},
    ldapservidor_id: {},
    pref: {bus_hide: true},
  }

  serialize :pref

  belongs_to :empresa_def, :class_name => 'Empresa'
  belongs_to :ejercicio_def, :class_name => 'Ejercicio'
  belongs_to :ldapservidor, :class_name => 'Pais'

  after_initialize :ini_campos

  def ini_campos
    if self.respond_to? :pref
      self.pref ||= {}
      self.pref[:permisos] ||= {emp: [], prf: [], usu: [], ctr: {}}
    end
  end

  def auto_comp_label(_tipo)
    "#{self.nombre} (#{self.codigo})"
  end

  def auto_comp_value(_tipo)
    "#{self.nombre} (#{self.codigo})"
  end

  def self.add_menu(hm, menu)
    hm.deep_merge!(YAML.load(ERB.new(File.read(menu)).result(binding)))
  end

  def self.del_opts_menu(menu)
    menu.delete_if {|k, v|
      if v.is_a? Hash
        del_opts_menu(v)
        false
      else
        v == '_'
      end
    }
  end

  def self.load_menu(perm = false, usu = nil)
    @usu = usu
    hmenu = {}
    if perm
      hmenu.deep_merge!(Perfil.permisos_especiales).deep_merge!({'_opciones_de_menu_' => nil})
    end
    fm = "#{Nimbus::GestionPath}menu_pre.yml"
    add_menu(hmenu, fm) if File.exist?(fm)
    add_menu(hmenu, 'modulos/nimbus-core/menu.yml')
    # Mezclar el menú de cada módulo y obtener un array con los módulos disponibles
    modulos = []
    Dir.glob(Nimbus::ModulosGlob + '/menu.yml').each {|m|
      next if m == 'modulos/nimbus-core/menu.yml'
      add_menu(hmenu, m)
      modulos << m.split('/')[1]
    }
    # Mezclar los menús de sobrecarga de módulos de cada módulo si el módulo a sobrecargar existe
    Dir.glob(Nimbus::ModulosGlob + '/menu_*.yml').each {|m|
      add_menu(hmenu, m) if modulos.include?(m.scan(/_\w*\.yml/)[0][1..-5])
    }
    # Mezclar el menú principal de la gestión
    fm = "#{Nimbus::GestionPath}menu.yml"
    add_menu(hmenu, fm) if File.exist?(fm)

    # Eliminar recursivamente todas las opciones que tengan como valor (url) un "_" que es el
    # convenio para eliminar opciones (fundamentalmente sobrecargándolas desde el menú principal)
    del_opts_menu(hmenu)

    return hmenu
  end

  def self.asigna_permiso(ctrl, st, emp, dest)
    #ctrl = URI(ctrl).path[1..-1]
    ctrl = URI(ctrl).path
    ctrl = ctrl[1..-1] if ctrl[0] == '/'

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
      #next if k.starts_with? 'tag_'
      next if k.starts_with?('tag_') || v.nil?

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
            cl = ps.size == 3 ? ps[1].capitalize + '::' + ps[2].camelize : ps[1].camelize
            (cl + 'Controller').constantize # Para forzar el "lazy load" del controlador asociado
            cl = (cl + 'Mod').constantize
            # Asignación de permisos a las opciones de menu_l
            cl.menu_l.each {|m|
              st2 = []
              emp.each_with_index {|e, i|
                st2[i] = prf[e[2]] ? (prf[e[2]][path + k + '/' + m[:label]] || prm[i]) : 'x'
              }
              asigna_permiso(m[:url], st2, emp, dest)
            }
            # Asignación de permisos a los hijos
            cl.hijos.each {|h|
              #asigna_permiso('/' + h[:url], st, emp, dest)
              _calcula_permisos({'' => '/' + h[:url]}, path, emp, st, prf, dest)
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

    menu = load_menu(true) unless menu
    pf = {0 => {}} unless pf

    usu.pref[:permisos][:ctr] = {}
    usu.pref[:permisos][:emp].delete_if {|e|
      if Empresa.exists?(e[0])
        unless pf[e[2]]
          p = Perfil.find(e[2])
          pf[e[2]] = p.data if p
        end
        false
      else
        true
      end
    }
    usu.pref[:permisos][:ctr] = {}
    _calcula_permisos(menu, '/', usu.pref[:permisos][:emp], usu.pref[:permisos][:emp].map{|e| e[1]}, pf, usu.pref[:permisos][:ctr])

    return [menu, pf]
  end

  def self.valida_password(p)
    return (p.size >= 8 and p =~ /[a-z]/ and p =~ /[A-Z]/ and p =~ /[0-9]/) ? nil : 'La contraseña debe de tener al menos 8 caracteres y contenr mayúsculas, minúsculas y números'
  end

  # Método que devuelve las empresas a las que tiene acceso un usuario
  # Si no se le pasan argumentos devuelve un array con los ids de las empresas
  # Si se le pasa un número variable de argumentos (o un array) indicando
  # campos del modelo Empresa (en forma de string o symbol), devuelve
  # un array de arrays (si hay más de un argumento) con los valores de dichos campos.

  def mis_empresas(*cmps)
    ids = self.admin ? Empresa.pluck(:id) : self.pref[:permisos][:emp].map{|e| e[0]}
    if cmps.empty?
      ids
    else
      Empresa.where('id in (?)', ids).pluck(*cmps.flatten.compact)
    end
  end

  def permiso(tag, eid)
    pref[:permisos][:ctr][tag.to_s][eid.to_i]
  end
end

end
