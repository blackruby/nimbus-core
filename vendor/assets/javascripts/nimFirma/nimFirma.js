//= require nimFirma/signature_pad

function nimFirma(th) {
  $("<div><canvas></canvas></div>").dialog({
    title: "Introduzca firma",
    resizable: false,
    modal: true,
    width: "auto",
    hight: "auto",
    create: function() {
      creaBotonesDialogo([
        {label: "Hecho", icon: "done", accion: `js:nimFirmaUpload("${th.id}")`},
        {label: "Borrar", icon: "delete", accion: 'js:nimFirmaObj.clear()', close: false},
      ], $(this));
      cv = $(this).find("canvas")[0];
      nimFirmaObj = new SignaturePad(cv);
      cv.width = 330;
      cv.height = 170;
    },
    close: function() {
      delete nimFirmaObj;
      $(this).remove();
    }
  });
}

function nimFirmaUpload(cmp) {
  zombi = $("#" + cmp);
  send_validar($("#" + cmp), nimFirmaObj.toData().length == 0 ? "*" : nimFirmaObj.toDataURL());
}