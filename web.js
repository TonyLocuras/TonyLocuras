// Funcionamiento compartido por la página de redes (index.html) y la tienda (tienda.html).
// No hace falta tocarlo: todo el contenido se cambia desde el panel (admin.html).
function TL_start() {
const PAGE = document.body.dataset.page; // "redes" o "tienda"
const app = document.getElementById("app");

if (typeof DATOS === "undefined") {
  app.innerHTML = '<div class="err"><b>La web no carga los datos.</b><br>Seguramente falta o sobra una coma, comilla o corchete en <b>datos.js</b>. Revisa el último cambio que hiciste.</div>';
  return;
}
const D = DATOS;

// ---------- utilidades ----------
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const eur = n => n.toLocaleString("es-ES", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €";
const r2 = n => Math.round(n * 100) / 100;
const visible = x => x && x.activa !== false;
const finDia = f => new Date(f + "T23:59:59");
const hoy = new Date();
const ext = 'target="_blank" rel="noopener"';

// Añade el código al enlace (?coupon=...) para que Vitastrong lo aplique solo.
function conCupon(url, codigo) {
  try {
    const u = new URL(url);
    if (codigo && ![...u.searchParams.keys()].some(k => k.toLowerCase() === "coupon")) u.searchParams.set("coupon", codigo);
    return u.toString();
  } catch { return url; }
}

const ICON = {
  yt: '<svg viewBox="0 0 24 24"><path fill="#fff" d="M21.6 7.2a2.5 2.5 0 0 0-1.8-1.8C18.2 5 12 5 12 5s-6.2 0-7.8.4A2.5 2.5 0 0 0 2.4 7.2 26 26 0 0 0 2 12a26 26 0 0 0 .4 4.8 2.5 2.5 0 0 0 1.8 1.8C5.8 19 12 19 12 19s6.2 0 7.8-.4a2.5 2.5 0 0 0 1.8-1.8A26 26 0 0 0 22 12a26 26 0 0 0-.4-4.8z"/><path fill="#c2321d" d="M10 15V9l5.2 3z"/></svg>',
  ig: '<svg viewBox="0 0 24 24"><path d="M12 7.3A4.7 4.7 0 1 0 12 16.7 4.7 4.7 0 0 0 12 7.3zm0 7.7a3 3 0 1 1 0-6 3 3 0 0 1 0 6zM17 5.8a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2zM7.8 2h8.4A5.8 5.8 0 0 1 22 7.8v8.4a5.8 5.8 0 0 1-5.8 5.8H7.8A5.8 5.8 0 0 1 2 16.2V7.8A5.8 5.8 0 0 1 7.8 2zm0 1.8a4 4 0 0 0-4 4v8.4a4 4 0 0 0 4 4h8.4a4 4 0 0 0 4-4V7.8a4 4 0 0 0-4-4z"/></svg>',
  tt: '<svg viewBox="0 0 24 24"><path d="M16.6 5.8A4.3 4.3 0 0 1 15.5 3h-3.1v12.4a2.6 2.6 0 1 1-1.8-2.5V9.7a5.7 5.7 0 1 0 4.9 5.7V9.1a7.3 7.3 0 0 0 4.3 1.4V7.4a4.3 4.3 0 0 1-3.2-1.6z"/></svg>',
  star: '<svg viewBox="0 0 24 24"><path d="M12 2.5l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.4l-5.9 3.1 1.2-6.5L2.5 9.4l6.6-.9z"/></svg>'
};

const yt = D.youtube || {}, ig = D.instagram || {}, tt = D.tiktok || {}, mb = D.miembros || {}, vs = D.vitastrong || {};
const TI = Object.assign({
  titulo: "Mis carritos Vitastrong",
  boton: "Ver mis carritos"
}, D.tienda || {});
const pct = Number(vs.descuento) || 0;

// ---------- promociones activas y en fecha ----------
const promos = (D.promociones || []).filter(p => visible(p) && (!p.hasta || finDia(p.hasta) >= hoy));
const extraPct = Math.max(0, ...promos.map(p => Number(p.extraEnPacks) || 0));
const extraNombre = (promos.find(p => Number(p.extraEnPacks) === extraPct) || {}).etiqueta || "la promo";
function cuentaAtras(f) {
  if (!f) return "";
  const dias = Math.ceil((finDia(f) - hoy) / 86400000);
  return dias <= 1 ? "Último día" : "Quedan " + dias + " días";
}

let h = '<div class="inapp" id="inapp" hidden></div>';

// =====================================================================
//  PÁGINA DE REDES
// =====================================================================
if (PAGE === "redes") {
  h += `<h1>${esc(D.nombre)}</h1><p class="lead">${esc(D.descripcion)}</p>`;

  h += `
    <a class="yt" data-app="yt" href="https://www.youtube.com/@${esc(yt.usuario)}?sub_confirmation=1" ${ext}>
      <div class="row"><div class="icon">${ICON.yt}</div><div><h2>YouTube</h2><p>${esc(yt.texto)}</p></div></div>
      <span class="btn">${esc(yt.boton || "Suscribirme")}</span>
    </a>`;

  const redes = [];
  if (visible(ig)) redes.push(`<a class="social" data-app="ig" href="https://www.instagram.com/${esc(ig.usuario)}/" ${ext}><div class="icon">${ICON.ig}</div><div><b>Instagram</b><small>${esc(ig.texto)}</small><span class="follow">Seguir</span></div></a>`);
  if (visible(tt)) redes.push(`<a class="social" data-app="tt" href="https://www.tiktok.com/@${esc(tt.usuario)}" ${ext}><div class="icon">${ICON.tt}</div><div><b>TikTok</b><small>${esc(tt.texto)}</small><span class="follow">Seguir</span></div></a>`);
  if (redes.length) h += `<div class="socials${redes.length === 1 ? " one" : ""}">${redes.join("")}</div>`;

  // Tarjeta que lleva a la tienda (enseña la promo activa si la hay)
  const promoTop = promos[0];
  h += `
    <a class="shopcard" href="tienda.html">
      ${promoTop ? `<span class="hot">🔥 ${esc(promoTop.etiqueta || "PROMO")} ACTIVO</span>` : ""}
      <h2>${esc(TI.titulo)}</h2>
      <p>${pct} % de descuento con mi código <b>${esc(vs.codigo)}</b>${promoTop && promoTop.titulo ? ` · ${esc(promoTop.titulo)}` : ""}</p>
      <span class="go">${esc(TI.boton)} →</span>
    </a>`;

  if (visible(mb)) h += `
    <section class="member">
      <div class="head"><div class="icon">${ICON.star}</div><h2>${esc(mb.titulo)}</h2></div>
      <p>${esc(mb.texto)}</p>
      <a class="btn block" data-app="ytjoin" href="https://www.youtube.com/channel/${esc(yt.idCanal)}/join" ${ext}>${esc(mb.boton)}</a>
    </section>`;
}

// =====================================================================
//  PÁGINA DE TIENDA
// =====================================================================
if (PAGE === "tienda") {
  document.title = TI.titulo + " · " + (D.nombre || "");
  h += `<header class="shophead"><span class="by">${esc(D.nombre)} × Vitastrong</span><h1>${esc(TI.titulo)}</h1></header>`;

  h += promos.map(p => `
    <section class="promo">
      <div class="top">${p.etiqueta ? `<span class="tag">${esc(p.etiqueta)}</span>` : "<span></span>"}<span class="left">${cuentaAtras(p.hasta)}</span></div>
      ${p.titulo ? `<h2>${esc(p.titulo)}</h2>` : ""}
      ${p.texto ? `<p>${esc(p.texto)}</p>` : ""}
      ${p.boton && p.enlace ? `<a class="go" href="${esc(p.enlace)}" ${ext}>${esc(p.boton)}</a>` : ""}
    </section>`).join("");

  h += `
    <section class="vita">
      <h2>${pct} % en Vitastrong</h2>
      <p>${esc(vs.texto).replace("{codigo}", "<b>" + esc(vs.codigo) + "</b>")}</p>
      <a class="go" href="${esc(conCupon(vs.enlace, vs.codigo))}" ${ext}>${esc(vs.boton)}</a>
      <button class="code" id="code" type="button"><b>${esc(vs.codigo)}</b><small>Toca para copiar el código</small></button>
    </section>`;

  const tabs = (D.pestanas || []).filter(visible);
  const packHTML = p => {
    const conCodigo = typeof p.precioFinal === "number" ? p.precioFinal : r2(p.precio * (1 - pct / 100));
    return `
      <a class="pack" href="${esc(p.enlace)}" ${ext}>
        <h4>${esc(p.nombre)}</h4>
        ${p.incluye ? `<p class="inc">Incluye: ${esc(p.incluye)}</p>` : ""}
        <div class="price"><s>${eur(p.precio)}</s><b>${eur(conCodigo)}</b><small>${pct} % de descuento con mi código</small></div>
        ${extraPct > 0 ? `<span class="extra">Con ${esc(extraNombre)} (−${extraPct} % extra): <b>${eur(r2(conCodigo * (1 - extraPct / 100)))}</b></span>` : ""}
        <span class="cta">Ver este carrito →</span>
      </a>`;
  };
  if (tabs.length) {
    h += `<section class="carts"><h2>${esc(D.carritosTitulo)}</h2><p>${esc(D.carritosTexto)}</p>`;
    if (tabs.length > 1) h += `<div class="tabs" role="tablist">${tabs.map((t, i) => `<button class="tab" role="tab" aria-selected="${i === 0}" data-tab="${i}">${esc(t.nombre)}</button>`).join("")}</div>`;
    h += tabs.map((t, i) => `<div class="panel" data-panel="${i}"${i ? " hidden" : ""}>${
      (t.grupos || []).filter(visible).map((g, j) => {
        const packs = (g.packs || []).filter(p => visible(p) && p.nombre && Number(p.precio) > 0 && p.enlace);
        if (!packs.length) return "";
        return `<details class="group"${j === 0 ? " open" : ""}><summary><h3 class="cond">${esc(g.titulo)}</h3><span class="n">${packs.length}</span><span class="pm"></span></summary>${packs.map(packHTML).join("")}</details>`;
      }).join("")}</div>`).join("");
    h += `</section>`;
  }
  if (D.notaFinal) h += `<p class="note">${esc(D.notaFinal)}</p>`;
  h += `<a class="back" href="./">← Mis redes y canal de YouTube</a>`;
}

app.innerHTML = h;

// ---------- pestañas ----------
app.querySelectorAll(".tab").forEach(t => t.addEventListener("click", () => {
  app.querySelectorAll(".tab").forEach(o => o.setAttribute("aria-selected", o === t));
  app.querySelectorAll(".panel").forEach(p => p.hidden = p.dataset.panel !== t.dataset.tab);
}));

// ---------- copiar código ----------
const codeBtn = document.getElementById("code"), toast = document.getElementById("toast");
if (codeBtn) codeBtn.addEventListener("click", async () => {
  try { await navigator.clipboard.writeText(vs.codigo); }
  catch {
    const ta = document.createElement("textarea"); ta.value = vs.codigo;
    document.body.appendChild(ta); ta.select(); document.execCommand("copy"); ta.remove();
  }
  codeBtn.classList.add("ok"); codeBtn.querySelector("small").textContent = "¡Copiado!";
  toast.classList.add("show");
  setTimeout(() => { toast.classList.remove("show"); codeBtn.classList.remove("ok"); codeBtn.querySelector("small").textContent = "Toca para copiar el código"; }, 1800);
});

// ---------- abrir directamente la app (YouTube, Instagram, TikTok) en el móvil ----------
const UA = navigator.userAgent;
const isAndroid = /Android/i.test(UA);
const isIOS = /iPhone|iPad|iPod/i.test(UA) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
const inApp = /Instagram|FBAN|FBAV|musical_ly|BytedanceWebview|TikTok|Twitter|Snapchat/i.test(UA);
const APPS = {
  yt:     { android: "com.google.android.youtube", ios: "youtube://www.youtube.com/@" + yt.usuario + "?sub_confirmation=1" },
  ytjoin: { android: "com.google.android.youtube", ios: "youtube://www.youtube.com/channel/" + yt.idCanal + "/join" },
  ig:     { android: "com.instagram.android",      ios: "instagram://user?username=" + ig.usuario },
  tt:     { android: "com.zhiliaoapp.musically",   ios: null }
};
window.TL_go = window.TL_go || (u => { location.href = u; });

app.querySelectorAll("a[data-app]").forEach(a => a.addEventListener("click", e => {
  if (!isAndroid && !isIOS) return;
  const info = APPS[a.dataset.app], web = a.href;
  e.preventDefault();
  if (isAndroid) {
    TL_go("intent://" + web.replace(/^https?:\/\//, "") + "#Intent;scheme=https;package=" + info.android +
          ";S.browser_fallback_url=" + encodeURIComponent(web) + ";end");
  } else if (inApp && info.ios) {
    TL_go(info.ios);
    setTimeout(() => { if (!document.hidden) TL_go(web); }, 1500);
  } else {
    TL_go(web);
  }
}));

// Aviso solo en la página de redes, que es donde hace falta saltar a otras apps
if (PAGE === "redes" && inApp && (isAndroid || isIOS) && location.protocol === "https:") {
  const box = document.getElementById("inapp");
  box.innerHTML = isAndroid
    ? '<p>Ábrelo en Chrome para seguirme con un toque.</p><a href="intent://' + location.host + location.pathname + '#Intent;scheme=https;package=com.android.chrome;end">Abrir</a><button class="x" aria-label="Cerrar">×</button>'
    : '<p>Para seguirme con un toque: pulsa <b>···</b> arriba y elige <b>Abrir en el navegador</b>.</p><button class="x" aria-label="Cerrar">×</button>';
  box.hidden = false;
  box.querySelector(".x").onclick = () => box.hidden = true;
}
}

// Carga datos.js siempre fresco (sin versiones viejas guardadas en el móvil)
(function () {
  var s = document.createElement("script");
  s.src = "datos.js?v=" + Date.now();
  s.onload = s.onerror = TL_start;
  document.head.appendChild(s);
})();
