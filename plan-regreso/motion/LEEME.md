# RÓTULO ANIMADO EDITABLE — SIN RESCATE

MP4 **1920×1080 · 16:9 · 25 fps · 3,00 s · H.264 + AAC estéreo 48 kHz**.
Pico de audio −3,0 dB (sin clipeo, con margen para tu mezcla).

- `rotulo.html` — la plantilla. **Es lo único que editas.**
- `render.js` — lo convierte en MP4.
- `rotulo-hora-15.mp4` / `rotulo-hora-19.mp4` — ejemplos ya renderizados.

## Renderizar
```bash
cd plan-regreso/motion
node render.js                 # saca rotulo-hora-15.mp4
node render.js mi-rotulo.mp4   # con el nombre que quieras
```

## Tirada rápida sin abrir el HTML
```bash
TITULO="HORA 19" DATO="VIENTO 38 KM/H" PIE="La hora mala" node render.js hora19.mp4
```
Variables: `TITULO` `DATO` `PIE` `EYEBROW` `FONDO` `FONDOIMAGEN` `ACENTO` `TINTA`
`TRANSICION` `SALIDA` `DURACION` `FPS`.
Así sacas las 24 horas en un bucle de bash sin tocar un archivo.

## Lo que pediste, dónde se toca (bloque `CONFIG`, arriba del `rotulo.html`)

**El texto** → `eyebrow` · `titulo` · `dato` · `pie`. Tamaños en `cpTitulo`, `cpDato`…
(píxeles sobre lienzo de 1920×1080).

**El fondo** → `fondo` para color plano. Para vídeo o foto detrás, pon la ruta en
`fondoImagen` y regula `fondoOscuro` (0–1). `vineta` y `grano` para el acabado sucio.
Si quieres metraje en movimiento de fondo: renderiza con `fondo:"#000"` y mételo en
Premiere en modo **Trama/Screen** sobre tu plano — el negro desaparece y queda solo el texto.

**La transición de aparición** → `transicion`:
- `"slam"` (por defecto) — el título entra barrido desde abajo, con rebote de escala y
  destello de 2 fotogramas. Es el que pega con el golpe de audio.
- `"wipe"` — barrido lateral, más seco.
- `"fade"` — fundido limpio, para momentos de calma.
- `"persiana"` — por bandas.
`flash:false` quita el destello. `salida:"corte"` termina a seco en vez de fundir.
Los tiempos de cada elemento están en `t:{...}`, en segundos.

**El sonido** → `audio:{...}`. `impacto` es un sub que cae de 96 Hz a 34 Hz con cola,
sincronizado al fotograma exacto del slam (`t.titulo`). `viento` es una cama de ruido
marrón filtrada a 360 Hz. `volImpacto` y `volViento` para la mezcla; `false` para quitar
cualquiera de los dos.

## Sobre el audio
Está **sintetizado aquí**, así que es libre: no hay licencia que gestionar ni Content ID
que te reclame. Si prefieres el de librería, Epidemic deja buscar desde esta sesión pero
**no descargar** con tu cuenta. El corte que había elegido, por si lo quieres bajar tú:
**"Designed, Boom, Cinematic Hit, Low Boom"** (3,5 s, id `240e5b47-f13f-49e8-a66a-75720e0a2428`).
Lo sueltas en la pista A2 cuadrado al fotograma 8 y silencias el impacto con `impacto:false`.

## En Premiere
El MP4 va directo a la línea de tiempo. Si además lo quieres **editable dentro de Premiere**
sin volver aquí: importa el MP4, y encima pon tu propio texto en **Gráficos esenciales**
con Inter Black y numeración tabular activada — así cambias la hora sin re-renderizar.
Para fondo transparente real, dime y te lo saco en **ProRes 4444 con alfa** (.mov):
MP4 no transporta canal alfa de forma fiable.
