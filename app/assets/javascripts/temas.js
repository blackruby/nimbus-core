var stopChanges = false;

function RGB2Array(c) {
  return [
    parseInt(c.substr(1, 2), 16),
    parseInt(c.substr(3, 2), 16),
    parseInt(c.substr(5, 2), 16)
  ]
}

function HSL2RGB(h, s, l) {
  s /= 100;
  l /= 100;
  const k = n => (n + h / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = n =>
    l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  var r = Math.round(255 * f(0));
  var g = Math.round(255 * f(8));
  var b = Math.round(255 * f(4));
  zzz = [r,g,b];
  return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
}

function RGB2HSL(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  const l = Math.max(r, g, b);
  const s = l - Math.min(r, g, b);
  const h = s
    ? l === r
      ? (g - b) / s
      : l === g
      ? 2 + (b - r) / s
      : 4 + (r - g) / s
    : 0;
  return [
    60 * h < 0 ? 60 * h + 360 : 60 * h,
    100 * (s ? (l <= 0.5 ? s / (2 * l - s) : s / (2 - (2 * l - s))) : 0),
    (100 * (2 * l - s)) / 2,
  ];
}

function fgBlackOrWhite(c) {
  var ca = RGB2Array(c);
  return (ca[0] + ca[1] + ca[2]) / 3 > 128 ? "#000000" : "#ffffff";
}

function fColor(th) {
  document.getElementById(th.id + '_f').value = fgBlackOrWhite(th.value);
}

var setDefault = false;
function jsGrabar() {
  var h = {css: setHashCSS()};
  if (setDefault) h.default = true;
  return h;
}

function chMainColor(th) {
  stopChanges = true;

  fColor(th);

  var n = th.id[8];
  var rgb = RGB2Array(th.value);
  var hsl = RGB2HSL(rgb[0], rgb[1], rgb[2]);
  var f = fgBlackOrWhite(th.value) == "#000000" ? -hsl[2] / 3 : (100 - hsl[2]) / 3;
  var c2 = HSL2RGB(hsl[0], hsl[1], hsl[2] + f);
  var c3 = HSL2RGB(hsl[0], hsl[1], hsl[2] + 2*f);
  $(`#--color-${n}-2`).val(c2).change();
  $(`#--color-${n}-3`).val(c3).change();
  if (n == 1) {
    $("#--jqg-head-column-color").val(c2).change();
    $("#--jqg-head-color").val(c3).change();
  }

  stopChanges = false;
}

function setHashCSS() {
  var v = {};
  for(var i of $("#parametros input")) v[i.id] = i.value + (i.attributes.sufijo ? i.attributes.sufijo.value : "");
  return v;
}

$(window).load(function() {
  // Inicializar los inputs con los valores que se almacenan en la variable cssVars del padre
  if (_factId != 0) {
    var v = parent.cssVars;
    var keys = Object.keys(v);
    for (var k of keys) $("#" + k).val(v[k].replace("px", "").replace("%", ""));
    setCSSVariables2(v);
  }

  // Construir los botones de swap blanco/negro (Celdas que tienen <i>)
  // y añadir celda de "Muestra"
  for (var el of $("td i")) {
    var c = $(el).prev().attr("id");
    $(el).
    addClass("material-icons").
    attr("title", "Intercambia blanco/negro").
    text("compare_arrows").
    click(function() {
      var inp = $(this).prev();
      inp.val(inp.val() == "#000000" ? "#ffffff" : "#000000").change();
    }).
    parent().after(`<td style="color: var(${c});background-color: var(${c.slice(0, -2)});">Muestra</td>`);
  }

  // Aplicar tema resultante si cambia algún parámetro
  $("#parametros").on("change", "input", function() {
    if (stopChanges) return;

    var v = setHashCSS();
    setCSSVariables2(v);
  })

  // Llamar al servidor para almacenar el tema como predeterminado
  $("#default").click(function() {
    setDefault = true;
    mant_grabar();
    setDefault = false;
    nimPopup("Se ha establecido el tema como predeterminado");
  });
});

// Almacenar los parámetros en el padre.
// Así en una nueva alta se usarán los últimos editados.
$(window).unload(function() {
  parent.cssVars = setHashCSS();
});