var menuIndent = 40;

function statusToClass(st) {
  switch(st) {
    case 'p': return "c-permitido";
    case 'b': return "c-sinborrado";
    case 'c': return "c-consulta";
    case 'x': return "c-prohibido";
    default: return "c-herencia";
  }
}

function menuOption(name, clase, status, status_h) {
  cadMenu += "<label class='" + status + " l-menu'>";
  cadMenu += "<i class='material-icons " + clase + "'>" + (clase == 'collapse' ? 'remove_box' : '') + "</i>"
  cadMenu += "<i class='" + statusToClass(status_h) + " material-icons status'>" + (status == 'h' ? '' : 'lock') + "</i>";
  cadMenu += "&nbsp;" + name;
  cadMenu += "</label>";
}

function _genMenu(menu) {
  for (m in menu) {
    if (menu[m].menu) {
      cadMenu += "<div clave='" + m + "' style='margin-top: 2px;margin-bottom: 2px'>";
      menuOption(menu[m].nt, 'collapse', menu[m].st, menu[m].sth);
      cadMenu += "<div class='menu-cont' style='margin-left: " + menuIndent + "px'>";
      _genMenu(menu[m].menu);
      cadMenu += "</div>";
      cadMenu += "</div>";
    } else {
      if (menu[m].url != null) {
        cadMenu += "<div clave='" + m + "'>";
        menuOption(menu[m].nt, 'relleno', menu[m].st, menu[m].sth);
        cadMenu += "</div>";
      } else
        cadMenu += '<div class="titulo-bloques">' + menu[m].nt + '</div>';
    }
  }
}

function genMenu(menu) {
  cadMenu = '';
  _genMenu(menu);
  $("#menu").append(cadMenu);
  delete cadMenu;
}

function cambiaStatus(div, st) {
  div.children().each(function() {
    th =$(this);
    if (th.hasClass('l-menu') && !th.hasClass('h')) return(false);
    if (th.hasClass('menu-cont')) {
      th.children().each(function () {cambiaStatus($(this), st)});
    } else
      th.find('.status').attr('class', statusToClass(st) + " material-icons status");
  });
}

function _generaResult(div, path, menuToServer) {
  div.children().each(function() {
    if ($(this).hasClass("titulo-bloques")) return;
    var sm = $(this).children('div');
    var id = $(this).attr('clave');
    var st = $(this).children().first().attr('class')[0];
    if (st != 'h') menuToServer[path + id] = st;
    if (sm.length > 0) _generaResult(sm, path + id + '/', menuToServer);
  });
}

function generaResult() {
  var menuToServer = {};
  _generaResult($("#menu"), '/', menuToServer);
  return menuToServer;
}

function jsGrabar() {
  var res = generaResult();
  menuOrg = JSON.stringify(res);
  return {data: res};
}

function jsCambios() {
  return _factId != 0 && menuOrg != JSON.stringify(generaResult());
}

function redimMenu() {
  $("#menu").css("height", $(window).height() - $("#menu").offset().top);
}

function colapsar(modo) {
  for (c of $(".collapse")) if (c.innerText == modo) c.click();
}

$(window).load(function () {
  $("#menu").on("click", ".collapse", function (e) {
    e.stopPropagation();

    var st = $(this).text();

    if (st == "remove_box") {
      $(this).text("add_box");
      var vis = "none";
    } else {
      $(this).text("remove_box");
      var vis = "block";
    }

    $(this).parent().parent().find('div').first().css("display", vis);
  });

  var nuevo_status = null;

  $("#menu").
    on("mouseenter", ".l-menu", function (e) {$("#float_opts").appendTo($(this)).css("display", "inline");}).
    on("mouseleave", function (e) {float_opts.style.display = "none";}).
    on("click", ".l-menu", function (e) {
      var st = nuevo_status ? nuevo_status : $('input[name=options]:checked').val();
      nuevo_status = null;
      if (st == 'h') {
        var nst = 'h';
        $(this).parent().parent().parentsUntil("#menu").each(function () {
          var cl = $(this).find('label').first().attr('class')[0];
          if (cl != 'h') {
            nst = cl;
            return false;
          }
        });
      } else {
        var nst = st;
      }

      $(this).attr('class', 'h l-menu');
      cambiaStatus($(this).parent(), nst);
      $(this).attr('class', st + ' l-menu');
      $(this).find('.status').html(st == 'h' ? '' : 'lock').attr('class', statusToClass(nst) + " material-icons status");
    });

  $(".opts").on("click", function (e) {nuevo_status = this.attributes.st.value;});

  if (_factId != 0) {
    main.style.display = 'block';
    redimMenu();
    $(window).resize(redimMenu);
    menuOrg = JSON.stringify(generaResult());
  }
});
