//= require quill/quill

function nimQuill(cmp) {
  var cont = $("#" + cmp);

  var htm = "";
  htm += `<i class="material-icons nq-toolbar-left" onclick="nimQlToolBarMove('${cmp}', -28)">arrow_back_ios</i>`;
  htm += `<i class="material-icons nq-toolbar-right" onclick="nimQlToolBarMove('${cmp}', 28)">arrow_forward_ios</i>`;
  htm += '<div class="nq-toolbar">';
  htm += ' <select class="ql-font" title="Fuente"></select>';
  htm += ' <select class="ql-size" title="Tamaño (Ctrl-I)"></select>';
  htm += ' <button class="ql-bold" title="Negrita (Ctrl-B)"></button>';
  htm += ' <button class="ql-italic" title="Cursiva (Ctrl-I)"></button>';
  htm += ' <button class="ql-underline" title="Subrayado (Ctrl-U)"></button>';
  htm += ' <button class="ql-strike" title="Tachado"></button>';
  htm += ' <select class="ql-align" title="Alineación"></select>';
  htm += ' <select class="ql-color" title="Color del texto"></select>';
  htm += ' <select class="ql-background" title="Color del fondo"></select>';
  htm += ' <button class="ql-link" title="Hiperenlace (Ctrl-K)"></button>';
  htm += ' <button class="ql-list" value="ordered" title="Lista numerada"></button>';
  htm += ' <button class="ql-list" value="bullet" title="Lista con viñetas"></button>';
  htm += ' <button class="ql-indent" value="-1" title="Reducir sangría"></button>';
  htm += ' <button class="ql-indent" value="+1" title="Aumentar sangría"></button>';
  htm += '</div>';
  htm += '<div class="nq-editor"></div>';

  cont.addClass("nq-contenedor").html(htm);

  var tb = $("#" + cmp + " .nq-toolbar");
  // Guardamos en una variable global de nombre "nq_<cmp>" el descriptor devuelto por el constructor Quill.
  // A través de dicho descriptor se podrá, donde sea necesario, acceder a las distintas funciones que
  // ofrece la clase Quill (focus, enable, getContents, setContents, ...)
  var nq = "nq_" + cmp;
  window[nq] = new Quill("#" + cmp + " .nq-editor", {
    modules: {
      toolbar: "#" + cmp + " .nq-toolbar"
    },
    // placeholder: 'Introduzca su texto...',
    theme: 'snow'
  });
  // La propiedad "display" por alguna razón no la coge bien desde el CSS y por lo tanto se la asignamos aquí.
  tb.css("display", "-webkit-box").scroll(function(){nimQlToolbarScroll(this)});
  $(window).resize(function(){nimQlToolbarScroll(tb[0]);});

  // Sacar de la rueda de focos a los elementos de la toolbar
  tb.find("button,.ql-picker-label").attr("tabindex", -1)

  nimQlToolbarScroll(tb[0]);

  return window[nq];
}

function nimQuillVal(cmp) {
  // Reasigno el contenido para quitar elementos espurios que puedan quedar
  var w = window["nq_" + cmp];
  w.setContents(w.getContents());

  var val = $("#" + cmp + " .ql-editor").html();
  return val == "<p><br></p>" ? "" : val;  
}

function nimQlToolbarScroll(t) {
  $(t).parent().find(".nq-toolbar-left").css("display", t.scrollLeft > 0 ? "block" : "none");
  $(t).parent().find(".nq-toolbar-right").css("display", t.scrollLeft + t.clientWidth < t.scrollWidth ? "block" : "none");
}

function nimQlToolBarMove(cmp, x) {
  var tb = $("#" + cmp + " .nq-toolbar");
  tb[0].scrollLeft = tb[0].scrollLeft + x;
}