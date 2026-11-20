# App TODO OK — Diseño (fase 1 MVP + fases posteriores)

Fuente: "App Todo OK – planteamiento para Claude Code" (PDF de Tony) + brainstorming y stress-test del 2026-11-20.
Versión revisada tras stress-test (ver al final).

## Objetivo
App Flutter para expediciones de TonyLocuras. Tony confirma con un botón; si no lo hace antes de la hora límite, el contacto recibe una alarma aunque Tony no tenga cobertura. Sin dispositivos externos ni suscripciones.

## Decisiones tomadas
| Tema | Decisión |
|---|---|
| Ubicación del código | **Repo privado separado** (a crear por Tony y añadir a la sesión). No va en este repo público |
| Stack | Flutter (Android + iOS), Firebase plan gratuito: Auth (Google), Firestore, FCM. **Sin Blaze ni Cloud Functions en fase 1** |
| Alarma | **Solo local** en el móvil del contacto (fase 1). Capa servidor = fase 3 opcional |
| Contacto Android | Alarma a pantalla completa con sonido, ignora silencio |
| Contacto iPhone | Notificación local degradada, puede silenciarse. Instalarla requiere Apple Developer (99 $/año) y un Mac: fuera de la gratuidad, a cargo de Tony |
| Entrega | MVP primero; GPS/mapas/GPX en fase 2 |
| Entorno de Tony | Nada preparado: se entrega guía de montaje de Firebase y Flutter |

## Principio de seguridad
La alarma depende de la **hora límite**, no de que Tony envíe nada. Si Tony falla (batería, sin cobertura, incapacitado), la alarma suena igual.

## Semántica de las confirmaciones
- Solo existe el **check-in** (botón TODO OK). Registra hora, última coordenada y batería.
- Con intervalo configurado, un check-in reprograma el límite a `max(límite_actual, ahora_efectivo + intervalo)`. Sin intervalo, no mueve el límite.
- **TODO OK nunca desarma la alarma.** Solo **Finalizar** (vuelta a casa) la cancela.
- Estados de expedición: `active | alarm | finished`. "OK" en la pantalla del contacto se deriva del último check-in reciente, no es un estado.
- Ampliar el límite a mano cuenta como un check-in. Olvidar pulsar Finalizar produce una falsa alarma aceptada; la app de Tony recuerda finalizar al detectar que está de vuelta.

## Falsa alarma vs alarma perdida
- Sesgo explícito: **ante la duda, suena**.
- Un check-in que llega tarde se aplica con su hora efectiva. Si la alarma ya sonó, **no se apaga sola**: la pantalla pasa a aviso naranja "Tony hizo check-in a las HH:MM (llegó con retraso)" y el contacto la cierra a mano.
- La pantalla de alarma muestra siempre hora del último check-in y cuánto hace.

## Reloj
- Instantes en UTC; formato local solo al mostrar.
- Hora efectiva del check-in = `min(hora_cliente, hora_servidor_de_recepción)`; se rechaza una hora de cliente futura.
- Aviso si Tony tiene desactivada la hora automática.

## Armado de la alarma (contacto)
- Al programar la alarma, el contacto escribe `armedAt` y la versión del límite en `expeditions/{id}/contacts/{uid}`. Tony lo ve antes de salir: "Contacto A armado ✓ / Contacto B sin confirmar ✗".
- **No se puede iniciar** la expedición sin al menos un contacto armado con el límite vigente, salvo confirmación explícita ("salgo sin alarma activa").
- Mínimo dos contactos recomendado (aviso, no bloqueo). Cada contacto arma su propia alarma: redundancia.
- Acuse obligatorio: el contacto pulsa "Recibida" (`ackAt`). Sin acuse en 5 min, la propia app vuelve a sonar hasta el acuse. El escalado entre contactos queda diferido a la fase 3 (requiere servidor).
- Las alarmas pendientes se guardan en local y se reprograman con un receptor `BOOT_COMPLETED` tras reiniciar.
- Si el contacto fuerza el cierre, Android cancela las alarmas: la verificación de armado lo detecta en el siguiente arranque.

## Android: que suene de verdad
- Programar con `setAlarmClock`; mostrar con notificación de pantalla completa en canal de alarma, con vibración y volumen forzado.
- Pantalla de **permisos guiados** (alarmas exactas, pantalla completa Android 14+, exención de batería, notificaciones) con estado verde/rojo. Si falta alguno, no se marca como armado.
- Botón **"Probar alarma"**: suena en 60 s con pantalla bloqueada y app cerrada.
- Enlace a instrucciones por fabricante (autoarranque, ahorro de batería).
- Validación en móvil físico del contacto antes de la primera expedición real: criterio de aceptación.

## Vinculación, autenticación y reglas de Firestore
- Firebase Auth con **Google Sign-In**: reinstalar o cambiar de móvil conserva identidad y vínculos.
- Código de **10 caracteres base32** (50 bits), un solo uso, caduca a 10 min, en `pairingCodes/{código}`. Reglas: `get` por ID permitido, `list` prohibido. El QR contiene el mismo código.
- Canje atómico: el contacto escribe `pairings/{id}` en un batch que marca el código como usado; validado con `getAfter()` (existe, no caducado, no usado, `contactUid == request.auth.uid`).
- Reglas por campo: solo el explorador escribe expedición y check-ins; cada contacto escribe solo su propio `armedAt` y `ackAt`.
- Tony puede desvincular a un contacto y este pierde la lectura de inmediato.
- **Retención:** política **TTL de Firestore** sobre un campo `expireAt` (30 días tras finalizar), gratis y sin Blaze.
- Tests de reglas con el emulador: obligatorios en cada cambio.

