class NimbusHelpController < ApplicationController
  def index
    unless @usu.codigo == 'admin'
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    require 'rdoc'
    @rdoc_th = RDoc::Markup::ToHtml.new(RDoc::Options.new)

    @cap = {}

    procesa_file('Controladores', 'app/controllers/application_controller.rb')
    procesa_file('GI', 'app/controllers/gi.rb')
    procesa_file('General', 'app/controllers/nimbus_help_controller.rb')

    @cap.each {|c, s| s.each {|k, m| m.sort!}}
  end

  def procesa_file(cap, fi)
    @cap[cap] = {}

    met = nil
    h = nil
    File.readlines('modulos/nimbus-core/' + fi).each {|l|
      ls = l.strip
      if ls.starts_with?('##nim-doc')
        h = eval(ls[10..-1])
        @cap[cap][h[:sec]] ||= []
        met = ''
      else
        next unless met

        if ls.starts_with?('##')
          if h[:mark] == :asciidoc
            met = Asciidoctor.convert(met)
          elsif h[:mark] == :rdoc
            met = @rdoc_th.convert(met)
          end
          @cap[cap][h[:sec]] << [h[:met], met]
          met = nil
        else
          l = "#{ls[0] == '#' ? ls[1..-1] : l.rstrip}\n"
          if l[0] != "\n"
            l = l[1..-1] if h[:mark] == :rdoc
            l.lstrip! if h[:mark] == :asciidoc
          end
          met << l
        end
      end
    }
  end
end

=begin
##nim-doc {sec: 'NimbusPDF', met: 'Ayuda'}
# Para consultar la ayuda seguir el siguiente enlace: <a href="/nimpdf_help" target="_blank">NimbusPDF</a>
##

##nim-doc {sec: 'Controladores', met: 'Imágenes'}
<pre>
Las imágenes en Nimbus pueden ser de tres tipos:
.- Públicas: Residirían en la carpeta "public" del proyecto. Para acceder a ellas basta usar
             la URL /imagen.jpg
             No es recomendable usar este tipo de imágenes.
.- Assets: Residirían en la carpeta app/assets/images del proyecto o de cualquier módulo.
           Esta es la forma ideal de tratar las imágenes, ya que como todos los assets,
           se precompilan y se cachean, por lo que el rendimiento es óptimo. Notar que los
           assets se precompilan todos juntos, por lo que es conveniente usar nombres con
           prefijo para cada uno de ellos. Así, si tuviéramos en el módulo de bodega una
           imagen para depósitos, convendría llamarla:
           "modulos/bodega/app/assets/images/bodega_deposito.svg".
           Para usarlas en un controlador usaríamos el método "nim_asset_image".
           El método admite cuatro argumentos con nombre:
             img: Es el nombre de la imagen (sin path).
             w: Anchura de la imagen (opcional).
             h: Altura de la imagen (opcional).
             hid: id del elemento html que se generará (opcional).
           Si no se especifica ni anchura ni altura se usará una altura de 25.
           Si no se especifica una de las dos medidas, la otra se calculará para preservar
           el aspect-ratio.
           Devuelve un tag html de tipo <img> con toda la información para cargar la imagen.
           Hay que tener en cuenta que es posible que haya que relanzar el server (rails s)
           siempre que añadamos un nuevo asset.
.- Propias: son las imágenes que se pueden asociar en un mantenimiento. Van ligadas al modelo
            y al id de la ficha que se esté editando. Residen en la carpeta data/Modelo/id/_imgs
            Para usarlas en un controlador usaríamos el método "nim_image".
            El método admite seis argumentos con nombre:
              mod: Modelo al que pertenece la imagen.
              id: id del registro.
              tag: Nombre del campo imagen relacionado en @campos.
              w: Anchura de la imagen (opcional).
              h: Altura de la imagen (opcional).
              hid: id del elemento html que se generará (opcional).
            Si no se especifica ni anchura ni altura se usará una altura de 25.
            Si no se especifica una de las dos medidas, la otra se calculará para preservar
            el aspect-ratio.
            Devuelve un tag html de tipo <img> con toda la información para cargar la imagen.

Para añadir una imagen en un controlador basta con añadir un campo (o varios si queremos varias imágenes)
en @campos con la clave "img" (que es un hash). Por ejemplo:
@campos = {
  foto1: {tab: 'pre', gcols: 2, img: {h: 120}, grid: {width: 50}},
  foto2: {tab: 'pre', gcols: 2, img: {h: 120}, grid: {width: 50}}
}

En este caso estamos asociando dos imágenes al modelo al que pertenezca el controlador.
Las imágenes saldrían en la ficha con una altura de 120px y la anchura que les corresponda.
Además se pintarían en el grid. Como para el grid no hemos especificado dimensiones
saldrían con una altura de 25px y la anchura que les corresponda dentro de una celda de 50px.
El tratamiento de las imágenes es completamente automático. Sólo si necesitáramos acceder
a ellas desde algún otro controlador necesitaríamos los métodos anteriores. En este caso
para acceder a la "foto1" tendríamos que usar:

nim_image mod: Mimodelo, id: id_del_registro, tag: :foto1, h: 100

La clave "img" puede tener las siguientes subclaves:
  w: Anchura de la foto en la ficha.
  h: Altura de la foto en la ficha.
  wg: Anchura de la foto en el grid.
  hg: Altura de la foto en el grid.

No hay que confundir, en el caso de pintar la imagen en el grid, la clave "wg" del hash "img"
con la clave "width" del hash "grid". La primera es la anchura de la imagen, la segunda es
la anchura de la celda. Para la clave "w" se puede usar también "width" y para la "h" "height".

Lo ideal es utilizar sólo una dimensión (altura o anchura) y que la otra se calcule para
preservar el aspect-ratio. En el caso del grid, mejor asignar la "h" para que todas las
filas salgan con la misma altura. Si no se especifica ninguna medida (ni anchura ni altura)
se tomará pordefecto "h: 25" (o "hg: 25" para el grid). Esto para el grid está bien, pero
para la ficha es un poco escaso.

También se puede personalizar la imagen que queramos. Si existiera en el controlador un
método con el mismo nombre que el campo, se usará lo que devuelva este método para generar
la imagen (y se ignorará el hash "img" de @campos). Por ejemplo:

def foto1
  case @fact.algun_campo
  when 1
    nim_asset_image img: 'img1.svg', h: (request.xhr? ? 25 : 120)
  when 2
    nim_asset_image img: 'img2.svg', h: (request.xhr? ? 25 : 120)
  else
    nim_asset_image img: 'default.png', h: (request.xhr? ? 25 : 120)
  end
end

Notar el uso de "request.xhr?". Si devuelve true es que el método ha sido llamado desde el
grid. Así podemos especificar alturas distintas para el grid y para la ficha.

Para usar imágenes en grids embebidos (los generados con crea_grid) tenemos que definir
una columna con el tipo "img" (type: :img) y luego en el "data" usar uno de los métodos
anteriores para generar la imagen. Por ejemplo:

cols = [
  {name: 'codigo', label: 'Código', width: 40},
  {name: 'nombre', label: 'Nombre', width: 40},
  {name: 'Imagen', type: :img, width: 40}
]
q = Usuario.pluck :id, :codigo, :nombre
crea_grid cmp: :mi_grid, cols: cols, grid: {caption: "Usuarios", height: 200}, data: q.map{|u| u + [nim_image(mod: Usuario, id: u[0], tag: :foto)]}
</pre>
##
=end
