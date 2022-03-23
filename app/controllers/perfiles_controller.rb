unless Nimbus::Config[:excluir_perfiles]

class PerfilesController < ApplicationController
  def gen_menu(menu, path, last_st)
    menu.delete_if {|k, v|
      if k.starts_with? 'tag_'
        true
      else
        st = @fact.data[path + k] || 'h'
        sth = st == 'h' ? last_st : st
        if v.class == Hash
          menu[k] = {url: nil, menu: v}
          gen_menu(v, path + k + '/', st == 'h' ? last_st : st)
        else
          mn = nil
          begin
            unless v.starts_with?('/gi/')
              ps = URI(v).path.split('/')
              cl = ps.size == 3 ? ps[1].capitalize + '::' + ps[2].camelize : ps[1].camelize
              (cl + 'Controller').constantize # Para forzar el "lazy load" del controlador asociado
              cl = (cl + 'Mod').constantize
              unless cl.menu_l.empty?
                mn = {}
                cl.menu_l.each {|m|
                  st2 = @fact.data[path + k + '/' + m[:label]] || 'h'
                  sth2 = st2 == 'h' ? sth : st2
                  mn[m[:label]] = {url: m[:url], nt: nt(m[:label]), st: st2, sth: sth2, menu: nil}
                }
              end
            end
          rescue
          end
          menu[k] = {url: v, menu: mn}
        end
        menu[k][:nt] = nt(k)
        menu[k][:st] = st
        menu[k][:sth] = sth
        false
      end
    }
  end

  def before_envia_ficha
    @assets_stylesheets = %w(perfiles)
    @assets_javascripts = %w(perfiles)

    return if @fact.id == 0

    @menu = Usuario.load_menu(true)
    gen_menu(@menu, '/', 'h')
    @ajax << "genMenu(#{@menu.to_json});"
  end

  def before_save
    @fact.data = params[:data]
  end

  def after_save
    return unless @fant[:id]

    menu = nil
    pf = nil
    Usuario.where('NOT admin').each {|u|
      calcular = false
      u.pref[:permisos][:emp].each {|e|
        if e[2] == @fact.id
          calcular = true
          break
        end
      }
      if calcular
        menu, pf = Usuario.calcula_permisos(u, menu, pf)
        u.save
      end
    }
  end
end

end
