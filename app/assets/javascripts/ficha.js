function abreDialogo(d) {
  $("#" + d).dialog("open");
}

function historico() {
  if (_factId && _factId > 0) window.open("/histo/" + _controlador + "/" + _factId);
}

function historico_pk() {
  if (_factId && _factId > 0) callFonServer("call_histo_pk");
}

function liFon(li, fon, tipo, side) {
  if ($(li).attr("disabled") == "disabled") return;
  if (typeof fon == 'function')
    fon.call();
  else if (tipo == 'dlg') {
    if (side) window[side]();
    abreDialogo(fon);
  } else {
    if (side == 'js' || side == 'ambos') window[fon]();
    if (side != 'js') callFonServer(fon);
  }
}

function tabClick(tab) {
  _activeTab = tab;
  var tab_name = tab.attr("id").slice(2);
  if (botLockTab.text() == "lock") parent.nimDefaultTab = tab_name;

  if (typeof(_controlador) == "undefined") return;
  
  var fs = "ontab_" + tab_name;
  if ($.inArray(fs, nimOnTabs) >= 0) callFonServer(fs);
  setTimeout(function(){
    if (typeof tabClickUsu == "function") tabClickUsu(tab);
    redimWindow();
    _activeTab.find(":input").filter(":enabled[readonly!='readonly']").first().focus();
  },100);
}

hayCambios = false;

function CambiosPendientesDeGrabar() {
  var jsHay = false;
  if (typeof jsCambios == "function") jsHay = jsCambios();
  return(hayCambios || jsHay);
}

function grabarConTecla(e) {
  e.preventDefault();
  var f = $(":focus");
  f.blur();
  mant_grabar();
  f.focus();
}

function nimLockTabs(def) {
  if (botLockTab.text() == "lock_open" || typeof(def) == "string") {
    if (botLockTab.text() == "lock_open") parent.nimDefaultTab = _activeTab.attr("id").slice(2);
    botLockTab.text("lock").css("color", "#FF4081").prop("title", "Desbloquear pestaña activa");
  } else {
    botLockTab.text("lock_open").css("color", "white").prop("title", "Bloquear pestaña activa en sucesivas ediciones");
    parent.nimDefaultTab = null;
  }
}

window.onbeforeunload = function(e) {
  if (CambiosPendientesDeGrabar()) {
    parent.fichaLoading = false;
    return('Hay cambios pendientes de grabar');
  }
};

$(window).load(function () {
  $("#dialog-borrar").dialog({
    autoOpen: false,
    resizable: false,
    //height:170,
    //width: 350,
    modal: true,
    buttons: {
      "Sí": function() {
        $(this).dialog("close");
        mant_borrar_ok();
      },
      No: function() {
        $(this).dialog("close");
      }
    }
  });

  // Ctr-k Habilita los campos clave
  $(document).keydown(function(e) {
    if (nimGrabacionEnCurso) return;

    if (_pkCmps) {
      // Es el caso de un mantenimiento
      if (e.ctrlKey && e.which == 75) {
        e.preventDefault();
        $(_pkCmps).attr("disabled", false);
      } else if (e.altKey) {
        if (e.which == 70) { // Alt-f
          if (parent != self && $.isFunction(parent.searchBar)) {e.preventDefault(); parent.searchBar();}
        } else if (e.which == 86) { // Alt-v
          if (parent != self && $.isFunction(parent.gridCollapse)) {e.preventDefault(); parent.gridCollapse();}
        } else if (e.which == 78) { // Alt-n
          if (parent != self && $.isFunction(parent.newFicha)) {e.preventDefault(); parent.newFicha();}
        } else if (e.which == 66) { // Alt-b
          if (parent != self && $.isFunction(parent.pkSearch)) {e.preventDefault(); parent.pkSearch();}
        } else if (e.which == 68) { // Alt-d
          if (parent != self && $.isFunction(parent.ospGrid)) {e.preventDefault(); parent.ospGrid();}
        } else if (e.which == 65) { // Alt-a
          if (parent != self && $.isFunction(parent.newFicha)) {
            e.preventDefault();
            $(":focus").blur();
            mant_grabar(true);
          }
        } else if (e.which == 71) { // Alt-g
          grabarConTecla(e);
        }
      }
    } else {
      // Es el caso de un proc
      if (e.altKey && e.which == 71) grabarConTecla(e); // Alt-g
    }
  });

  $(window).resize(redimWindow);

  redimWindow();
  $(".nim-div-tab").css("visibility", "visible");
  //componentHandler.upgradeDom();
  if (parent != self && $.isFunction(parent.redimWindow)) parent.redimWindow();
  $("input,select,textarea").filter(":enabled[readonly!='readonly']").first().focus();

  // Si hay pestañas, activar el botón de bloqueo/desbloqueo de pestañas en sucesivas ediciones.
  botLockTab = $(".nim-tab-lock");
  if (botLockTab.length == 1 && parent != self) {
    _activeTab = $(".nim-div-tab section").first();
    botLockTab.click(nimLockTabs);
    nimLockTabs(parent.nimDefaultTab);
  }

  // Seleccionar pestaña (si se ha indicado en la URL o en la URL del padre)
  var url = new URL(window.location.href);
  var tab = url.searchParams.get("tab");
  if (!tab && parent != self) tab = parent.nimDefaultTab;
  if (tab) $("#h_" + tab + " span")[0].click();
});
