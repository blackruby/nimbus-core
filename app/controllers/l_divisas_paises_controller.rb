class LDivisasPaisesMod
  @campos = {
    divisa_id: {tab: 'pre', gcols: 3, title: 'Si no se especifica una divisa se mostrarán todas'}
  }

  @titulo = 'Listado de países por divisa'
  @nivel = ''

  include MantMod
end

class LDivisasPaisesController < ApplicationController
  def before_index
    @usu.admin
  end

  def before_envia_ficha
    params2fact
  end

  def after_save
    st = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n"
    fecha = Time.now
    tmp_file = nim_tmpname '/tmp/', '.pdf'

    info = {
      Title: 'Países por divisa',
      Author: 'Nimbus',
      Subject: 'Informe de ejemplo de NimbusPDF',
      Keywords: 'divisas, países',
      Creator: 'Nimbus',
      Producer: 'NimbusPDF + Prawn',
      CreationDate: fecha
    }

    sql = Divisa.includes(:paises).order(:codigo)
    sql = sql.where(id: @fact.divisa_id) if @fact.divisa_id

    NimbusPDF.generate(tmp_file, info: info, compress: true) {
      sql.each {|div|
        tot = 0

        # Lambdas de cabecera y pie
        cabecera -> {{divisa: div.codigo + ' ' + div.descripcion, lorem: st, pagina: "Página: #{page_number}"}}
        pie ->(fin) {{fecha: fecha, total: fin ? "#{div.descripcion} (#{div.codigo})   Tot.Países: #{tot}" : ''}}

        nuevo_doc(tit: div.descripcion) {
          div.paises.each {|p|
            p.nombre += ": \n#{st * 2}" if p.codigo == 'DE'
            nueva_banda ban: :detalle, val: {codigo: p.codigo, descripcion: p.nombre, codigo_iso: p.codigo_iso3}
            stroke_horizontal_line documento[:draw][:margen_i][:at][0], documento[:draw][:margen_d][:at][0]
            move_down 5
            tot += 1
          }
          nueva_banda ban: :total, val: {total: "Nº de países: #{tot}"}
        }

        nuevo_doc doc: '322', cab: {codigo: div.codigo, descripcion: div.descripcion, n_paises: tot, actividad: 'X'}
      }

      repeat(:all, dynamic: true) {
        pon_elementos :pie, pagina_doc: page_number_doc('Página (doc): %{p} de %{tp}'), pagina_inf: page_number('Página (inf): %{p} de %{tp}')
      }
    }

    envia_fichero file: tmp_file, file_cli: 'paises_divisas.pdf', disposition: 'inline'
  end
end
