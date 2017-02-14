function allFrames(e, factor) {
  e.children().each(function () {
    if ($(this).is('iframe'))
      myZoom($(this), factor);
    else if ($(this).is('div'))
      allFrames($(this), factor);
  });
}

function myZoom(fr, factor) {
  var b = fr.contents().find("body");

  // Zoom con 'transform' (Mozilla)
  var t = b.css("-moz-transform");
  if (typeof t != "undefined" && t.startsWith("matrix")) {
    var z = parseFloat(t.slice(t.indexOf('(') + 1)) + 0.1 * factor;
  } else {
    var z = 1 + 0.1 * factor;
  }
  var ofs = Math.round(250 * (z - 1));
  var matrix = "matrix(" + z + ",0,0," + z + "," + ofs + "," + ofs + ")";
  b.css("-moz-transform", matrix);

  // Zoom con 'zoom' (Resto de navegadores)
  z = b.css('zoom');
  if (z == "normal") z = 1;
  b.css('zoom', parseFloat(z) + 0.1 * factor);

  allFrames(b, factor);
}

function fonStartDrag(e, ui) {
  //$(ui.helper).children('iframe').css("display", "none");
  $("iframe").css("display", "none");
}

function fonStopDrag(e, ui) {
  //$(ui.helper).children('iframe').css("display", "block");
  $("iframe").css("display", "block");
  ajustaWin();
}

function fonDrag(e, ui) {
  //$("#div-body").css("width", "2000px");
}

var nPan = 0;
var propWin = {w: 500, h: 500};

function calculaPosWin() {
  var ll, lr, t, l, r, b;

  var posWin = {left: 0, top: 60};
  var bt = 999999;
  while (true) {
    ll = 999999;
    $(".base").each(function () {
      t = parseInt($(this).css("top"));
      l = parseInt($(this).css("left"));
      r = l + parseInt($(this).css("width")) - 1;
      b = t + parseInt($(this).css("height")) - 1;
      if (t >= posWin.top + propWin.h || b < posWin.top || l >= posWin.left + propWin.w || r < posWin.left) return(posWin);
      if (l < ll) {
        ll = l;
        lr = r;
      }
      if (b < bt) bt = b;
    });
    var wr = posWin.left + propWin.w;
    if (ll == 999999) {
      if (wr > $(window).width() && !$("#ampHor").is(":checked")) {
        posWin.left = 0;
        posWin.top = bt + 1;
        bt = 999999;
      } else
        break;
    } else
      posWin.left = lr + 1;
  }
  return(posWin)
}

function creaWin(url, prop) {
  if (prop == undefined) {
    var p = calculaPosWin();
    prop = {top: p.top, left: p.left, width: propWin.w, height: propWin.h, zi: nPan, vtit: 'block', zoom: 1}
  }

  var did = "d" + nPan;
  var fid = "f" + nPan;
  var tid = "t" + nPan;
  $("<div class='base' id='" + did + "'>").
    appendTo($("#div-body")).
    draggable({snap: true, handle: "div", containment: "parent", scroll: true, start: fonStartDrag, stop: fonStopDrag, drag: fonDrag}).
    resizable({containment: "parent", handles: "n, e, s, w, se", autoHide: true, start: fonStartDrag, stop: fonStopDrag}).
    css('left', prop.left).
    css('top', prop.top).
    css('width', prop.width).
    css('height', prop.height).
    css('z-index', prop.zi).
    append(
    '<div id="rt' + nPan + '" class="res-tit"></div>' +
    '<div id="' + tid + '" class="div-titulo ui-widget-header" style="display:' + prop.vtit + '">' +
    '<button id="bzm' + nPan + '" onclick="myZoom($(\'#' + fid + '\'), -1)">Zoom -</button>' +
    '<button id="bzp' + nPan + '" onclick="myZoom($(\'#' + fid + '\'), +1)">Zoom +</button>' +
    '<button id="brl' + nPan + '" onclick="$(\'#' + fid + '\').attr(\'src\', function(i,v){return v;})">Recargar contenido</button>' +
    '<button id="bht' + nPan + '" onclick="$(\'#' + tid + '\').css(\'display\', \'none\')">Ocultar título</button>' +
    '<button id="brm' + nPan + '" onclick="$(\'#' + did + '\').remove()">Cerrar</button>' +
    '</div>' +
    '<iframe id="' + fid + '" class="ficha" src=' + url + '></iframe>'
  );

  $("#bzm" + nPan).button({icons: {primary: "ui-icon-zoomout"}, text: false});
  $("#bzp" + nPan).button({icons: {primary: "ui-icon-zoomin"}, text: false});
  $("#brl" + nPan).button({icons: {primary: "ui-icon-refresh"}, text: false});
  $("#bht" + nPan).button({icons: {primary: "ui-icon-arrow-n"}, text: false});
  $("#brm" + nPan).button({icons: {primary: "ui-icon-closethick"}, text: false});

  ajustaWin();
  nPan += 1;
}

