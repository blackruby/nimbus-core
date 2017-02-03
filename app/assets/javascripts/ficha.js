function abreDialogo(d) {
  $("#" + d).dialog("open");
}

function historico() {
  if (_factId && _factId > 0) window.open("/histo/" + _controlador + "/" + _factId);
}

function liFon(li, fon, tipo, side) {
  if ($(li).attr("disabled") == "disabled") return;
  if (typeof fon == 'function')
    fon.call();
  else if (tipo == 'dlg')
    abreDialogo(fon);
  else {
    if (side == 'js' || side == 'ambos') window[fon]();
    if (side != 'js') callFonServer(fon);
  }
}

function tabClick(tab) {
  _activeTab = tab;
  setTimeout(function(){
    if (typeof tabClickUsu == "function") tabClickUsu(tab);
    _activeTab.find(":input").filter(":enabled[readonly!='readonly']").first().focus();
  },100);
}

hayCambios = false;

window.onbeforeunload = function() {
  var jsHay = false;
  if (typeof jsCambios == "function") jsHay = jsCambios();
  if (hayCambios || jsHay) return('Hay cambios pendientes de grabar');
};

$(window).load(function () {
  $("#dialog-nim-alert").dialog({
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "Aceptar": function() {
        $(this).dialog("close");
      }
    }
  });

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
    if (e.ctrlKey && e.which == 75) {
      e.preventDefault();
      //$("<%= @fact.class.superclass.pk.map{|k| '#' + k}.join(',')%>").attr("disabled", false);
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
      } else if (e.which == 65) { // Alt-a
        if (parent != self && $.isFunction(parent.newFicha)) {
          e.preventDefault();
          $(":focus").blur();
          mant_grabar(true);
        }
      } else if (e.which == 71) { // Alt-g
        e.preventDefault();
        var f = $(":focus");
        f.blur();
        mant_grabar();
        f.focus();
      }
    }
  });

  $(window).resize(redimWindow);

  redimWindow();
  $(".nim-div-tab").css("visibility", "visible");
  //componentHandler.upgradeDom();
  if (parent != self && $.isFunction(parent.redimWindow)) parent.redimWindow();
  $("input,select,textarea").filter(":enabled[readonly!='readonly']").first().focus();
});
