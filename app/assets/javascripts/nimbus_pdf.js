var _controlador = "nimpdf";

var fonts = ["Helvetica", "Times-Roman", "Courier", "Symbol", "ZapfDingbats"];

var formatosPag = {
  A0: [2383.94, 3370.39],
  A1: [1683.78, 2383.94],
  A2: [1190.55, 1683.78],
  A3: [841.89, 1190.55],
  A4: [595.28, 841.89],
  A5: [419.53, 595.28],
  A6: [297.64, 419.53],
  A7: [209.76, 297.64],
  A8: [147.40, 209.76],
  A9: [104.88, 147.40],
  A10: [73.70, 104.88],
  B0: [2834.65, 4008.19],
  B1: [2004.09, 2834.65],
  B2: [1417.32, 2004.09],
  B3: [1000.63, 1417.32],
  B4: [708.66, 1000.63],
  B5: [498.90, 708.66],
  B6: [354.33, 498.90],
  B7: [249.45, 354.33],
  B8: [175.75, 249.45],
  B9: [124.72, 175.75],
  B10: [87.87, 124.72],
  C0: [2599.37, 3676.54],
  C1: [1836.85, 2599.37],
  C2: [1298.27, 1836.85],
  C3: [918.43, 1298.27],
  C4: [649.13, 918.43],
  C5: [459.21, 649.13],
  C6: [323.15, 459.21],
  C7: [229.61, 323.15],
  C8: [161.57, 229.61],
  C9: [113.39, 161.57],
  C10: [79.37, 113.39],
  RA0: [2437.80, 3458.27],
  RA1: [1729.13, 2437.80],
  RA2: [1218.90, 1729.13],
  RA3: [864.57, 1218.90],
  RA4: [609.45, 864.57],
  SRA0: [2551.18, 3628.35],
  SRA1: [1814.17, 2551.18],
  SRA2: [1275.59, 1814.17],
  SRA3: [907.09, 1275.59],
  SRA4: [637.80, 907.09],
  EXECUTIVE: [521.86, 756.00],
  FOLIO: [612.00, 936.00],
  LEGAL: [612.00, 1008.00],
  LETTER: [612.00, 792.00],
  TABLOID: [792.00, 1224.00],
  CUSTOM: null
}

var alto, ancho;

var id = 1;
var $canvas = null;
var canvasWidth = null;
var canvasHeight = null;
var canvasLeft = null;
var canvasTop = null;
var activo = null;
var zoom = 1;
var clonar = false;
var puntoIni = null; //Para almacenar las coordenadas (en puntos) del punto inicial al añadir elementos
var oldValue = ""; //Para almacenar el valor anterior de los inputs
var modoBorrado;  // Indica qué se va a eliminar: "e" (elemento), "b" (banda)
var extraHandle = 6;  // anchura/altura extra que se dará a las líneas de la banda "draw" para que sea más fácil acceder a sus handles de dimensionamiento
var mouseDownOnElemento = false;

function pt2pxX(pt) {
  return (pt * canvasWidth / ancho).toFixed(0) + "px";
}
function pt2pxY(pt) {
  return ((alto - pt) * canvasHeight / alto).toFixed(0) + "px";
}
function pt2pxH(pt) {
  return (pt * canvasHeight / alto).toFixed(0) + "px";
}
function px2ptX(px) {
  return (px * ancho / canvasWidth).toFixed(2);
}
function px2ptY(px) {
  return (alto - px * alto / canvasHeight).toFixed(2);
}
function px2ptH(px) {
  return (px * alto / canvasHeight).toFixed(2);
}

function tagValido(tag) {
  if (tag == "" || tag[0] >= "0" && tag[0] <= "9") return false;
  for (var l of tag) {
    if (!(l >= "0" && l <= "9" || l >= "a" && l <= "z" || l >= "A" && l <= "Z" || l == "_")) return false;
  }
  return true;
}

function bandaValida(banda) {
  if (!tagValido(banda)) return false;

  var val = true;
  $("#i_banda option").each(function() {
    if (banda == this.value) {
      val = false;
      return false;
    }
  });

  return val;
}

function addBanda() {
  var banda = "";
  var msg = "Banda";
  while(true) {
    banda = prompt(msg, banda);
    if (banda == null || bandaValida(banda)) break;
    msg = "Nombre de banda inválido o repetido";
  };
  if (banda) {
    $(i_banda).append(`<option value="${banda}">${banda}</option`).val(banda).trigger("change");
  }
}

function ajustaMargenBottom(pos) {
  var t = pt2pxY(pos);
  var tf = parseFloat(t);
  margen_bottom.style.top = margen_bottom_guia.style.top = tf > cont_canvas.scrollHeight - 1 ? cont_canvas.scrollHeight - 1 + "px" : t;
}

function ajustaZoom(z) {
  // Asumimos que un zoom == 1 significa que el ancho de la página está ajustado al ancho del canvas
  // minZoom es el mínimo zoom permitido, que coincide con que la página esté ajustada en altura y anchura en el canvas
  //var minZoom = Math.min(1, cont_canvas.clientHeight * ancho / alto / cont_canvas.clientWidth);
  //zoom = z < minZoom ? minZoom : z;
  var minZoom = Math.min(1, cont_canvas.clientHeight * ancho / alto / cont_canvas.clientWidth);
  zoom = z < minZoom ? minZoom : z;
}

function setExtraHandle() {
  for (var e of $("._draw")) {
    var dat = $(e).data("nimbus");
    if (dat) {
      if (dat.vh == "h")
        e.style.height = e.offsetHeight + extraHandle + "px"
      else
        e.style.width = e.offsetWidth + extraHandle + "px"
    }
  }
}