function ajustaWin() {
  wmax = hmax = 0;
  $(".base").each(function () {
    wm = parseInt($(this).css("left")) + parseInt($(this).css("width"));
    if (wm > wmax) wmax = wm;
    hm = parseInt($(this).css("top")) + parseInt($(this).css("height"));
    if (hm > hmax) hmax = hm;
  });

  for (i = 0; i < 2; i++) {
    w = Math.max(wmax, $(window).width());
    h = Math.max(hmax, $(window).height());

    $("#div-body").css("height", h + "px");
    $("#div-body").css("width", w + "px");
  }
}

// Tratamiento de la selección de empresa

/*
 var empresa_id = null;
 var empresa_nom = "";
 var ejercicio_id = null;
 var ejercicio_nom = "";
 */

function session_out() {
  clearTimeout(tmo);
  //alert("<%= nt('no_session') %>");
  alert("La sesión ha caducado");
  window.location.replace('/');
}

function well_auto_comp_error(e, ui) {
  if (typeof(ui.content) != "undefined" && typeof(ui.content[0]) != "undefined" && ui.content[0].error == 1) {
    session_out();
  }
}

/*
function graba_emej() {
  $.ajax({
    url: '/usuarios/validar_cell',
    type: 'POST',
    //data: {nocallback: true, id: <%= @usu.id %>, empresa_def_id: empresa_id}
    data: {nocallback: true, id: usu_id, empresa_def_id: empresa_id}
  });

  $.ajax({
    url: '/usuarios/validar_cell',
    type: 'POST',
    //data: {nocallback: true, id: <%= @usu.id %>, ejercicio_def_id: ejercicio_id}
    data: {nocallback: true, id: usu_id, ejercicio_def_id: ejercicio_id}
  });
}
*/

function set_cookie_emej() {
  //document.cookie = "<%= Nimbus::CookieEmEj %>=" + empresa_id + ":" + ejercicio_id + ";path=/";
  document.cookie = cookieEmEj + "=" + empresa_id + ":" + ejercicio_id + ";path=/";
}

// Funciones para comprobar periódicamente noticias del servidor
function noticias() {
  $.ajax({
    url: '/noticias',
    type: 'POST'
  });
}

var tmo;

function noticiass() {
  noticias();
  tmo = setTimeout("noticiass()", 30000);
}

