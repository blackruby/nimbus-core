$(window).load(function() {
// Los iconos de los tipos de ficheros están sacados de:
// https://www.flaticon.com/packs/file-types

$("body").append('\
<svg style="display: none">\
<defs>\
<g id="s-file">\
<path style="fill:#E9E9E0;" d="M36.985,0H7.963C7.155,0,6.5,0.655,6.5,1.926V55\
c0,0.345,0.655,1,1.463,1h40.074c0.808,0,1.463-0.655,1.463-1V12.978c0-0.696-0.093-0.92-0.257-1.085L37.607,0.257C37.442,0.093,37.218,0,36.985,0z"/>\
<polygon style="fill:#D9D7CA;" points="37.5,0.151 37.5,12 49.349,12   "/>\
<path style="fill:#C8BDB8;" d="M48.037,56H7.963C7.155,56,6.5,55.345,6.5,54.537V39h43v15.537C49.5,55.345,48.845,56,48.037,56z"/>\
<circle style="fill:#FFFFFF;" cx="18.5" cy="47" r="3"/>\
<circle style="fill:#FFFFFF;" cx="28.5" cy="47" r="3"/>\
<circle style="fill:#FFFFFF;" cx="38.5" cy="47" r="3"/>\
</g>\
\
<g id="s-folder">\
<path style="fill:#EFCE4A;" d="M46.324,52.5H1.565c-1.03,0-1.779-0.978-1.51-1.973l10.166-27.871\
c0.184-0.682,0.803-1.156,1.51-1.156H56.49c1.03,0,1.51,0.984,1.51,1.973L47.834,51.344C47.65,52.026,47.031,52.5,46.324,52.5z"/>\
<path style="fill:#EBBA16;" d="M50.268,12.5H25l-5-7H1.732C0.776,5.5,0,6.275,0,7.232V49.96c0.069,0.002,0.138,0.006,0.205,0.01\
l10.015-27.314c0.184-0.683,0.803-1.156,1.51-1.156H52v-7.268C52,13.275,51.224,12.5,50.268,12.5z"/>\
</g>\
\
<g id="s-pdf">\
<path style="fill:#E9E9E0;" d="M36.985,0H7.963C7.155,0,6.5,0.655,6.5,1.926V55c0,0.345,0.655,1,1.463,1h40.074\
c0.808,0,1.463-0.655,1.463-1V12.978c0-0.696-0.093-0.92-0.257-1.085L37.607,0.257C37.442,0.093,37.218,0,36.985,0z"/>\
<polygon style="fill:#D9D7CA;" points="37.5,0.151 37.5,12 49.349,12   "/>\
<path style="fill:#CC4B4C;" d="M19.514,33.324L19.514,33.324c-0.348,0-0.682-0.113-0.967-0.326\
c-1.041-0.781-1.181-1.65-1.115-2.242c0.182-1.628,2.195-3.332,5.985-5.068c1.504-3.296,2.935-7.357,3.788-10.75\
c-0.998-2.172-1.968-4.99-1.261-6.643c0.248-0.579,0.557-1.023,1.134-1.215c0.228-0.076,0.804-0.172,1.016-0.172\
c0.504,0,0.947,0.649,1.261,1.049c0.295,0.376,0.964,1.173-0.373,6.802c1.348,2.784,3.258,5.62,5.088,7.562\
c1.311-0.237,2.439-0.358,3.358-0.358c1.566,0,2.515,0.365,2.902,1.117c0.32,0.622,0.189,1.349-0.39,2.16\
c-0.557,0.779-1.325,1.191-2.22,1.191c-1.216,0-2.632-0.768-4.211-2.285c-2.837,0.593-6.15,1.651-8.828,2.822\
c-0.836,1.774-1.637,3.203-2.383,4.251C21.273,32.654,20.389,33.324,19.514,33.324z M22.176,28.198\
c-2.137,1.201-3.008,2.188-3.071,2.744c-0.01,0.092-0.037,0.334,0.431,0.692C19.685,31.587,20.555,31.19,22.176,28.198z\
M35.813,23.756c0.815,0.627,1.014,0.944,1.547,0.944c0.234,0,0.901-0.01,1.21-0.441c0.149-0.209,0.207-0.343,0.23-0.415\
c-0.123-0.065-0.286-0.197-1.175-0.197C37.12,23.648,36.485,23.67,35.813,23.756z M28.343,17.174\
c-0.715,2.474-1.659,5.145-2.674,7.564c2.09-0.811,4.362-1.519,6.496-2.02C30.815,21.15,29.466,19.192,28.343,17.174z\
M27.736,8.712c-0.098,0.033-1.33,1.757,0.096,3.216C28.781,9.813,27.779,8.698,27.736,8.712z"/>\
<path style="fill:#CC4B4C;" d="M48.037,56H7.963C7.155,56,6.5,55.345,6.5,54.537V39h43v15.537C49.5,55.345,48.845,56,48.037,56z"/>\
<path style="fill:#FFFFFF;" d="M17.385,53h-1.641V42.924h2.898c0.428,0,0.852,0.068,1.271,0.205\
c0.419,0.137,0.795,0.342,1.128,0.615c0.333,0.273,0.602,0.604,0.807,0.991s0.308,0.822,0.308,1.306\
c0,0.511-0.087,0.973-0.26,1.388c-0.173,0.415-0.415,0.764-0.725,1.046c-0.31,0.282-0.684,0.501-1.121,0.656\
s-0.921,0.232-1.449,0.232h-1.217V53z M17.385,44.168v3.992h1.504c0.2,0,0.398-0.034,0.595-0.103\
c0.196-0.068,0.376-0.18,0.54-0.335c0.164-0.155,0.296-0.371,0.396-0.649c0.1-0.278,0.15-0.622,0.15-1.032\
c0-0.164-0.023-0.354-0.068-0.567c-0.046-0.214-0.139-0.419-0.28-0.615c-0.142-0.196-0.34-0.36-0.595-0.492\
c-0.255-0.132-0.593-0.198-1.012-0.198H17.385z"/>\
<path style="fill:#FFFFFF;" d="M32.219,47.682c0,0.829-0.089,1.538-0.267,2.126s-0.403,1.08-0.677,1.477s-0.581,0.709-0.923,0.937\
s-0.672,0.398-0.991,0.513c-0.319,0.114-0.611,0.187-0.875,0.219C28.222,52.984,28.026,53,27.898,53h-3.814V42.924h3.035\
c0.848,0,1.593,0.135,2.235,0.403s1.176,0.627,1.6,1.073s0.74,0.955,0.95,1.524C32.114,46.494,32.219,47.08,32.219,47.682z\
M27.352,51.797c1.112,0,1.914-0.355,2.406-1.066s0.738-1.741,0.738-3.09c0-0.419-0.05-0.834-0.15-1.244\
c-0.101-0.41-0.294-0.781-0.581-1.114s-0.677-0.602-1.169-0.807s-1.13-0.308-1.914-0.308h-0.957v7.629H27.352z"/>\
<path style="fill:#FFFFFF;" d="M36.266,44.168v3.172h4.211v1.121h-4.211V53h-1.668V42.924H40.9v1.244H36.266z"/>\
</g>\
\
<g id="s-xls">\
<path style="fill:#E9E9E0;" d="M36.985,0H7.963C7.155,0,6.5,0.655,6.5,1.926V55c0,0.345,0.655,1,1.463,1h40.074\
c0.808,0,1.463-0.655,1.463-1V12.978c0-0.696-0.093-0.92-0.257-1.085L37.607,0.257C37.442,0.093,37.218,0,36.985,0z"/>\
<polygon style="fill:#D9D7CA;" points="37.5,0.151 37.5,12 49.349,12   "/>\
<path style="fill:#91CDA0;" d="M48.037,56H7.963C7.155,56,6.5,55.345,6.5,54.537V39h43v15.537C49.5,55.345,48.845,56,48.037,56z"/>\
<path style="fill:#FFFFFF;" d="M20.379,48.105L22.936,53h-1.9l-1.6-3.801h-0.137L17.576,53h-1.9l2.557-4.895l-2.721-5.182h1.873\
l1.777,4.102h0.137l1.928-4.102H23.1L20.379,48.105z"/>\
<path style="fill:#FFFFFF;" d="M27.037,42.924v8.832h4.635V53h-6.303V42.924H27.037z"/>\
<path style="fill:#FFFFFF;" d="M39.041,50.238c0,0.364-0.075,0.718-0.226,1.06S38.453,51.94,38.18,52.2s-0.611,0.467-1.012,0.622\
c-0.401,0.155-0.857,0.232-1.367,0.232c-0.219,0-0.444-0.012-0.677-0.034s-0.467-0.062-0.704-0.116\
c-0.237-0.055-0.463-0.13-0.677-0.226c-0.214-0.096-0.399-0.212-0.554-0.349l0.287-1.176c0.127,0.073,0.289,0.144,0.485,0.212\
c0.196,0.068,0.398,0.132,0.608,0.191c0.209,0.06,0.419,0.107,0.629,0.144c0.209,0.036,0.405,0.055,0.588,0.055\
c0.556,0,0.982-0.13,1.278-0.39c0.296-0.26,0.444-0.645,0.444-1.155c0-0.31-0.105-0.574-0.314-0.793\
c-0.21-0.219-0.472-0.417-0.786-0.595s-0.654-0.355-1.019-0.533c-0.365-0.178-0.707-0.388-1.025-0.629\
c-0.319-0.241-0.583-0.526-0.793-0.854c-0.21-0.328-0.314-0.738-0.314-1.23c0-0.446,0.082-0.843,0.246-1.189\
s0.385-0.641,0.663-0.882c0.278-0.241,0.602-0.426,0.971-0.554s0.759-0.191,1.169-0.191c0.419,0,0.843,0.039,1.271,0.116\
c0.428,0.077,0.774,0.203,1.039,0.376c-0.055,0.118-0.119,0.248-0.191,0.39c-0.073,0.142-0.142,0.273-0.205,0.396\
c-0.064,0.123-0.119,0.226-0.164,0.308c-0.046,0.082-0.073,0.128-0.082,0.137c-0.055-0.027-0.116-0.063-0.185-0.109\
s-0.167-0.091-0.294-0.137c-0.128-0.046-0.296-0.077-0.506-0.096c-0.21-0.019-0.479-0.014-0.807,0.014\
c-0.183,0.019-0.355,0.07-0.52,0.157s-0.31,0.193-0.438,0.321c-0.128,0.128-0.228,0.271-0.301,0.431\
c-0.073,0.159-0.109,0.313-0.109,0.458c0,0.364,0.104,0.658,0.314,0.882c0.209,0.224,0.469,0.419,0.779,0.588\
c0.31,0.169,0.647,0.333,1.012,0.492c0.364,0.159,0.704,0.354,1.019,0.581s0.576,0.513,0.786,0.854\
C38.936,49.261,39.041,49.7,39.041,50.238z"/>\
<path style="fill:#C8BDB8;" d="M23.5,16v-4h-12v4v2v2v2v2v2v2v2v4h10h2h21v-4v-2v-2v-2v-2v-2v-4H23.5z M13.5,14h8v2h-8V14z\
M13.5,18h8v2h-8V18z M13.5,22h8v2h-8V22z M13.5,26h8v2h-8V26z M21.5,32h-8v-2h8V32z M42.5,32h-19v-2h19V32z M42.5,28h-19v-2h19V28\
z M42.5,24h-19v-2h19V24z M23.5,20v-2h19v2H23.5z"/>\
</g>\
\
<g id="s-pic">\
<rect x="1" y="7" style="fill:#C3E1ED;stroke:#E7ECED;stroke-width:2;stroke-miterlimit:10;" width="56" height="44"/>\
<circle style="fill:#ED8A19;" cx="16" cy="17.569" r="6.569"/>\
<polygon style="fill:#1A9172;" points="56,36.111 55,35 43,24 32.5,35.5 37.983,40.983 42,45 56,45 "/>\
<polygon style="fill:#1A9172;" points="2,49 26,49 21.983,44.983 11.017,34.017 2,41.956 "/>\
<rect x="2" y="45" style="fill:#6B5B4B;" width="54" height="5"/>\
<polygon style="fill:#25AE88;" points="37.983,40.983 27.017,30.017 10,45 42,45 "/>\
</g>\
\
</defs>\
</svg>\
');

  nimFolders = [];
  nimPdfs = [];
  for (var f in nimFiles) {
    htm = '<div class="c-file">';
    htm += '<svg width="50" height="60">';
    htm += '<use xlink:href="#s-' + nimFiles[f].type + '"/>';
    htm += '</svg>';
    htm += '<label class="l-file">' + f + '</label>';
    htm += '</div>';
    $("#d-files").append(htm);

    if (nimFiles[f].type == 'folder') nimFolders.push(f);
    if (nimFiles[f].type == 'pdf') nimPdfs.push(f);
  }

  $(".c-file").click(function(e) {
    f = $(this).find("label");
    if (e.ctrlKey)
      if (f.hasClass('nim-bgcolor-1'))
        f.removeClass('nim-bgcolor-1').css("color", "black");
      else
        f.addClass('nim-bgcolor-1').css("color", "white");
    else {
      $(".c-file label").removeClass('nim-bgcolor-1').css("color", "black");
      f.addClass('nim-bgcolor-1').css("color", "white");
    }
  }).dblclick(function(e) {
    nimFileSel = $(this).find("label");
    if (nimFiles[nimFileSel.text()].type == 'folder') ospAbrir();
  }).contextmenu(function(e) {
    e.preventDefault();

    nimFileSel = $(this).find("label");
    if (!nimFileSel.hasClass('nim-bgcolor-1') && !e.ctrlKey) $(".c-file label").removeClass('nim-bgcolor-1').css("color", "black");
    nimFileSel.addClass('nim-bgcolor-1').css("color", "white");

    // Rellenar el array de elementos (ficheros) seleccionados
    nimFilesSel = [];
    $(".c-file .nim-bgcolor-1").each(function() {nimFilesSel.push($(this).text());});

    // Rellenar el array de carpetas disponibles para poder mover dentro de ellas la selección
    nimFoldersFree = [];
    if ($("#l-dir").text() != '') nimFoldersFree.push("..(Nivel anterior)")
    for (var f in nimFolders) if ($.inArray(nimFolders[f], nimFilesSel) == -1) nimFoldersFree.push(nimFolders[f]);
    $("#li-mov").css("display", (nimFoldersFree.length > 0 ? "block" : "none"));

    // Rellenar el array de pdfs disponibles para poder añadirles la selección
    if (nimFilesSel.length == 1 && nimFiles[nimFilesSel[0]].type == 'pdf') {
      nimPdfsFree = [];
      for (var f in nimPdfs) if ($.inArray(nimPdfs[f], nimFilesSel) == -1) nimPdfsFree.push(nimPdfs[f]);
      $("#li-add").css("display", (nimPdfsFree.length > 0 ? "block" : "none"));
    } else
      $("#li-add").css("display", "none");

    $("#li-abr").css("display", (nimFiles[nimFileSel.text()].type == 'folder' ? "block" : "none"));
    $("#li-ren").css("display", (nimFilesSel.length == 1 ? "block" : "none"));

    $("#menu").css("display", "block").position({my: "top", at: "bottom", of: nimFileSel});
  });

  $("#li-mov").click(function(e) {
    e.stopPropagation();
    var htm = '';
    for (var f in nimFoldersFree) {
      htm += '<li class="nim-context-menu-li" onClick="ospMover($(this).text())">' + nimFoldersFree[f] + '</li>';
    }
    $("#menu2-ul").html(htm);
    $("#menu2").css("display", "block").position({my: "left top", at: "right+3 top", of: this});
  });

  $("#li-add").click(function(e) {
    e.stopPropagation();
    var htm = '';
    for (var f in nimPdfsFree) {
      htm += '<li class="nim-context-menu-li" onClick="ospAdd($(this).text())">' + nimPdfsFree[f] + '</li>';
    }
    $("#menu2-ul").html(htm);
    $("#menu2").css("display", "block").position({my: "left top", at: "right+3 top", of: this});
  });

  $("#inp-nombre").on("input", function() {
    var c;
    var v = $(this).val();
    var cur = $(this).caret().begin;

    var vb = "";
    for (var i = 0; c = v[i]; i++) if (c == '/' || i == 0 && c == '.') cur--; else vb += c;

    $(this).css("color", vb in nimFiles ? "red" : "black");
    $(this).val(vb);
    $(this).caret(cur);

    $("#b-nombre").button(vb == '' || vb in nimFiles ? "disable" : "enable")
  }).on("keydown", function(e) {
    if (e.keyCode == 13 && $("#b-nombre").attr("disabled") != "disabled") ospNewRename();
  });

  $("#d-borrar").dialog({
    autoOpen: false,
    resizable: false,
    modal: true,
    width: 'auto',
    buttons: {
      "Sí": function() {
        $(this).dialog("close");
        callFonServer('osp_borrar', {files: nimFilesSel});
      },
      No: function() {
        $(this).dialog("close");
      }
    }
  });

  $("#d-nombre").dialog({
    autoOpen: false,
    resizable: false,
    modal: true,
    width: 'auto',
    buttons: [{
      id: 'b-nombre',
      text: "Aceptar",
      click: ospNewRename
    }]
  });
});

function ospAbrir() {
  callFonServer('osp_abrir', {fol: nimFileSel.text()});
}

function ospAbrirBack() {
  callFonServer('osp_abrir', {fol: '..'});
}

function ospMover(f) {
  callFonServer('osp_mover', {org: nimFilesSel, dest: f})
}

function ospAdd(f) {
  callFonServer('osp_add', {org: nimFilesSel[0], dest: f})
}

function ospBorrar() {
  $("#d-borrar").dialog('open');
}

function ospNewRename() {
  if (ospNombreOp == 'new')
    callFonServer('osp_new', {fol: $("#inp-nombre").val()});
  else
    callFonServer('osp_rename', {org: nimFileSel.text(), dest: $("#inp-nombre").val()});
}

function ospCrearFolder() {
  ospNombreOp = 'new';
  $("#b-nombre").button("disable");
  $("#inp-nombre").val('');
  $("#d-nombre").dialog('open');
}

function ospRename() {
  ospNombreOp = 'mv';
  $("#b-nombre").button("disable");
  $("#inp-nombre").val(nimFileSel.text());
  $("#d-nombre").dialog('open');
}

function ospDescargar() {
  callFonServer('osp_descargar', {files: nimFilesSel})
}