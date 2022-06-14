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
  $("iframe").css("display", "none");
}

function fonStopDrag(e, ui) {
  $("iframe").css("display", "block");
  ajustaWin();
}

var nPan = 0;
var propWin = {w: 500, h: 500};

function calculaPosWin() {
  var ll, lr, t, l, r, b;

  var posWin = {left: 0, top: 60};
  var bt = 999999;
  while (true) {
    ll = 999999;
    $(".elemento-panel").each(function () {
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

function creaWin(url, prop, lbl) {
  if (prop == undefined) {
    var p = calculaPosWin();
    if (!url || lbl == undefined)
      prop = {top: p.top, left: p.left, width: propWin.w, height: propWin.h, zi: nPan, vtit: 'block', zoom: 1, lbl: lbl};
    else
      prop = {top: p.top, left: p.left, zi: nPan, lbl: lbl};
  }

  var did = "d" + nPan;
  var fid = "f" + nPan;
  var tid = "t" + nPan;

  if (prop.lbl == undefined) {
    // Ventanas
    var htm =
      //'<div id="rt' + nPan + '" class="res-tit"></div>' +
      '<div class="res-tit res-tit-1"></div>' +
      '<div class="res-tit res-tit-2"></div>' +
      '<div id="' + tid + '" class="div-titulo ui-widget-header" style="display:' + prop.vtit + '">' +
      /**
      '<button id="bzm' + nPan + '" onclick="myZoom($(\'#' + fid + '\'), -1)">Zoom -</button>' +
      '<button id="bzp' + nPan + '" onclick="myZoom($(\'#' + fid + '\'), +1)">Zoom +</button>' +
      '<button id="brl' + nPan + '" onclick="$(\'#' + fid + '\').attr(\'src\', function(i,v){return v;})">Recargar contenido</button>' +
      '<button id="bht' + nPan + '" onclick="$(\'#' + tid + '\').css(\'display\', \'none\')">Ocultar título</button>' +
      '<button id="brm' + nPan + '" onclick="$(\'#' + did + '\').remove()">Cerrar</button>' +
      **/
      '<i class="material-icons win-icons" title="Zoom -" onclick="myZoom($(\'#' + fid + '\'), -1)">zoom_out</i>' +
      '<i class="material-icons win-icons" title="Zoom +" onclick="myZoom($(\'#' + fid + '\'), +1)">zoom_in</i>' +
      '<i class="material-icons win-icons" title="Recargar contenido" onclick="$(\'#' + fid + '\').attr(\'src\', function(i,v){return v;})">refresh</i>' +
      '<i class="material-icons win-icons" title="Ocultar título" onclick="$(\'#' + tid + '\').css(\'display\', \'none\')">expand_less</i>' +
      '<i class="material-icons win-icons" title="Cerrar ventana" onclick="$(\'#' + did + '\').remove()">close</i>' +
      '</div>' +
      '<iframe id="' + fid + '" class="ficha" src=' + url + '></iframe>';

    $("<div class='base elemento-panel' id='" + did + "'>").
      appendTo($("#div-body")).
      draggable({snap: true, handle: "div", containment: "parent", scroll: true, start: fonStartDrag, stop: fonStopDrag}).
      resizable({containment: "parent", handles: "n, e, s, w, se", autoHide: true, start: fonStartDrag, stop: fonStopDrag}).
      css('left', prop.left).
      css('top', prop.top).
      css('width', prop.width).
      css('height', prop.height).
      css('z-index', prop.zi).
      append(htm);

    /*
    $("#bzm" + nPan).button({icons: {primary: "ui-icon-zoomout"}, text: false});
    $("#bzp" + nPan).button({icons: {primary: "ui-icon-zoomin"}, text: false});
    $("#brl" + nPan).button({icons: {primary: "ui-icon-refresh"}, text: false});
    $("#bht" + nPan).button({icons: {primary: "ui-icon-arrow-n"}, text: false});
    $("#brm" + nPan).button({icons: {primary: "ui-icon-closethick"}, text: false});
    */
  } else {
    if (url) {
      // Favoritos
      var chk = $("#actPan").is(":checked");
      var htm =
        '<div id="rt' + nPan + '" class="div-fav">' +
        '<a href=' + url + ' target="_blank" class="url-fav">' + prop.lbl + '</a>' +
        '<div class=div-del-fav>' +
        //'<i class="material-icons del-fav" title="Eliminar favorito" onclick="$(\'#' + did + '\').remove()">clear</i>' +
        '<i class="material-icons del-fav" title="Eliminar favorito" onclick="cierraElem($(\'#' + did + '\'))">clear</i>' +
        '</div></div>';

      $("<div class='base-fav elemento-panel' id='" + did + "'>").
        appendTo(prop.cont ? prop.cont : $("#div-body")).
        draggable({snap: true, handle: "div", containment: $("#div-body"), scroll: true,
          start: function(e, ui) {
            dragActivo = true;
          },
          stop: ajustaWin
        }).
        mousedown(function() {
          dragActivo = false;
          var par = $(this).parent();
          if (par.hasClass("contenedor")){
            dragParent = par;
            var di = $(this);
            var top = di.offset().top;
            var left = di.offset().left;
            di.detach().css("top", top).css("left", left).appendTo($("#div-body"));
          } else {
            dragParent = null;
          }
        }).
        mouseup(function() {
          if (!dragActivo && dragParent) {
            var di = $(this);
            if ($("i:hover").length != 0) {
              // Estamos sobre el icono de cerrar favorito
              //di.remove();
              cierraElem(di);
              return;
            }
            //if ($("a:hover").length != 0) window.open(di.find("a").attr("href"), "_blank");
            if ($("a:hover").length != 0 && !checkNimServerStop()) window.open(di.find("a").attr("href"), "_blank");
            var dp = dragParent.parent();
            var top = di.position().top - dragParent.position().top - dp.position().top + dragParent.scrollTop();
            var left = di.position().left - dragParent.position().left - dp.position().left + dragParent.scrollLeft();
            di.detach().css("top", top).css("left", left).appendTo(dragParent);
          }
        }).
        resizable({containment: "parent", snap: true, handles: "e", start: function() {$(this).find("i").css("display", "none")}, stop: function() {$(this).find("i").css("display", "inline")}}).
        css('left', prop.left).
        css('top', prop.top).
        css('z-index', prop.zi).
        append(htm);

      var div = $("#" + did);
      if (prop.width == undefined) {
        prop.minw = div.width();
      } else {
        div.css("width", prop.width)
      }
      div.resizable("option", "minWidth", prop.minw);
    } else {
      // Contenedores
      var htm = 
        '<p class="tit-contenedor">' + prop.lbl + '</p>' +
        '<div class="bot-contenedor">' +
        '<i class="material-icons edit-tit-cont" title="Editar título">edit</i>' +
        //'<i class="material-icons" title="Eliminar contenedor" onclick="$(\'#' + did + '\').remove()">clear</i>' +
        '<i class="material-icons" title="Eliminar contenedor" onclick="cierraElem($(\'#' + did + '\'))">clear</i>' +
        '</div>';

      $("<div class='base-cont elemento-panel' id='" + did + "'>").
        appendTo($("#div-body")).
        draggable({snap: true, handle: "p", containment: "parent", scroll: true,
          start: function(e, ui) {
          },
          stop: ajustaWin
        }).
        resizable({containment: "parent", handles: "e, s, se"}).
        css('left', prop.left).
        css('top', prop.top).
        css('width', prop.width).
        css('height', prop.height).
        css('z-index', prop.zi).
        append(htm).
        append(
          $("<div class='contenedor'>").
          droppable({
            accept: ".base-fav",
            drop: function(e, ui) {
              var di = $(this);
              var dp = di.parent();
              var top = ui.position.top - di.position().top - dp.position().top + di.scrollTop();
              var left = ui.position.left - di.position().left - dp.position().left + di.scrollLeft();
              ui.draggable.detach().css("top", top).css("left", left).appendTo($(this));
            }
          })
        );
    }
  } 

  nPan += 1;
  ajustaWin();
}

function ajustaWin() {
  var el, wm, hm, wmax = 0, hmax = 0;
  $(".elemento-panel").each(function () {
    el = $(this);
    //wm = parseInt($(this).css("left")) + parseInt($(this).css("width"));
    wm = el.position().left + el.width();
    if (wm > wmax) wmax = wm;
    //hm = parseInt($(this).css("top")) + parseInt($(this).css("height"));
    hm = el.position().top + el.height();
    if (hm > hmax) hmax = hm;
  });

  //for (i = 0; i < 2; i++) { // Por si la primera redimensión altera medidas y hay que volver a hacerla
    w = Math.max(wmax, $(window).width());
    h = Math.max(hmax, $(window).height());

    $("#div-body").css("height", h + "px").css("width", w + "px");
  //}
}

function cierraElem(el) {
  if ($("#actPan").is(":checked"))
    el.remove();
  else
    nimPopup('Active el panel para eliminar elementos');
}

function session_out() {
  clearTimeout(tmo);
  //alert("<%= nt('no_session') %>");
  alert("La sesión ha caducado");
  window.location.replace('/');
}

function well_auto_comp_error(e, ui) {
  //if (typeof(ui.content) != "undefined" && typeof(ui.content[0]) != "undefined" && ui.content[0].error == 1) {
  if (typeof(ui.content) != "undefined" && ui.content[0] != undefined && ui.content[0].error != undefined) {
    session_out();
  }
}

function set_cookie_emej() {
  //document.cookie = "<%= Nimbus::CookieEmEj %>=" + empresa_id + ":" + ejercicio_id + ";path=/";
  document.cookie = cookieEmEj + "=" + empresa_id + ":" + ejercicio_id + ";path=/";
}

// Función para comprobar periódicamente noticias del servidor

var tmo;

function noticias() {
  $.ajax({url: '/noticias', type: 'POST'});
  tmo = setTimeout(noticias, 60000);
}

function prompTitulo(tit) {
  var lbl = prompt('Título:', tit);
  if (lbl) {
    lbl = lbl.trim();
    return(lbl == "" ? "&nbsp;" : lbl);
  } else
    return(tit && tit != "" ? tit : "&nbsp;");
}

function nimOpenWindow(url, tag, w, h) {
  return window.open(url, tag,
    "location=no" +
    ",menubar=no" +
    ",status=no" +
    ",toolbar=no" +
    ",height=" + h +
    ",width=" + w +
    ",left=" + (window.screenX + (window.innerWidth - w)/2) +
    ",top=" + (window.screenY + 140)
  );
}

nimWinMensaje = null;
nimHtmMensaje = null;
nimServerStop = false;

function nimActData(n, stop, htm) {
  if (nimNoticias) $("#nim-noticias").attr("data-badge", n == 0 ? null : n);
  nimServerStop = stop;
  if (htm && htm != nimHtmMensaje) {
    if (nimWinMensaje) nimWinMensaje.close();
    nimWinMensaje = nimOpenWindow("", "_blank", 700, 500);
    nimWinMensaje.document.write(htm);
  }
  nimHtmMensaje = htm;
}

$(window).load(function () {
  //if (nimNoticias) noticias();
  noticias();

  $("#nim-noticias").click(function (e) {
    if (checkNimServerStop()) return;

    nimOpenWindow("/shownoticias", "noticias", 600, 800);
    $(this).attr("data-badge", null);
  });

  //$("#nim-menu").mmenu({classes: "mm-slide"});
  $("#nim-menu").mmenu({onClick: {close: false}, searchfield: true});

  $("#bAddToPanel, #add-url").click(function (e) {
    var url = prompt('URL:');
    if (url && url.trim() != "") creaWin(url);
  });

  $("#bAddContenedor, #add-cont").click(function (e) {
    creaWin(null, undefined, prompTitulo());
  });

  $("#bSave, #save-panel").click(function (e) {
    e.preventDefault();
    var h = {win: []};
    function add(w, fav) {
      var wh = {};
      wh.zi = w.css("z-index");
      wh.top = w.css("top");
      wh.left = w.css("left");
      wh.width = w.css("width");
      if (fav) {
        // Favoritos
        wh.minw = w.resizable("option", "minWidth");
        var a = w.find("a");
        wh.lbl = a.text();
        wh.src = a.attr("href");
      }
      return(wh);
    }
    // Ventanas
    $(".base").each(function () {
      var w = $(this);
      var wh = add(w);
      wh.height = w.css("height");
      wh.zoom = w.css("zoom");
      wh.vtit = w.find(".div-titulo").css("display");
      wh.src = w.find(".ficha").attr("src");
      h.win.push(wh);
    });

    //Favoritos no pernecientes a ningún contenedor
    $(".base-fav").not(".contenedor .base-fav").each(function () {
      h.win.push(add($(this), true));
    });

    //Contenedores
    $(".base-cont").each(function () {
      var w = $(this);
      var wh = add(w);
      wh.height = w.css("height");
      wh.lbl = w.find(".tit-contenedor").html();
      wh.fav = [];
      // Favoritos dentro del contenedor
      w.find(".base-fav").each(function () {
        wh.fav.push(add($(this), true));
      });
      h.win.push(wh);
    });

    $.ajax({
      url: '/pref_user',
      type: 'POST',
      data: {pref: "panel", data: JSON.stringify(h)}
    });

    nimPopup("Panel guardado");
  });

  $(".cerrar-sesion").click(function (e) {
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
    if ($(window).width() < 670)
      $(".nim-wide").css("display", "none");
    else
      $(".nim-wide").css("display", "block");
  });

  $("body").on("click", ".url-fav", function (e) {
    if (checkNimServerStop()) e.preventDefault();
  });

  $(".menu-ref").click(function (e) {
    e.preventDefault();

    if (checkNimServerStop()) return;
    
    set_cookie_emej();
    var a = $(this).find("a");
    if ($("#actPan").is(":checked")) {
      creaWin(a.attr("href"), undefined, ($("#addFav").is(":checked") ? a.text() : undefined));
    } else {
      w = window.open(a.attr("href"), "_blank");
    }
  });

  $("#act-desact-panel").click(function (e) {
    if ($("#actPan").is(":checked")) {
      $("#actPan").prop("checked", false);
      nimPopup("Panel desactivado");
    } else {
      $("#actPan").prop("checked", true);
      nimPopup("Panel activado");
    }
  });

  $("#fav-win").click(function (e) {
    if ($("#addFav").is(":checked")) {
      $("#addFav").prop("checked", false);
      nimPopup("Las opciones de menú se añadirán como ventanas");
    } else {
      $("#addFav").prop("checked", true);
      nimPopup("Las opciones de menú se añadirán como favoritos");
    }
  });

  $("#hor-ver").click(function (e) {
    if ($("#ampHor").is(":checked")) {
      $("#ampHor").prop("checked", false);
      nimPopup("Los nuevos elementos se añadirán en vertical");
    } else {
      $("#ampHor").prop("checked", true);
      nimPopup("Los nuevos elementos se añadirán en horizontal");
    }
  });

  $("#div-body").on("mouseenter", ".res-tit", function () {
    $(this).parent().find(".div-titulo").css("display", "block");
  }).on("mousedown", ".elemento-panel", function () {
    var z = parseInt($(this).css("z-index"));
    var zmax = 0;
    $(".elemento-panel").each(function() {
      var el = $(this);
      var zi = parseInt(el.css("z-index"));
      if (zi > z) el.css("z-index", zi - 1);
      if (zi > zmax) zmax = zi;
    });
    $(this).css("z-index", zmax);
  }).on("click", ".edit-tit-cont", function () {
    var el = $(this).parent().prev();
    var tit = el.text();
    el.html(prompTitulo(tit));
  }).on("contextmenu", ".base-fav", function (e) {
    e.preventDefault();
    e.stopPropagation();
  }).on("contextmenu", ".base-cont", function (e) {
    e.preventDefault();
    e.stopPropagation();
  }).on("contextmenu", function (e) {
    e.preventDefault();
    if ($("#actPan").is(":checked")) {
      $("#act-desact-panel i").text("open_in_new");
      $("#act-desact-panel span").text("Desactivar panel");
      $("#fav-win").css("display", "block");
      if ($("#addFav").is(":checked")) {
        $("#fav-win i").text("web");
        $("#fav-win span").text("Añadir como ventana");
      } else {
        $("#fav-win i").text("favorite_border");
        $("#fav-win span").text("Añadir como favorito");
      }
    } else {
      $("#act-desact-panel i").text("input");
      $("#act-desact-panel span").text("Activar panel");
      $("#fav-win").css("display", "none");
    }
    if ($("#ampHor").is(":checked")) {
      $("#hor-ver i").text("swap_vert");
      $("#hor-ver span").text("Ampliar en vertical");
    } else {
      $("#hor-ver i").text("swap_horiz");
      $("#hor-ver span").text("Ampliar en horizontal");
    }

    $("#context-menu").css("display", "block").position({my: "top", of: e});
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

  if (numEjer > 0) $("#d-ejercicio").css("visibility", "visible");

  set_cookie_emej();

  $(window).resize(ajustaWin);

  if (panel.win) {
    for (var w of panel.win) {
      if (w.src) {
        // Ventanas y favoritos fuera de contenedores
        creaWin(w.src, w);
      } else {
        // Contenedores y sus favoritos
        creaWin(undefined, w);
        var con = $(".contenedor").last();
        for (var f of w.fav) {
          f.cont = con;
          creaWin(f.src, f);
        }
      }
    }
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
