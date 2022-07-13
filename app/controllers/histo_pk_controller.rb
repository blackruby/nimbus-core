class HistoPkMod
  @campos = {
    panel: {type: :div, tab: 'pre', gcols: 12},
  }

  include MantMod
end

class HistoPkController < ApplicationController
  def before_edit
    @nivel = flash[:nivel]
    flash[:mod].nil? || flash[:mod].constantize.modelo_histo.nil? ? {msg: 'No hay histórico'} : true
  end

  def before_envia_ficha
    @assets_javascripts = %w(histo_pk)

    id = flash[:id]
    mod = flash[:mod].constantize
    modh = mod.modelo_histo

    fic = modh.where('idid = ?', id).order('created_at').last

    begin
      fic.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)
      clave = forma_campo_id(modh, fic.id)
    rescue
      clave = nil
    end
    @titulo = 'Histórico ' + nt(mod.table_name) + ': ' + (clave ? clave : "id: #{id}")

    cols = [
      {name: 'idid', type: :integer, hidden: true},
      {name: 'created_at', label: nt('fecha'), type: :datetime, width: 100},
      {name: 'created_by_id', label: nt('usuario'), ref: 'Usuario', width: 150}
    ]

    modh.columns_hash.each {|c, v|
      next if %w(id idid created_at created_by_id).include?(c) || modh.propiedades.dig(c.to_sym, :bus_hide)

      prop = modh.propiedades[c.to_sym] || {}
      rich = v.type == :text && prop[:rich]
      @assets_stylesheets = @assets_stylesheets.to_a + %w(quill/nim_quill) if rich

      cols << {
        name: c,
        label: nt(c),
        type: v.type,
        manti: prop[:manti],
        decim: prop[:decim],
        formatter: rich ? '~function(v){return \'<div class=ql-editor style=padding:0;height:unset;max-height:100px>\' + v + \'</div>\'}~' : nil
      }
      if c.ends_with? '_id'
        cl = modh.reflect_on_association(c[0..-4]).class_name
        cols[-1][:ref] = cl
      end
    }

    if fic
      #wh = modh.pk.map{|k| "#{k} = '#{fic[k]}'"}.join(' AND ')
      wh = modh.pk.map{|k| k.to_s + (fic[k] ? " = '#{fic[k]}'" : ' IS NULL')}.join(' AND ')
      q = modh.where(wh).order(:created_at)
    else
      q = []
    end

    crea_grid(
      cmp: :panel,
      modo: :ed,
      export: 'histo',
      cols: cols,
      del: false,
      ins: false,
      sel: :cel,
      bsearch: true,
      search: false,
      grid: {
        cellEdit: false,
        altRows: false,
        caption: @titulo,
        height: 800,
        gridComplete: '~gridCargado~',
        beforeSelectRow: '~function(){return false;}~'
      },
      data: q.map{|r| [r.id] + cols.map{|c| r[c[:name]]}}
    )
  end
end