$(window).load(function () {
  //tmo = setTimeout("noticiass()", 30000);

  //$("#nim-menu").mmenu({classes: "mm-slide"});
  $("#nim-menu").mmenu({onClick: {close: false}, searchfield: true});

  $("#bAddToPanel").click(function (e) {
    var url = prompt('URL:');
    if (url != null) creaWin(url);
  });

  $("#bSave").click(function (e) {
    e.preventDefault();
    //h = {wMenu: wMenu, win: []};
    h = {win: []};
    $(".base").each(function () {
      w = $(this);
      id = w.attr("id").slice(1);
      i = h.win.push({});
      wh = h.win[i - 1];
      wh.top = w.css("top");
      wh.left = w.css("left");
      wh.width = w.css("width");
      wh.height = w.css("height");
      wh.zi = w.css("z-index");
      wh.zoom = w.css("zoom");
      wh.vtit = $("#t" + id).css("display");
      wh.src = $("#f" + id).attr("src");
    });

    $.ajax({
      url: '/pref_user',
      type: 'POST',
      data: {pref: "panel", data: JSON.stringify(h)}
    });

    alert('Panel guardado');
  });

  $("#bCerrar").click(function (e) {
    e.preventDefault();
    $.ajax({
      url: '/logout',
      type: 'GET',
      success: function () {
        window.location.replace('/');
      }
    });
  });

  $("#a-menu").click(function (e) {
    //noticias();
    if ($(window).width() < 670)
      $(".nim-wide").css("display", "none");
    else
      $(".nim-wide").css("display", "block");
  });

  $(".menu-ref").click(function (e) {
    e.preventDefault();
    s = $(this)[0].innerHTML;
    ih = s.indexOf('href') + 6;
    s = s.slice(ih);
    url = s.slice(0, s.indexOf('"'));
    set_cookie_emej();
    if ($("#actPan").is(":checked")) {
      creaWin(url);
    } else {
      /*
       w = window.open(url, "_blank", "location=no, menubar=no, status=no, toolbar=no" +
       ",height=800, width=1000" +
       ",left=" + (window.screenX + 10) +
       ",top=" + (window.screenY + 10)
       );
       */
      w = window.open(url, "_blank");
    }
  });

  $("#div-body").on("mouseenter", ".res-tit", function () {
    id = $(this).attr("id").slice(2);
    $("#t" + id).css("display", "block");
  });

  $("#div-body").on("click", ".base", function () {
    zmax = -1;
    $(".base").each(function () {
      z = $(this).css("z-index");
      if (z > zmax) {
        zmax = z;
        obj = $(this);
      }
    });

    z = $(this).css("z-index");
    obj.css("z-index", z);
    $(this).css("z-index", zmax);
  });

  $("#empresa").blur(function () {
    $(this).val(empresa_nom);
  });

  $("#ejercicio").blur(function () {
    $(this).val(ejercicio_nom);
  });

  $("#empresa").autocomplete({
    //source: '/application/auto?type=grid&mod=Empresa',
    source: '/application/auto?type=grid&mod=Empresa&vista=' + _vista + '&cmp=em',
    minLength: 1,
    select: function (e, ui) {
      empresa_id = ui.item.id;
      empresa_nom = ui.item.value;

      ejercicio_id = null;
      ejercicio_nom = "";
      $("#ejercicio").val('');

      // Consultar si tiene ejercicios la empresa para habilitar el campo ejercicio (lo hace la función del servidor en su respuesta)
      //callFonServer('ejercicio_en_menu', {eid: empresa_id});

      callFonServer('cambio_emej', {eid: empresa_id, jid: ejercicio_id});

      //graba_emej();
      //set_cookie_emej();
      //location.reload();
    },
    response: function (e, ui) {
      well_auto_comp_error(e, ui);
    }
  });

  $("#ejercicio").autocomplete({
    //source: '/application/auto?type=grid&mod=Ejercicio&wh=empresa_id=null',
    source: '/application/auto?type=grid&mod=Ejercicio&vista=' + _vista + '&cmp=ej',
    minLength: 1,
    select: function (e, ui) {
      ejercicio_id = ui.item.id;
      ejercicio_nom = ui.item.value;
      callFonServer('cambio_emej', {eid: empresa_id, jid: ejercicio_id});
      //graba_emej();
      //set_cookie_emej();
      //location.reload();
    },
    response: function (e, ui) {
      well_auto_comp_error(e, ui);
    }
  });

  // Inicialización de los campos empresa y ejercicio
  $("#empresa").val(empresa_nom);
  $("#ejercicio").val(ejercicio_nom);
  //$("#ejercicio").autocomplete("option", "source", '/application/auto?type=grid&mod=Ejercicio&wh=empresa_id=' + empresa_id);

  if (numEjer > 0) $("#d-ejercicio").css("visibility", "visible");

  set_cookie_emej();

  $(window).resize(ajustaWin);

  for (var i in panel.win) {
    creaWin(panel.win[i].src, panel.win[i]);
  }

  if (daysLeft) {
    if (daysLeft == 1) {
      var plQ = '';
      var plD = '';
    } else {
      var plQ = 'n';
      var plD = 's';
    }
    alert('Le queda' + plQ + ' menos de ' + daysLeft + ' día' + plD + ' para que caduque su contraseña.\n\nConsidere entrar en su perfil y cambiarla ya.')
  }
});
