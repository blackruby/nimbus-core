function session_out() {
  clearInterval(tmo);
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

nimWinNoticias = null;
nimWinMensaje = null;
nimHtmMensaje = null;
nimServerStop = false;

var tmo;

window.onbeforeunload = function(e) {
  if (nimWinNoticias && !nimWinNoticias.closed) nimWinNoticias.close();
}

window.addEventListener("load", function() {
  tmo = setInterval(function() {
    $.ajax({
      url: '/noticias',
      type: 'POST',
      data: {news: (!nimWinNoticias || nimWinNoticias.closed) ? false : true},
      success: function(res) {
        if ("n" in res) $("#nim-noticias").attr("data-badge", res.n == 0 ? null : (res.n > 1 ? "9+" : res.n));
        nimServerStop = res.stop;
        if (res.htm && res.htm != nimHtmMensaje) {
          if (nimWinMensaje) nimWinMensaje.close();
          nimWinMensaje = nimOpenWindow("", "_blank", 700, 500);
          nimWinMensaje.document.write(res.htm);
        }
        nimHtmMensaje = res.htm;
      }
    });
  }, 60000);

  $("#nim-noticias").click(function (e) {
    if (checkNimServerStop()) return;

    if (!nimWinNoticias || nimWinNoticias.closed) {
      nimWinNoticias = nimOpenWindow("/shownoticias", "noticias", 660, 800);
      $(this).attr("data-badge", null);
    } else {
      window.open("", "noticias");
    }
  });

  $(".cerrar-sesion").click(function (e) {
    e.preventDefault();
    $.ajax({
      url: '/logout',
      type: 'GET',
      success: function () {
        if (nimWinNoticias && !nimWinNoticias.closed) nimWinNoticias.close();
        window.location.replace('/');
      }
    });
  });

  $("#li-opacidad").click(function (e) {
    e.stopPropagation();
  });
  $("#opacidad").on("input", function (e) {
    $("#bg-img").css("opacity", opacidad.value);
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

  if (bgImg) {
    opacidad.value = panel.opacidad || 1;
    $("#bg-img").css("opacity", opacidad.value).css("background-image", `url(${bgImg})`);
    $("#li-opacidad").css("display", "block");
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