function resetExtraHandle() {
  for (var e of $("._draw")) {
    var dat = $(e).data("nimbus");
    if (dat) {
      if (dat.vh == "h")
        e.style.height = e.offsetHeight - extraHandle + "px"
      else
        e.style.width = e.offsetWidth - extraHandle + "px"
    }
  }
}

function setDrawWH(el) {
  // En los elementos "draw" el efecto de grosor se hace con la anchura/altura del borde (en función de si es horizontal o vertical)
  // Al propio elemento (div) se le da un extra en anchura/altura para no tener problemas en encontrar los handles de redimensionamiento.

  var data = el.data("nimbus");
  var e0 = el[0];

  if (data.vh == 'h') {
    e0.style.width = pt2pxX(data.width);
    var h = pt2pxH(data.height);
    e0.style.height = parseFloat(h) + extraHandle + "px";
    e0.style.borderTopWidth = h;
  } else {
    e0.style.height = pt2pxH(data.height);
    var w = pt2pxX(data.width);
    e0.style.width = parseFloat(w) + extraHandle + "px";
    e0.style.borderLeftWidth = w;
  }
}

function ajustaCanvas(z = zoom) {
  ajustaZoom(z);
  // Ponemos a cero el top del margen inferior por si en el zoom actual está algo por debajo
  // del bottom del canvas y está falseando las dimensiones de cont_canvas
  margen_bottom.style.top = margen_bottom_guia.style.top = 0;

  canvasWidth = cont_canvas.clientWidth * zoom;
  canvasHeight = alto * canvasWidth / ancho;
  $canvas
    .width(canvasWidth)
    .height(canvasHeight)
    .css("left", canvasWidth < cont_canvas.clientWidth ? (cont_canvas.clientWidth - canvasWidth) / 2 : 0)
    .find(".elemento").each(function() {
      var el = $(this);

      this.style.left = pt2pxX(el.data("nimbus").at[0]);
      this.style.top = pt2pxY(el.data("nimbus").at[1]);
      if (this.getAttribute("banda") == "draw") {
        setDrawWH(el);
      } else {
        this.style.width = pt2pxX(el.data("nimbus").width);
        this.style.height = pt2pxH(el.data("nimbus").height);
        this.style.fontSize = pt2pxH(el.data("nimbus").size)
      }
    });

  // Ajustar divs de bandas de detalle
  for (var d of $(".div-banda")) {
    d.style.top = pt2pxY(parseFloat($(`._${$(d).attr("banda")}:not(.div-banda)`).data("nimbus").at[1]) + 5);
    d.style.height = pt2pxH(20);
  }

  canvasLeft = bandas.offsetWidth + canvas.offsetLeft;

  // Márgenes
  margen_top.style.top = margen_top_guia.style.top = pt2pxY(alto - i_top_margin.value);
  ajustaMargenBottom(i_bottom_margin.value);
}

function redim() {
  cont_canvas.style.left = bandas.offsetWidth + "px";
  cont_canvas.style.right = propiedades.offsetWidth + "px";
  ajustaCanvas();
}

function marcarElementoBanda() {
  // Marcar el elemento activo en la relación de elementos de la banda
  for (var e of $("#bandas_cont label")) {
    if (e.innerText == activo.data("nimbus").alias) {
      e.classList.add("activo-banda");
      break;
    }
  }
}

function selElemento(elemento) {
  if (activo) {
    activo.removeClass(activo.attr("banda") == "draw" ? "activo-draw" : "activo").css("z-index", 0);
    $(".activo-banda").removeClass("activo-banda");
  }

  activo = elemento;
  $("#propiedades table").css("display", elemento == null ? "none" : "table");

  if (!elemento) {
    b_eliminar_elemento.style.display = "none";
    return;
  }

  b_eliminar_elemento.style.display = "";

  activo.addClass(activo.attr("banda") == "draw" ? "activo-draw" : "activo").css("z-index", 1);

  // Pasar todos los valores de data a los inputs

  var data = activo.data("nimbus");
  i_alias.value = data.alias;
  i_x.value = data.at[0];
  i_y.value = data.at[1];
  i_ancho.value = data.width;
  i_alto.value = data.height;
  i_texto.value = data.texto;
  i_alineacion_h.value = data.align;
  i_alineacion_v.value = data.valign;
  i_font.value = data.font;
  i_estilo.value = data.style;
  i_font_size.value = data.size;
  i_interlineado.value = data.leading;
  i_overflow.value = data.overflow;
  i_min_font_size.value = data.min_font_size;
  i_imagen.value = data.imagen;
  i_color.value = data.color;
  i_bgcolor.value = data.bgcolor;
  i_borde.value = data.borde;
  i_brcolor.value = data.brcolor;
  i_pad_l.value = data.pad_l;
  i_pad_r.value = data.pad_r;
  i_pad_t.value = data.pad_t;
  i_pad_b.value = data.pad_b;
  i_render.value = data.render;

  // Seleccionar banda activa si el elemento pertenece a otra banda
  var banda = $(elemento).attr("banda");
  if (banda != i_banda.value) $(i_banda).val(banda).trigger("change", false);

  marcarElementoBanda();

  // Activar los inputs de propiedades adecuados al tipo de banda
  $("#propiedades tr").css("display", ""); // Activar todos
  switch (banda) {
    case "cab": case "pie": break;
    case "draw":
      $(".tr-hide-draw").css("display", "none");
      break;
    default:
      $(".tr-hide-det").css("display", "none");
  }
}

function disableConfPag() {
  i_formato_pag.disabled = true;
  i_orientacion_pag.disabled = true;
  i_ancho_pag.disabled = true;
  i_alto_pag.disabled = true;
}

function dragTbox(e, ui) {
  if (e.shiftKey) ui.position.top = ui.originalPosition.top;
  if (e.ctrlKey) ui.position.left = ui.originalPosition.left;
  $(this).draggable("option", "snap", e.altKey);

  if (!clonar) {
    activo.data("nimbus").at[0] = i_x.value = px2ptX(ui.position.left);
    activo.data("nimbus").at[1] = i_y.value = px2ptY(ui.position.top);
  }
}

