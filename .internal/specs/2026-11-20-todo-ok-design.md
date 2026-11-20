# App TODO OK — Diseño (fase 1 MVP + fase 2)

Fuente: "App Todo OK – planteamiento para Claude Code" (PDF de Tony) + decisiones de brainstorming del 2026-11-20.

## Objetivo
App Flutter para expediciones de TonyLocuras. Tony confirma con un botón; si no lo hace antes de la hora límite, el contacto recibe una alarma aunque Tony no tenga cobertura. Sin dispositivos externos ni suscripciones.

## Decisiones tomadas
| Tema | Decisión |
|---|---|
| Ubicación del código | `/todo_ok` dentro de este repo (aparte de la web) |
| Stack | Flutter (Android + iOS), Firebase: Auth, Firestore, FCM; Cloud Functions (plan Blaze) |
| Alarma | **Híbrida**: local en el móvil del contacto + Cloud Function de respaldo |
| iPhone | Alarma degradada aceptada por Tony: notificación normal, puede quedar silenciada por No Molestar/Concentración. La app debe avisarlo al contacto iOS |
| Entrega | MVP primero; GPS/mapas/GPX en fase 2 |
| Entorno de Tony | Nada preparado: se entrega guía de montaje de Firebase y Flutter |

## Principio de seguridad
La alarma depende de la **hora límite**, no de que Tony envíe nada. Si Tony falla (batería, sin cobertura, incapacitado), la alarma suena igual.

## Arquitectura de alarma (dos capas independientes)
1. **Local (Android, fiable):** el contacto, al sincronizar la expedición, programa una alarma exacta (`SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, canal con prioridad de alarma que ignora silencio). Cada TODO OK o check-in cancela y reprograma con la nueva hora límite. Finalizar cancela.
2. **Servidor (respaldo):** Cloud Function programada (cada minuto) busca expediciones activas con `deadline < now` y estado no OK, marca `alarm` y envía FCM de alta prioridad al contacto. Es idempotente (no repite push si ya está en `alarm`).

Fallos conocidos asumidos: contacto con el móvil apagado, en modo avión o con la app forzada a cerrar tras fabricante agresivo de batería. La app del contacto muestra una pantalla de comprobación de permisos/optimización de batería.

## Modelo de datos (Firestore, persistencia offline activada)
- `users/{uid}`: rol (`explorer`|`contact`), nombre, `fcmToken`, plataforma.
- `pairings/{id}`: `explorerUid`, `contactUid`, creado por código de 8 caracteres de un solo uso con caducidad (o QR del mismo código).
- `expeditions/{id}`: `explorerUid`, `contactUids[]`, nombre, zona, `startAt`, `deadlineAt`, `status` (`active`|`ok`|`alarm`|`finished`), `checkinIntervalMin?`, `createdAt`.
- `expeditions/{id}/checkins/{id}`: `at`, `lat`, `lng`, `battery`, `kind` (`ok`|`checkin`).
- Reglas: solo el explorador y sus contactos vinculados leen la expedición; solo el explorador escribe checkins y estado; la Cloud Function escribe `alarm`.

## Funciones fase 1 (MVP)
1. **Vincular**: Tony genera código/QR, el contacto lo introduce o escanea.
2. **Crear expedición**: nombre, zona, salida, hora límite. Sincroniza al contacto con cobertura.
3. **Botón TODO OK**: un toque; guarda hora, última coordenada y batería. Sin datos: queda en la cola offline de Firestore y se reintenta.
4. **Check-ins opcionales**: intervalo configurable; cada uno amplía la hora límite por el intervalo.
5. **Alarma por hora límite**: pantalla completa y sonido en Android con la última posición conocida y la zona.
6. **Finalizar**: cierra la expedición y cancela alarmas local y de servidor.
Pantallas: Tony (inicio con expedición activa y botón, historial, ajustes); Contacto (estado OK/pendiente/alarma, cuenta atrás, última posición).

## Fase 2 (fuera del MVP, spec propia)
Servicio GPS en primer plano con intervalo configurable, mapas offline (`flutter_map` + caché de teselas OSM), ruta prevista dibujada/GPX, subida del track, exportación GPX, ruta real sobre la prevista para el contacto.

## Permisos y requisitos
Notificaciones, alarmas exactas, exención de optimización de batería, ubicación (en segundo plano en fase 2). Persistencia offline de Firestore activada.

## Riesgos y límites
- Sin señal, la posición no llega; la hora límite es la alerta.
- iOS: sin Critical Alerts, la alarma puede no sonar en silencio.
- Blaze exige tarjeta (coste esperado 0 €); fijar presupuesto/alerta de gasto.
- No se puede probar en móvil físico desde la sesión en la nube: Tony compila y valida alarma en silencio, ahorro de batería y reinicio del móvil.

## Pruebas
Unitarias de la lógica de hora límite/reprogramación y la cola de TODO OK; tests de reglas de Firestore con el emulador; test de la Cloud Function (idempotencia); checklist manual en móvil real (alarma en silencio, app cerrada, modo avión, reinicio).
