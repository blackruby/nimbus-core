class UpdatesController < ApplicationController
  def index
    @assets_stylesheets = %w(updates)
    @assets_javascripts = %w(updates)

    @updates = YAML.load_file("#{Nimbus::GestionPath}updates.yml").sort.reverse.map{|f| d_m_a(f)} rescue []
  end

  def get_update
    rdth = RDoc::Markup::ToHtml.new(RDoc::Options.new)
    
    hfec = a_m_d(params[:hfec])
    if params[:dfec]
      dfec = a_m_d(params[:dfec])
    else
      updates = YAML.load_file("#{Nimbus::GestionPath}updates.yml").sort rescue []
      i = updates.index(hfec)
      dfec = i.to_i > 0 ? updates[i - 1].next : '0000'
    end
    
    mods = [Nimbus::Gestion, 'nimbus-core']
    Nimbus::ModulosCli.each {|m|
      break if m =='.'
      mods << m.split('/')[-1]
    }
    
    cm = YAML.load_file('modulos/changelog.yml') rescue {}
    cc = YAML.load_file("#{Nimbus::GestionPath}changelog.yml") rescue {}
    cc.each {|k, v| cm[k] ? cm[k].concat(v) : cm[k] = v}
    
    htm = ''
    mods.each {|m|
      next unless cm[m]
      cms = cm[m].select{|c| c[1].between?(dfec, hfec)}.sort_by{|c| c[1]}.reverse
      next if cms.empty?
      htm << %Q(<div class="modulo">#{nt(m)}</div>)
      cms.each{|c|
        htm << '<div class="commit">'
        htm << (c[2] ? '<i class="material-icons expande">expand_more</i>' : '<i class="material-icons">remove</i>')
        htm << %Q(<span title="#{d_m_a(c[1])}">#{c[0]}</span></div>)
        # La siguiente línea comentada es si se quisiera parsear en rdoc. La descomentada es para markdown (md)
        # htm << %Q(<div class="cuerpo">#{rdth.convert(c[2])}</div>) if c[2]
        htm << %Q(<div class="cuerpo">#{RDoc::Markdown.parse(c[2]).accept(rdth)}</div>) if c[2]

      }
    }
    render json: htm.to_json
  end
        
  def d_m_a(f)
    f[8,2] + '-' + f[5,3] + f[0,4]
  end

  def a_m_d(f)
    f[6,4] + '-' + f[3,3] + f[0,2]
  end
end