function resizeTbox(e, ui) {
  $(this).resizable("option", "snap", e.altKey);

  if (ui.originalPosition.left != ui.position.left) activo.data("nimbus").at[0] = i_x.value = px2ptX(ui.position.left);
  if (ui.originalPosition.top != ui.position.top) activo.data("nimbus").at[1] = i_y.value = px2ptY(ui.position.top);
  if (ui.size.width != ui.originalSize.width) activo.data("nimbus").width = i_ancho.value = px2ptX(ui.size.width);
  if (ui.size.height != ui.originalSize.height) activo.data("nimbus").height = i_alto.value = px2ptH(ui.size.height);
}

function addTbox(data, alias, clase) {
  if (!alias) return;

  var claseCalc = clase ? clase : i_banda.value;

  var bd = banDetalle(claseCalc);
  if (bd && $("._" + claseCalc).length == 0) {
    $(canvas).append(`<div id="d_${claseCalc}" class="_${claseCalc} div-banda" banda="${claseCalc}"><div class="div-drag-banda"></div></div>`);
    $("#d_" + claseCalc)
      .css("top", pt2pxY(parseFloat(data.at[1]) + 5)).css("height", pt2pxH(20))
      .css("display", clase ? "none" : "block")
      .draggable({
        containment: "parent",
        handle: ".div-drag-banda",
        axis: "y",
        drag: function(e, ui) {
          var top = (parseFloat(px2ptY(parseFloat(ui.position.top))) - 5).toFixed(2);
          var topPx = pt2pxY(top);
          for (var e of $(`._${claseCalc}:not(.div-banda)`)) {$(e).css("top", topPx).data("nimbus").at[1] = top;}
        }
      });
  }

  var draw = false;
  if (claseCalc == "draw") draw = parseFloat(data.width) > parseFloat(data.height) ? "h" : "v";

  if (bd) {
    var hand = "e, w";
  } else if (draw == "h") {
    var hand = "e, w";
  } else if (draw == "v") {
    var hand = "n, s";
  } else {
    var hand = "e, s, se";
  }

  var elId = `el_${id++}`
  $canvas.append(`<div id="${elId}" class="elemento${draw ? " elemento-draw" : ""}" banda="${claseCalc}">${draw ? "" : "<label></label>"}</div>`);
  var el = $(`#${elId}`)
    .css("cursor", clonar ? "copy" : "move")
    .draggable({
      containment: "parent",
      axis: bd ? "x" : false,
      snap: true,
      helper: clonar ? "clone" : "original",
      drag: dragTbox,
      stop: function(e, ui) {
        if (clonar) addTbox($.extend(true, {}, $(this).data("nimbus"), {at: [px2ptX(ui.position.left), px2ptY(ui.position.top)]}), solicitarAlias());
      }
    })
    .resizable({
      containment: "parent",
      handles: hand,
      snap: true,
      resize: resizeTbox,
      start: function(e, ui) {
        if (draw == "h") $(this).resizable("option", "minWidth", this.offsetHeight);
        if (draw == "v") $(this).resizable("option", "minHeight", this.offsetWidth);
      }
    })
    .mousedown(function() {selElemento($(this));});

  // Inicializar el data

  var dat = $.extend(true, {
    texto: "",
    align: "left",
    valign: "center",
    font: i_font_def.value,
    style: "normal",
    size: i_font_size_def.value,
    leading: i_interlineado_def.value,
    overflow: "truncate",
    min_font_size: "5.00",
    imagen: "",
    color: draw ? i_color_linea.value : "#000000",
    bgcolor: "#ffffff",
    borde: "0.00",
    brcolor: "#000000",
    pad_l: "0.00",
    pad_r: "0.00",
    pad_t: "0.00",
    pad_b: "0.00",
    render: "auto",
  }, data, {alias: alias});
  if (draw) dat.vh = draw;

  el.data("nimbus", dat);

  // Posicionar y dimensionar el elemento

  var e0 = el[0];
  e0.style.left = pt2pxX(data.at[0]);
  e0.style.top = pt2pxY(data.at[1]);
  if (draw) {
    setDrawWH(el);
  } else {
    e0.style.width = pt2pxX(data.width);
    e0.style.height = pt2pxH(data.height);
  }

  // Cargar imagen
  dat.imagen ? el.addClass("bgcolor-con-imagen").css("background-image", urlImagen(dat.imagen)) : el.addClass("bgcolor-sin-imagen");

  // Ajustar carácteristicas del texto
  if (claseCalc == "cab" || claseCalc == "pie") {
    el.css("text-align", dat.align).css("font-size", pt2pxH(dat.size));
    el.find("label").text(dat.texto).css("vertical-align", dat.valign == "center" ? "middle" : dat.valign);
  }

  el.addClass("_" + claseCalc);
  if (!clase) {
    el[0].style.display = "table"
    $(bandas_cont).append(`<label elemento="${elId}">${alias}</label><br>`);
    selElemento(el);
  }

  disableConfPag();
}

function dialogOpenClose(diag) {
  var d = $("#" + diag);
  d.css("display") == "none" ? d.css("display", "block").find(":input:enabled").first().focus() : d.css("display", "none");
}