## Modelo de datos (Firestore, persistencia offline activada)
- `users/{uid}`: rol, nombre, `fcmToken` (reservado para fase 3), plataforma.
- `pairingCodes/{código}`: `explorerUid`, `expiresAt`, `used`.
- `pairings/{id}`: `explorerUid`, `contactUid`, creado.
- `expeditions/{id}`: `explorerUid`, `contactUids[]`, nombre, zona, `startAt`, `deadlineAt`, `status`, `checkinIntervalMin?`, `createdAt`, `expireAt?`.
- `expeditions/{id}/checkins/{id}`: `at`, `lat`, `lng`, `battery`.
- `expeditions/{id}/contacts/{uid}`: `armedAt`, `armedDeadlineVersion`, `ackAt`.

## Funciones fase 1 (MVP)
1. Vincular con código/QR.
2. Crear expedición (nombre, zona, salida, hora límite, intervalo opcional); sincroniza al contacto con cobertura.
3. Botón TODO OK con cola offline de Firestore.
4. Check-ins/ampliar el límite según la semántica de arriba.
5. Alarma local a pantalla completa con última posición y zona.
6. Finalizar: cierra y cancela la alarma local de los contactos.
Pantallas: Tony (expedición activa, botón, estado de armado de contactos, historial, ajustes); Contacto (estado, cuenta atrás, última posición, permisos, "Probar alarma").

## Fase 2 (spec propia)
Servicio GPS en primer plano con intervalo configurable, mapas offline (`flutter_map` + caché OSM), ruta prevista dibujada/GPX, subida del track, exportación GPX, ruta real sobre la prevista para el contacto. SMS de respaldo con un toque cuando hay voz pero no datos (opcional).

## Fase 3 (opcional, requiere Blaze)
Cloud Function programada cada minuto con transacción idempotente, push FCM de alta prioridad como respaldo, escalado automático a otros contactos. Alertas de presupuesto a 1 € y 5 €, sin apagado automático de facturación, y política de limpieza de imágenes en Artifact Registry.

## Riesgos aceptados (explícitos)
1. Sin servidor: si el móvil del contacto está apagado, sin batería o con la app cerrada a la fuerza, **no suena nada** y nadie lo detecta.
2. iPhone: sin vía gratuita de instalación y, instalado, puede quedar silenciado.
3. Sin señal no llega la posición; la hora límite es la única alerta.
La app muestra una línea fija con estos límites en el primer arranque y en cada expedición.

## Privacidad y repositorio
- Repo **privado**; `google-services.json` fuera de git y claves de API restringidas por paquete y huella SHA-1.
- Ubicación solo visible para contactos vinculados; revocable; retención por TTL.

## Pruebas
Unitarias de la lógica de límite/reprogramación/hora efectiva y de la cola de TODO OK; tests de reglas con el emulador; tests del canje de código; checklist manual en móvil real (alarma en silencio, app cerrada, modo avión, reinicio, fabricante concreto, "Probar alarma").

## Stress Test Results: App TODO OK

### Resolved Decisions
- Semántica: TODO OK nunca desarma; solo Finalizar. Estados `active|alarm|finished`.
- Falsa alarma: ante la duda suena; los check-ins tardíos no apagan una alarma disparada.
- Reloj: UTC y hora efectiva mínima cliente/servidor.
- Contacto: confirmación de armado visible y obligatoria, acuse con reintento local, reprogramación tras reinicio.
- Servidor: **sin Blaze en fase 1** (decisión de Tony tras discutir coste); capa servidor pasa a fase 3.
- Reglas/vinculación: Google Sign-In, código de 50 bits, canje atómico, escrituras por campo, TTL.
- iPhone: se mantiene alarma degradada por decisión de Tony; instalación fuera de la gratuidad.
- Android: `setAlarmClock`, permisos guiados, "Probar alarma", validación física.
- Seguridad: riesgos aceptados documentados; app en repo privado separado; claves restringidas.

### Changes Made
Eliminado el estado `ok`; añadidos armado, acuse, BOOT_COMPLETED, TTL, hora efectiva; capa servidor y escalado movidos a fase 3; app movida a repo privado.

### Deferred / Parking Lot
Cloud Function + push de respaldo + escalado (fase 3); Apple Developer y Critical Alerts/time-sensitive en iOS; SMS de respaldo (fase 2).

### Confidence Assessment
- Overall: Medium. La lógica es sólida, pero la fiabilidad real depende de móviles físicos y fabricantes que no se pueden probar desde la nube.
- Áreas de preocupación: riesgo 1 (sin servidor) y la instalación en iPhone.

## Cambios por revisión del plan (2026-11-20)
Estos puntos del stress-test del plan prevalecen sobre el texto anterior de esta spec:
- Estado adicional `planned` (antes de iniciar) y campo `alarmFiredAt`.
- Alarma con dos ranuras (principal y repetición); "Recibida" no cancela una alarma principal futura; un check-in de Tony tras `alarm` rearma la expedición a `active`.
- El contacto necesita un servicio en primer plano permanente mientras haya vínculo (tipo `specialUse`); sin él no se reprograma la alarma ni llega una expedición nueva. Se valida en un spike previo.
- Retención: `expireAt` en checkins/contacts (45 d) y en expediciones (`deadlineAt` + 30 d); TTL no es en cascada y puede tardar 24–72 h.
- El gate de salida exige armado vigente y latido del contacto de menos de 10 min.
- Una sola clave de firma de release en Firebase y distribución con Firebase App Distribution.
