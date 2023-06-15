function redim() {
  var w = divBody.clientWidth;
  var h = divBody.clientHeight - titulo.clientHeight;
  boxMargin = Math.min(w, h) / 10 / Math.sqrt(nBox);
  boxMargin2 = boxMargin * 2;
  w -= boxMargin2;
  h -= boxMargin2;
  var lado = Math.ceil(Math.sqrt(w*h/nBox));
  do {
    bxf = Math.floor(w / --lado);
    bxc = Math.ceil(nBox / bxf);
  } while (bxc * lado > h)

  divBody.style.paddingLeft = ((divBody.clientWidth - bxf*lado) / 2) + "px";
  divBody.style.paddingTop = (titulo.clientHeight + boxMargin + (h - bxc*lado) / 2) + "px";

  sty.setProperty("--box-m", boxMargin + "px");
  sty.setProperty("--box-l", (lado - boxMargin2) + "px");
  sty.setProperty("--box-f", lado/10 + "px");
}

window.addEventListener("load", function() {
  var bx = $('.box');
  nBox = bx.length;
  if (nBox == 0) return;

  bx.on('click', function() {open(this.attributes.url.value, "_blank")});
  addEventListener('resize', redim);

  divBody = document.getElementById("div-body");
  sty = document.querySelector(':root').style;

  redim();
});