function cargarDatos(d) {
  d = $.extend({def: {}, pag: {}, cab: {}, pie: {}, draw: {}, ban: {}}, d);

  i_font_def.value = d.def.font || 'Helvetica';
  i_font_size_def.value = d.def.font_size || "12.00";
  i_interlineado_def.value = d.def.leading || "0.00";
  i_grosor_linea.value = d.def.grosor_linea || "1.00";

  if (d.pag.size == undefined) d.pag.size = "A4";
  if (typeof(d.pag.size) == "string") {
    i_formato_pag.value = d.pag.size;
    ancho = i_ancho_pag.value = formatosPag[d.pag.size][0];
    alto = i_alto_pag.value = formatosPag[d.pag.size][1];
    i_ancho_pag.disabled = i_alto_pag.disabled = true;
  } else {
    i_formato_pag.value = "CUSTOM";
    ancho = i_ancho_pag.value = parseFloat(d.pag.size[0]);
    alto = i_alto_pag.value = parseFloat(d.pag.size[1]);
  }

  i_orientacion_pag.value = d.pag.layout || "portrait";
  if (i_orientacion_pag.value == "landscape") [ancho, alto] = [alto, ancho];
  i_top_margin.value = d.pag.top_margin || "0.00";
  i_bottom_margin.value = d.pag.bottom_margin || "0.00";
  i_fondo.value = d.pag.fondo || "";

  for (var t of Object.keys(d.cab)) addTbox(d.cab[t], t, "cab");
  for (var t of Object.keys(d.pie)) addTbox(d.pie[t], t, "pie");
  for (var t of Object.keys(d.draw)) addTbox(d.draw[t], t, "draw");
  for (var ban of Object.keys(d.ban)) {
    $(i_banda).append(`<option value="${ban}">${ban}</option`);
    var prim = true;
    for (var t of Object.keys(d.ban[ban])) {
      if (prim) {
        prim = false;
        var top = d.ban[ban][t].at[1];
      }
      d.ban[ban][t].at[1] = top;
      d.ban[ban][t].height = "10.00";
      addTbox(d.ban[ban][t], t, ban);
    }
  }
}

function aliasValido(alias) {
  if (!tagValido(alias)) return false;

  for (var a of $("._" + i_banda.value)) {
    var d = $(a).data("nimbus");
    if (d && alias == d.alias) return false;
  };
  return true;
}

function solicitarAlias() {
  var alias = "";
  if (i_banda.value == "draw") {
    // Generar alias automático
    max = 0;
    for (var e of $("._draw")) {
      var dat = $(e).data("nimbus");
      if (dat) {
        var n = parseInt(dat.alias.slice(2));
        if (n > max) max = n;
      }
    }
    alias = `e_${max + 1}`;
  } else {
    // Solicitar alias
    var msg = "Alias";
    while(true) {
      alias = prompt(msg, alias);
      if (alias == null || aliasValido(alias)) break;
      msg = "Alias inválido o repetido";
    }
  }
  return(alias);
}

function view1banda() {
  return b_view_bandas.innerText == "visibility";
}

function viewBandas() {
  if (view1banda()) {
    b_view_bandas.innerText = "visibility_off";
    b_view_bandas.title = "Ocultar elementos de otras bandas (Alt+v)";
    $(".elemento").css("display", "table");
    $(".div-banda").css("display", "block");
  } else {
    b_view_bandas.innerText = "visibility";
    b_view_bandas.title = "Mostrar elementos de todas las bandas (Alt+v)";
    $(".elemento, .div-banda").css("display", "none");
    $(`._${i_banda.value}:not(.div-banda)`).css("display", "table");
    $(`._${i_banda.value}.div-banda`).css("display", "block");
  }
}

function setTitulo() {
  document.title = `Nimpdf - ${ymlFile ? ymlFile : "Nuevo"}`;
  b_grabar.title = `Grabar (Alt+g)${ymlFile ? ' "' + ymlFile + '"' : ""}`;
}

function newDoc() {
  window.open("/nimpdf");
}

function openDoc() {
  var f = prompt("Archivo:");
  if (f) window.open(`/nimpdf?yml=${f}`);
}

function banda2json(banda) {
  var jsn = {};
  var bd = banDetalle(banda);
  for (var ban of $(`._${banda}:not(.div-banda)`)) {
    var d = $(ban).data("nimbus");
    var j = jsn[d.alias] = {};

    j.at = d.at;
    j.width = d.width;
    if (!bd) j.height = d.height;
    if (d.texto) j.texto = d.texto;
    if (d.align != "left") j.align = d.align;
    if (d.valign != "center") j.valign = d.valign;
    if (d.style != "normal") j.style = d.style;
    if (d.overflow != "truncate") j.overflow = d.overflow;
    if (d.min_font_size != "5.00") j.min_font_size = d.min_font_size;
    if (d.imagen) j.imagen = d.imagen;
    if (d.color != "#000000") j.color = d.color;
    if (d.bgcolor != "#ffffff") j.bgcolor = d.bgcolor;
    if (d.borde != 0) j.borde = d.borde;
    if (d.brcolor != "#000000") j.brcolor = d.brcolor;
    if (d.pad_l != 0) j.pad_l = d.pad_l;
    if (d.pad_r != 0) j.pad_r = d.pad_r;
    if (d.pad_t != 0) j.pad_t = d.pad_t;
    if (d.pad_b != 0) j.pad_b = d.pad_b;
    if (d.render != "auto") j.render = d.render;
    if (banda != "draw") {
      if (d.font != "Helvetica") j.font = d.font;
      if (d.size != 12) j.size = d.size;
      if (d.leading != 0) j.leading = d.leading;
    }
  }

  return jsn;
}

function genJson() {
  var dat = {def: {}, pag: {}, cab: {}, pie: {}};

  if (i_font_def.value != "Helvetica") dat.def.font = i_font_def.value;
  if (i_font_size_def.value != "12.00") dat.def.font_size = i_font_size_def.value;
  if (i_interlineado_def.value != "0.00") dat.def.leading = i_interlineado_def.value;
  if (i_grosor_linea.value != "1.00") dat.def.grosor_linea = i_grosor_linea.value;

  if (i_formato_pag.value != "A4") dat.pag.size = i_formato_pag.value == "CUSTOM" ? [i_ancho_pag.value, i_alto_pag.value] : i_formato_pag.value;
  if (i_orientacion_pag.value == "landscape") dat.pag.layout = "landscape";
  if (i_top_margin.value != "0.00") dat.pag.top_margin = i_top_margin.value;
  if ( i_bottom_margin.value != "0.00") dat.pag.bottom_margin = i_bottom_margin.value;
  if (i_fondo.value) dat.pag.fondo = i_fondo.value;

  dat.cab = banda2json("cab");
  dat.pie = banda2json("pie");
  dat.draw = banda2json("draw");
  dat.ban = {};
  for (b of Array.from(i_banda.options).slice(4)) dat.ban[b.value] = banda2json(b.value);

  return dat;
}

function grabarDoc() {
  if (ymlFile) {
    var fic = ymlFile;
  } else {
    var fic = prompt("Archivo (con toda la ruta desde la raíz del proyecto)");
    if (!fic) return;
    if (!fic.endsWith(".yml")) fic += ".yml";
  }

  jsonOrg = genJson();

  ponBusy();
  nimAjax(
    'grabar_doc',
    {fic: fic, new: !ymlFile, dat: jsonOrg},
    {
      complete: quitaBusy,
      timeout: 10000,
      error: function(xhr){alert("Error interno\n\n" + xhr.responseText)},
      success: function(res) {
        if (res == "ok") {
          ymlFile = fic;
          setTitulo();
        } else {
          alert(res);
        }
      }
    }
  );
}

function banDetalle(ban) {
  return !["cab", "pie", "draw"].includes(ban ? ban : i_banda.value);
}

function urlImagen(img = i_fondo.value) {
  if (!img) return "";

  if (!img.startsWith("~/")) {
    var usl = ymlFile.lastIndexOf("/");
    if (usl > 0) img = "~/" + ymlFile.slice(0, usl + 1) + img;
  }
  return `url("nim_send_file?file=${img}")`;
}

function modoFondo() {
  if (b_fondo.innerText == "visibility") {
    b_fondo.innerText = "visibility_off";
    b_fondo.title = "Ocultar imagen de fondo (Alt+f)";
    canvas.style.backgroundImage = urlImagen();
  } else {
    b_fondo.innerText = "visibility";
    canvas.style.backgroundImage = "none";
    b_fondo.title = "Mostrar imagen de fondo (Alt+f)";
  }
}

function modoClonar() {
  if (clonar) {
    clonar = false;
    b_clonar.style.backgroundColor = "";
    b_clonar.title = "Activar clonación";
    $(".elemento").draggable("option", "helper", "original").css("cursor", "move");
  } else {
    clonar = true;
    b_clonar.style.backgroundColor = "blue";
    b_clonar.title = "Desactivar clonación";
    $(".elemento").draggable("option", "helper", "clone").css("cursor", "copy");
  }
}

function openDialogoConfirmacion() {
  $(d_confirmacion).css("display", "block").position({my: "top", at: "top+20", of: "#cont_canvas"}).find("button").first().focus();
}

function closeDialogoConfirmacion() {
  $(".nim-body-modal").remove();
  d_confirmacion.style.display = "none";
}

function confirmarBorrado() {
  if (modoBorrado == "e") {
    // Borrado del elemento activo
    activo.remove();
    activo = null;
    selElemento(null);
    $(i_banda).trigger("change", false); // Para cargar de nuevo los elemento que quedan en la banda
  } else {
    // Borrado de banda
    var ban = i_banda.value;
    $("._" + ban).remove();
    if (banDetalle(ban)) {
      for (var op of $("#i_banda option")) if (op.value == ban) {$(op).remove(); break;}
      $(i_banda).val("cab").trigger("change");
    } else {
      $(i_banda).trigger("change");
    }
  }
  closeDialogoConfirmacion();
}

function delElemento() {
  if (!activo) return;

  modoBorrado = "e";
  $("body").append("<div class='nim-body-modal'></div>");
  l_confirmacion.innerText = `¿Desea eliminar el elemento "${activo.data("nimbus").alias}"?`;
  openDialogoConfirmacion();
}

function delBanda() {
  modoBorrado = "b";
  $("body").append("<div class='nim-body-modal'></div>");
  var ban = i_banda.options[i_banda.selectedIndex].innerText;
  l_confirmacion.innerText = banDetalle() ? `¿Desea eliminar la banda "${ban}" y todo su contenido?` : `¿Desea eliminar todos los elementos de la banda "${ban}"?`;
  openDialogoConfirmacion();
}

function resetPuntoIni() {
  puntoIni = null;
  div_contorno.style.display = "none";
  $canvas.find("*").removeClass("cursor-crosshair");
}

function snapPunto(x, y) {
  var tol = 15;
  resetExtraHandle();
  for (var e of $("._draw")) {
    if (x > e.offsetLeft - tol && x < e.offsetLeft + e.offsetWidth + tol) {
      var d1  = Math.abs(y - e.offsetTop);
      var d2  =  Math.abs(y - (e.offsetTop + e.offsetHeight));
      if (d1 < d2 && d1 < tol) y = e.offsetTop;
      else if (d2 < tol) y = e.offsetTop + e.offsetHeight;
    }
    if (y > e.offsetTop - tol && y < e.offsetTop + e.offsetHeight + tol) {
      var d1  = Math.abs(x - e.offsetLeft);
      var d2  =  Math.abs(x - (e.offsetLeft + e.offsetWidth));
      if (d1 < d2 && d1 < tol) x = e.offsetLeft;
      else if (d2 < tol) x = e.offsetLeft + e.offsetWidth;
    }
  }
  setExtraHandle();
  return [x, y];
}

function ayuda() {
  window.open("/nimpdf_help", "nimpdf_help");
}

$(window).load(function() {
  if (formato.error) {
    alert(formato.error);
    window.close();
    // Por si no se ha cerrado la ventana (por haberse abierto desde la barra de direcciones)
    $("body").css("display", "none")
    return;
  }

  setTitulo();

  $canvas = $("#canvas");

  // Cargar formatos de papel en la select
  var htm = "";
  for (var f of Object.keys(formatosPag)) htm += `<option value="${f}">${f}</option>`
  $(i_formato_pag).append(htm);

  // Añadir lista de fonts asociada a los inputs correspondientes
  var htm = "";
  for (var f of fonts) htm += `<option>${f}</option>`
  $("#i_font, #i_font_def").after(`<select class="select-for">${htm}</select>`);
  $(".select-for").click(function() {
    var inp = $(this).prev()[0];
    inp.value = this.value;
    if (inp == i_font) activo.data("nimbus").font = this.value;
  });

  cargarDatos(formato);

  // Obtenemos el Json que se grabaría en este momento para ver si ha habido cambios al abandonar la página
  jsonOrg = genJson();

  // Quedarnos con el valor anterior en todos los inputs
  $(":input").focus(function() {oldValue = this.value});

  $(margen_top).draggable({
    axis: "y",
    containment: "parent",
    drag: function(e, ui) {
      var c = px2ptH(ui.position.top);
      if (c < alto - i_bottom_margin.value - 15) {
        i_top_margin.value = c;
      } else {
        // Al dar un valor inválido (null) conseguimos que se mantenga la última
        // posición y por lo tanto se detenga el drag.
        ui.position.top = null;
      }
      margen_top_guia.style.top = ui.position.top + "px";
    }
  });

  $(margen_bottom).draggable({
    axis: "y",
    containment: "parent",
    drag: function(e, ui) {
      if (ui.position.top >= cont_canvas.scrollHeight - 1) {
        ui.position.top = cont_canvas.scrollHeight - 1;
        i_bottom_margin.value = "0.00";
      } else {
        var c = px2ptY(ui.position.top);
        if (c < alto - i_top_margin.value - 15) {
          i_bottom_margin.value = c < 1 ? "0.00" : c;
        } else {
          // Al dar un valor inválido (null) conseguimos que se mantenga la última
          // posición y por lo tanto se detenga el drag.
          ui.position.top = null;
        }
      }
      margen_bottom_guia.style.top = ui.position.top + "px";
    }
  });

  $(i_banda).change(function(e, desel = true) {
    var elementos = $("._" + this.value);
    if (desel) {
      selElemento(null);
      if (view1banda()) {
        $(".elemento, .div-banda").css("display", "none");
        elementos.css("display", "block");
      }
    }
    // Cargar en bandas_cont todos los elementos de la banda seleccionada
    var htm = "";
    for (var e of elementos) {if (!$(e).hasClass("div-banda")) htm += `<label elemento="${e.id}">${$(e).data("nimbus").alias}</label><br>`};
    bandas_cont.innerHTML = htm;
    $(this).blur();
  });

  // Seleccionar el elemento al hacer click en uno de los elementos de la banda
  $("#bandas_cont").on("click", "label", function() {selElemento($(`#${$(this).attr("elemento")}`))});

  // Asegurar dos decimales en todos los inputs de tipo "coord"
  $(".coord").change(function() {this.value = parseFloat(this.value).toFixed(2);});

  // Control de cambios en los inputs de propiedades

  $(i_alias).change(function() {
    if (!aliasValido(this.value)) {
      alert("Alias no válido o repetido");
      this.value = oldValue;
      this.focus();
    }
    activo.data("nimbus").alias = this.value;
    $(i_banda).trigger("change", false);
    marcarElementoBanda();
  });

  $(i_x).change(function() {
    if (this.value < 0) {
      this.value = "0.00";
    } else {
      var maxX = ancho - activo.data("nimbus").width;
      if (this.value > maxX) this.value = maxX.toFixed(2);
    }
    activo.data("nimbus").at[0] = this.value;
    activo[0].style.left = pt2pxX(this.value);
  });

  $(i_y).change(function() {
    if (this.value > alto) {
      this.value = alto;
    } else {
      var minY = parseFloat(activo.data("nimbus").height);
      if (this.value < minY) this.value = minY;
    }
    activo.data("nimbus").at[1] = this.value;
    activo[0].style.top = pt2pxY(this.value);
  });

  $(i_ancho).change(function() {
    var dat = activo.data("nimbus");

    if (this.value < 1) {
      this.value = "1.00";
    } else {
      var maxW = ancho - activo.data("nimbus").at[0];
      if (this.value > maxW) this.value = maxW.toFixed(2);
    }
    if (dat.vh == "v" && this.value > parseFloat(dat.height)) this.value = dat.height;
    if (dat.vh == "h" && this.value < parseFloat(dat.height)) this.value = dat.height;

    dat.width = this.value;
    dat.vh ? setDrawWH(activo) : activo[0].style.width = pt2pxX(this.value);
  });

  $(i_alto).change(function() {
    var dat = activo.data("nimbus");

    if (this.value < 1) {
      this.value = "1.00";
    } else {
      var maxH = parseFloat(activo.data("nimbus").at[1]);
      if (this.value > maxH) this.value = maxH;
    }
    if (dat.vh == "h" && this.value > parseFloat(dat.width)) this.value = dat.width;
    if (dat.vh == "v" && this.value < parseFloat(dat.width)) this.value = dat.width;

    dat.height = this.value;
    dat.vh ?  setDrawWH(activo) : activo[0].style.height = pt2pxH(this.value);
  });

  $(i_texto).change(function() {
    activo.data("nimbus").texto = this.value
    activo.find("label").text(this.value);
  });
  
  $(i_alineacion_h).change(function() {
    activo.data("nimbus").align = this.value
    activo.css("text-align", this.value);
  });
  
  $(i_alineacion_v).change(function() {
    activo.data("nimbus").valign = this.value
    activo.find("label").css("vertical-align", this.value == "center" ? "middle" : this.value);
  });

  $(i_font).change(function(){activo.data("nimbus").font = this.value});
  $(i_estilo).change(function(){activo.data("nimbus").style = this.value});
  $(i_font_size).change(function() {
    if (this.value < 1) this.value = "1.00";
    activo.data("nimbus").size = this.value
    activo.css("font-size", pt2pxH(this.value));
  });

  $(i_overflow).change(function(){activo.data("nimbus").overflow = this.value});
  $(i_min_font_size).change(function() {
    if (this.value < 1) this.value = "1.00";
    activo.data("nimbus").min_font_size = this.value
  });

  $(i_interlineado).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").leading = this.value
  });
  $(i_imagen).change(function() {
    activo.data("nimbus").imagen = this.value
    activo.css("background-image", urlImagen(this.value));
    this.value ? activo.removeClass("bgcolor-sin-imagen").addClass("bgcolor-con-imagen") : activo.removeClass("bgcolor-con-imagen").addClass("bgcolor-sin-imagen");
  });
  $(i_color).change(function(){activo.data("nimbus").color = this.value});
  $(i_bgcolor).change(function(){activo.data("nimbus").bgcolor = this.value});
  $(i_borde).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").borde = this.value
  });
  $(i_brcolor).change(function(){activo.data("nimbus").brcolor = this.value});
  $(i_pad_l).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").pad_l = this.value
  });
  $(i_pad_r).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").pad_r = this.value
  });
  $(i_pad_t).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").pad_t = this.value
  });
  $(i_pad_b).change(function() {
    if (this.value < 0) this.value = "0.00";
    activo.data("nimbus").pad_b = this.value
  });
  $(i_render).change(function(){activo.data("nimbus").render = this.value});

  // Control de cambios en los inputs de configuración de página

  $(i_formato_pag).change(function() {
    if (this.value == "CUSTOM") {
      i_ancho_pag.disabled = i_alto_pag.disabled = false;
    } else {
      i_ancho_pag.value = formatosPag[this.value][0];
      i_alto_pag.value = formatosPag[this.value][1];
      if (i_orientacion_pag.value = "portrait") {
        ancho = parseFloat(i_ancho_pag.value);
        alto = parseFloat(i_alto_pag.value);
      } else {
        ancho = parseFloat(i_alto_pag.value);
        alto = parseFloat(i_ancho_pag.value);
      }
      i_ancho_pag.disabled = i_alto_pag.disabled = true;
      ajustaCanvas();
    }
  });

  $(i_orientacion_pag).change(function() {
    [ancho, alto] = [alto, ancho];
    ajustaCanvas();
  });

  $(i_ancho_pag).change(function() {
    i_orientacion_pag.value == "portrait" ? ancho = parseFloat(this.value) : alto = parseFloat(this.value);
    ajustaCanvas();
  });
  $(i_alto_pag).change(function() {
    i_orientacion_pag.value == "portrait" ? alto = parseFloat(this.value) : ancho = parseFloat(this.value);
    ajustaCanvas();
  });

  $(i_top_margin).change(function() {
    if (this.value < 0) this.value = "0.00";
    var max = alto - i_bottom_margin.value - 15;
    if (this.value > max) this.value = max;
    margen_top.style.top = margen_top_guia.style.top = pt2pxY(alto - this.value);
  });
  $(i_bottom_margin).change(function() {
    if (this.value < 0) this.value = "0.00";
    var max = alto - i_top_margin.value - 15;
    if (this.value > max) this.value = max;
    ajustaMargenBottom(this.value);
  });

  $(i_fondo).change(function() {
    canvas.style.backgroundImage = urlImagen();
  });

  $(i_interlineado_def).change(function() {
    if (this.value < 0) this.value = 0;
  });

  $(i_grosor_linea).change(function() {
    if (this.value < 1) this.value = 1;
  });

  $canvas.mousemove(function(e) {
    var x = e.pageX - canvasLeft + cont_canvas.scrollLeft;
    var y = e.pageY - canvasTop + cont_canvas.scrollTop;
    pos_x.innerText = px2ptX(x);
    pos_y.innerText = px2ptY(y);
    if (puntoIni) {
      switch (i_banda.value) {
        case "draw":
          var w = Math.abs(x - puntoIni[0]);
          var h = Math.abs(y - puntoIni[1]);
          if (w > h) {
            div_contorno.style.width = w + "px";
            div_contorno.style.height = 0;
            div_contorno.style.left = Math.min(puntoIni[0], x) + "px";
            div_contorno.style.top = puntoIni[1] + "px";
          } else {
            div_contorno.style.width = 0;
            div_contorno.style.height = h + "px";
            div_contorno.style.left = puntoIni[0] + "px";
            div_contorno.style.top = Math.min(puntoIni[1], y) + "px";
          }
          break;
        case "cab":
        case "pie":
          div_contorno.style.top = Math.min(puntoIni[1], y) + "px";
          div_contorno.style.height = Math.abs(y - puntoIni[1]) + "px";
        default:
          // Bandas de detalle
          div_contorno.style.left = Math.min(puntoIni[0], x) + "px";
          div_contorno.style.width = Math.abs(x - puntoIni[0]) + "px";
      }
    }
  }).mouseleave(function() {
    pos_x.innerText = "-----";
    pos_y.innerText = "-----";
  }).mousedown(function(e) {
    if (e.button != 0) return;  // Tratar solo el botón izquierdo

    var x = e.pageX - canvasLeft + cont_canvas.scrollLeft;
    var y = e.pageY - canvasTop + cont_canvas.scrollTop;
    var ban = i_banda.value;
    var bd = banDetalle(ban);
    var dat = bd ? $(`._${ban}:not(.div-banda)`).data("nimbus") : null;
    var top = dat ? dat.at[1] : null;
    if (puntoIni) {
      var draw = (ban == "draw");
      var w = px2ptX(div_contorno.offsetWidth);
      var h = px2ptH(div_contorno.offsetHeight);
      if (draw) {
        parseFloat(w) > parseFloat(h) ? h = i_grosor_linea.value : w = i_grosor_linea.value;
      } else if (bd) {
        h = "10.00";
      }

      addTbox({
        at: [px2ptX(div_contorno.offsetLeft), top ? top : px2ptY(div_contorno.offsetTop)],
        width: w,
        height: h
      }, solicitarAlias());

      resetPuntoIni();
    } else if (e.target == canvas || $(e.target).hasClass("div-banda")) {
      puntoIni = e.altKey ? snapPunto(x, y) : [x, y];
      div_contorno.style.display = "block";
      div_contorno.style.left = puntoIni[0] + "px";
      div_contorno.style.top = top ? pt2pxY(top) : puntoIni[1] + "px";
      div_contorno.style.width = 0;
      div_contorno.style.height = bd ? pt2pxH(10) : 0;
      $canvas.find("*").addClass("cursor-crosshair");
    } else {
      var t = $(e.target);
      if (t.hasClass("elemento") || t.parent().hasClass("elemento")) {
        // Quitamos el extra de anchura/altura para que el "snap" ajuste a las dimensiones reales
        // Esto es en previsión de que el usuario inicie una maniobra de drag o resize
        // No se puede relegar esta función al callback "start" de draggable/resizable porque
        // éstos cachean las dimensiones de todos los elementos antes de disparar el callback
        resetExtraHandle();
        mouseDownOnElemento = true;
      }
    }
  }).mouseup(function(e) {
    if (mouseDownOnElemento) {
      setExtraHandle();
      mouseDownOnElemento = false;
    }
  });

  // Configuración de diálogos
  $(d_pag).draggable({
    handle: ".dialogo-tit",
    containment: "body"
  });

  $(d_confirmacion).css("z-index", 100001).draggable({
    handle: ".dialogo-tit",
    containment: "body"
  });

  // Calcular la posición de canvas relativa a la ventana del navegador
  canvasTop = barra_herramientas.offsetHeight;

  redim();

  // Mostramos la imagen de fondo
  $(b_fondo).trigger("click");

  // Seleccionamos por defecto todas las bandas visibles
  $(b_view_bandas).trigger("click");
  
  // Seleccionar la banda de cabecera (que es la seleccionada por defecto) como banda activa
  $(i_banda).trigger("change", false);
})
.click(function(e) {
  // Si se hace click fuera de cualquier input, forzamos la pérdida de foco para que
  // los atajos de teclado funcionen directos (sin Alt)
  if (!$(e.target).is(":input")) $(":focus").blur();
})
.keydown(function(e) {
  // Atajos de teclado

  if (e.keyCode == 27) {
    closeDialogoConfirmacion();
    resetPuntoIni();
    return;
  }

  if (e.shiftKey) return;
  if (e.altKey && e.ctrlKey) return

  var k = e.key;
  var c = e.keyCode;
  var del = c == 8 || c == 46;
  var ctrPerm = del || k == "+" || k == "-" || c >= 37 && c <= 40;

  if (e.ctrlKey) {
     if (!ctrPerm) return;
  } else if (e.target != document.body && !e.altKey) return;

  var pd = true;
  if (del) e.ctrlKey ? delBanda() : delElemento();
  else if (k == "+") ajustaCanvas(zoom + 0.05);
  else if (k == "-") ajustaCanvas(zoom - 0.05);
  else if (k == "0") ajustaCanvas(0);
  else if (k >= "1" && k <= "9") ajustaCanvas(1 + (parseInt(k) - 1) * 0.05);
  else if (k == "a") openDoc();
  else if (k == "b") addBanda();
  else if (k == "c") modoClonar();
  else if (k == "f") modoFondo();
  else if (k == "g") grabarDoc();
  else if (k == "h") ayuda();
  else if (k == "n") newDoc();
  else if (k == "p") dialogOpenClose("d_pag");
  else if (k == "v") viewBandas();
  else if (c == 37) {
    if (activo) {
      if (e.ctrlKey) {
        i_ancho.value = parseFloat(i_ancho.value) - 0.1;
        $(i_ancho).trigger("change")
      } else {
        i_x.value = parseFloat(i_x.value) - 0.1;
        $(i_x).trigger("change")
      }
    }
  }
  else if (c == 38) {
    if (activo && !banDetalle()) {
      if (e.ctrlKey) {
        i_alto.value = parseFloat(i_alto.value) - 0.1;
        $(i_alto).trigger("change")
      } else {
        i_y.value = parseFloat(i_y.value) + 0.1;
        $(i_y).trigger("change")
      }
    }
  }
  else if (c == 39) {
    if (activo) {
      if (e.ctrlKey) {
        i_ancho.value = parseFloat(i_ancho.value) + 0.1;
        $(i_ancho).trigger("change")
      } else {
        i_x.value = parseFloat(i_x.value) + 0.1;
        $(i_x).trigger("change")
      }
    }
  }
  else if (c == 40) {
    if (activo && !banDetalle()) {
      if (e.ctrlKey) {
        i_alto.value = parseFloat(i_alto.value) + 0.1;
        $(i_alto).trigger("change")
      } else {
        i_y.value = parseFloat(i_y.value) - 0.1;
        $(i_y).trigger("change")
      }
    }
  }
  else pd = false;

  if (pd) e.preventDefault();
})
.resize(function(e) {if (e.target == window) redim();})
.on("beforeunload", function() {
  if (JSON.stringify(jsonOrg) != JSON.stringify(genJson())) return "";
});