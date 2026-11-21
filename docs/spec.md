# Especificación — App de entrenamiento de escalada en bloque (Tony)

Estado: **borrador para aprobación**. No se programa nada hasta que Tony lo apruebe.
Fecha: 2026-11-21. Macrociclo objetivo: enero–diciembre de 2027.

Convenciones de este documento:
- **[DECIDIDO]** lo acordado en la entrevista.
- **[PENDIENTE]** falta un dato de Tony o una verificación mía.
- **[PROVISIONAL]** valor de arranque editable hasta que se importe el estudio.

---

## 1. Resumen

Dos aplicaciones Android sobre un mismo backend:

1. **App de Tony** (Flutter, APK): atleta (plan, sesión del día, tests, Tindeq, bienestar, nutrición, competiciones) + **modo entrenador** (clientes y clases).
2. **App cliente** (Flutter, APK, solo Android al principio): el cliente ve su entreno, lo registra, ve su evolución, rellena bienestar y se comunica con Tony.

Objetivos de producto:
- Importar planes y documentos desde PDF con IA y revisión humana obligatoria.
- Llevar la sesión con temporizadores y el Tindeq Progressor por Bluetooth, todo offline.
- Calcular cargas, carga semanal, semáforo y nutrición con reglas **transparentes y editables**.
- Nada de datos inventados: si falta un dato, la app lo pide.

---

## 2. Usuarios y roles

| Rol | App | Qué puede |
|---|---|---|
| Atleta (Tony) | App de Tony | Todo lo personal. Cuenta propia. |
| Entrenador (Tony) | App de Tony | Gestionar clientes y clases. **Cuenta separada** de la de atleta. [DECIDIDO] |
| Cliente | App cliente | Solo sus propios datos y lo que Tony le asigna. |

- Inicio de sesión con correo y contraseña. [DECIDIDO]
- Datos privados por defecto. Compartir solo con enlace de solo lectura, con caducidad y datos elegidos. [DECIDIDO]
- Los datos de clientes nunca se mezclan con los personales de Tony. [DECIDIDO]
- Clientes: ~10-20 al inicio, ampliable. Habrá algunos menores. [DECIDIDO]

---

## 3. Plataforma y arquitectura

### 3.1 Cliente
- **Flutter**, Android (móvil y tablet). APK. [DECIDIDO]
- Tablet en horizontal con barra lateral; móvil con barra inferior de 5 secciones (Hoy, Plan, Progreso, Nutrición, Más). [DECIDIDO]
- **Offline total**: base local (SQLite, p. ej. Drift) como fuente de verdad en el dispositivo; sincronización posterior. [DECIDIDO]
- Widget de pantalla de inicio (sesión de hoy + semáforo). Wake lock durante sesión. [DECIDIDO]
- Sin reloj en v1. [DECIDIDO]
- iPhone: fuera de alcance al principio. [DECIDIDO]
- PC: acceso a datos sincronizados; formato (web o escritorio) [PENDIENTE: decidir en plan por fases].

### 3.2 Backend (recomendación, pendiente de verificación de límites)
- **Supabase (plan gratuito)**: base de datos Postgres con RLS por usuario, autenticación, almacenamiento de archivos. [DECIDIDO como recomendación]
- **Cloudflare Worker (gratuito)**: función intermediaria que guarda la clave de Anthropic y lee los PDF. La clave **nunca** va en la app ni en el repositorio. [DECIDIDO]
- [PENDIENTE] Verificar en la documentación oficial: límites gratuitos, **pausa por inactividad** de Supabase y cuotas de Workers.
- La API de Anthropic **no es gratuita**: pago por uso con la clave de Tony. [PENDIENTE: estimación mensual]

### 3.3 Sincronización
- Cada dispositivo escribe en local y encola cambios; el servidor reconcilia.
- Conflictos: última escritura gana por campo en datos simples; en sesiones registradas gana el dispositivo conectado al Tindeq. [DECIDIDO]
- Multimedia (fotos y vídeo cortos) **solo en el dispositivo**; a la nube solo metadatos. [DECIDIDO]
- PDF originales: en dispositivo y en nube privada. [DECIDIDO]

### 3.4 Entrega del APK
- Se intenta compilar en este entorno y entregar el APK directo. Si el entorno no tiene Android SDK, se avisa y se compila por otra vía (p. ej. GitHub Actions). [DECIDIDO / PENDIENTE de comprobación]

---

## 4. Importación de PDF

### 4.1 Flujo
1. Tony sube un PDF (o foto/escaneo).
2. La app lo envía al Worker, que llama a un modelo de Claude con **esquema JSON estricto**.
3. Se valida el JSON contra el esquema.
4. **Pantalla de revisión editable** (fases → semanas → sesiones → ejercicios). Campos dudosos o ausentes quedan **vacíos y resaltados**; no se inventa nada. [DECIDIDO]
5. Solo tras confirmar se guarda.

### 4.2 Reglas
- Los PDF llegan mezclados (tablas, texto, fotos). Revisión más exigente en imágenes. [DECIDIDO]
- Reimportar crea **nueva versión**; la anterior queda archivada; el nuevo plan se activa desde la fecha elegida. [DECIDIDO]
- Modelo potente para planes y analíticas. [DECIDIDO] Modelo concreto y coste mensual [PENDIENTE].
- Se conservan las **capacidades** (prioritaria, complementaria, suplementaria, otra) como etiqueta de ejercicio, con filtros, gráficos y alerta de capacidad prioritaria descuidada. [DECIDIDO por delegación]

### 4.3 Otros PDF
Estudio biomecánico, analítica de sangre, bioimpedancia y prueba de esfuerzo usan la misma pantalla de revisión y, al confirmar, actualizan datos de Tony. [DECIDIDO]
- El **estudio biomecánico** alimenta: reglas de recuperación tras expedición, valores de referencia por nivel y criterios de macros. Hasta importarlo, valores [PROVISIONAL].

### 4.4 Entrenamiento actual hasta enero
Tony introduce a mano, semana a semana, el plan de su entrenador actual. En enero se importa su macrociclo propio. Todo el historial se conserva. [DECIDIDO]

---

## 5. Modelo de planificación

Jerarquía: **Macrociclo → Mesociclo (con fase) → Microciclo (semana) → Día → Sesión → Bloque → Ejercicio → Serie.** [DECIDIDO]

- Fases: acumulación, intensificación, pico, descarga, competición (colorean calendario y gráficos).
- Un día puede tener 1 o 2 sesiones, con hora y duración.
- Bloques de sesión: calentamiento, principal, complementario, vuelta a la calma.
- Tipos de ejercicio con campos y temporizadores propios: suspensiones/repeaters (Tindeq/regleta), bloque y proyectos (intentos, tops, grado, sector, estilo), fuerza general/gimnasio, resistencia/ARC/cardio/movilidad.
- Intensidad: % del máximo del test, % del pico del Tindeq, RPE/EPL/EPG, kg absolutos o RIR.
- Cada serie guarda **prescrito** y **realizado** por separado. [DECIDIDO]
- Estados de ejercicio: Hecho / Modificado / Saltado (si modificado, se pregunta qué cambió). [DECIDIDO]

### 5.1 Reprogramación
Si se mueve o salta una sesión, la app **propone opciones** (mover, fusionar, recortar, saltar) con su impacto en la carga semanal. Tony elige. [DECIDIDO]

### 5.2 Expediciones
- Evento detallado en el calendario: duración, sueño, comida, agua, esfuerzo, ambiente, carga transportada y peso antes/después. [DECIDIDO]
- La app propone remodelar la semana o los días necesarios según reglas de recuperación **basadas en el estudio**; Tony acepta. [DECIDIDO]
- Cada regla indica su origen. Si el estudio no cubre un caso (p. ej. más de 48 h sin agua), se usa un valor conservador marcado **«sin respaldo del estudio»**, editable. [DECIDIDO]
- Cuentan en la carga semanal con color propio. [DECIDIDO]

### 5.3 Calendario
Vista año (franjas por fase) y vista mes (sesiones, expediciones, tests, competiciones). [DECIDIDO]

---

## 6. Sesión del día

- Pantalla «Hoy»: sesión en orden, modo pantalla completa, números enormes, botones ≥ 56 px, controles principales abajo. [DECIDIDO]
- Temporizadores: suspensiones, repeaters 7:3, descansos encadenados; pitidos con cuenta final 3-2-1; vibración; **voz** que anuncia el siguiente ejercicio. [DECIDIDO]
- Registro por serie: carga real, repeticiones, tiempo, ajuste +/- en un toque. Por ejercicio: RPE y dolor por zona (dedos, hombro, codo, muñeca; dedo concreto si hay molestia). Notas de texto o voz. [DECIDIDO]
- Adjuntar foto o vídeo corto a un ejercicio (solo en dispositivo). [DECIDIDO]
- **EPG/EPL a los 30 min** de terminar: notificación; si se ignora, la sesión queda «pendiente de valorar». [DECIDIDO]
- Ajuste según estado del día: el semáforo propone, Tony decide. [DECIDIDO]

---

## 7. Tindeq Progressor

### 7.1 Conexión
- Nuestra app se conecta **directamente** al Progressor por Bluetooth y sustituye a la app oficial durante el entreno. [DECIDIDO]
- Se asume una única conexión Bluetooth a la vez (no pueden coexistir app oficial y la nuestra, ni dos dispositivos). [PENDIENTE: verificar en documentación oficial]
- Se usa en móvil y tablet, solo uno conectado a la vez. La tablet lleva la sesión en horizontal. [DECIDIDO]
- Las series de suspensión, repeaters y fuerza máxima se configuran en nuestra app; el % se calcula sobre el último test registrado **en nuestra app**. [DECIDIDO]
- Importación de CSV de la app oficial como dato medido. [DECIDIDO]

### 7.2 Medición
- Inicio y fin **automáticos** al detectar carga (umbral editable). [DECIDIDO]
- Tara automática al conectar y antes de cada serie; si hay carga al tarar se avisa y se descarta. [DECIDIDO]
- Se guarda la **curva completa** (serie temporal) y se recalculan métricas cuando haga falta. [DECIDIDO]
- Unidades: kg y N **a la vez**. [DECIDIDO]
- Pantalla en vivo: curva en tiempo real, número grande con % del pico, cuenta atrás y repeticiones, pico y media al instante. [DECIDIDO]

### 7.3 Calidad de datos
- Detección de picos anormales o saturación.
- Aviso de batería y calibración (comprobación con peso conocido).
- Descarte de series con tara incorrecta o deriva de línea base. [DECIDIDO]
- Si se corta el Bluetooth: reintento, serie marcada incompleta, opción de repetir. Entrada manual siempre disponible, etiquetada como **manual** para no mezclarla con datos medidos. [DECIDIDO]
- [PENDIENTE] Protocolo BLE exacto (servicio, características, comandos, frecuencia de muestreo) verificado en documentación oficial antes de implementar.

---

## 8. Tests

### 8.1 Calendario de tests
Lo define el **plan importado**. Recordatorios: 3 días antes, el mismo día con el protocolo, y aviso si se retrasa. [DECIDIDO]

### 8.2 Batería
**Con Tindeq (20 mm, por mano):** semiarqueo, extendido, arqueo; pinza y romo con bloque de agarres (20/15/10/5 mm); RFD y tiempo hasta el pico; fuerza crítica.

**Sin Tindeq (formulario propio por test):** suspensión máxima 10 s con lastre en 18 mm, regleta mínima, campus de alcance máximo, dominada 1RM (directa, con lastre real), bloqueo a una mano (directo), circuito de bloques con caída de fuerza (resultado, tiempo por bloque, picos antes/después), core, empuje, talonaje (puntuación 1-5) y movilidad (grados o cm).

### 8.3 Protocolo
- Mejor de 2-3 intentos como resultado; se guardan todos. [DECIDIDO]
- Manos alternadas con descanso fijo. [DECIDIDO]
- **Calentamiento guiado** con progresión (≈50-70-85 %) antes de máximos. [DECIDIDO]
- **CF y W′:** all-out de 24 repeticiones 7:3 en 20 mm. Fórmula exacta de CF (sobre qué repeticiones) y de W′ (impulso por encima de CF) [PENDIENTE: fijar contra literatura y estudio].

### 8.4 Derivados
Fuerza relativa (pico / peso corporal), asimetría izquierda/derecha en % (umbral de alerta editable), CF/MVC, W′/MVC, tiempo hasta el pico y RFD. [DECIDIDO]

### 8.5 Recálculo
- Con un test nuevo, la app **propone** las cargas nuevas (antes/después por ejercicio) y Tony acepta, con deshacer. [DECIDIDO]
- Si un test sale peor, pregunta si fue un mal día y permite repetir; no baja cargas por un solo dato. [DECIDIDO]

---

## 9. Bienestar y semáforo

- Cuestionario diario (<30 s): sueño (horas y calidad), cansancio/recuperación, dolor por zona, estrés, motivación, apetito, piel. Escala 1-10 donde aplique. [DECIDIDO]
- Dos momentos: mañana (aviso a hora fija) y recordatorio rápido antes de entrenar; el semáforo se recalcula. [DECIDIDO]
- Salida: **verde / ámbar / rojo con puntuación** y motivo de cada descuento. Siempre con icono y texto, nunca solo color. [DECIDIDO]
- Acciones: sesión tal cual; bajar intensidad o volumen; cambiar por técnica o recuperación; descansar. [DECIDIDO]
- **Reglas visibles, cada una con interruptor y valor editable.** Umbrales [PROVISIONAL] hasta el estudio. [DECIDIDO]
- **Tony decide**: con rojo, la app recomienda y explica; si entrena igualmente, se registra que ignoró el aviso. [DECIDIDO]
- Alertas de sobrecarga: subida brusca de carga semanal; dolor repetido en la misma zona o dedo; bienestar bajo sostenido; sesión intensa antes de completar la recuperación tras expedición. Umbrales editables. [DECIDIDO]

---

## 10. Carga y gráficos

- Carga semanal = **EPG × minutos reales (sRPE)**. Expediciones suman con color propio. [DECIDIDO]
- Carga específica de dedos desde la curva del Tindeq: **fuera de v1**, prevista. [DECIDIDO]
- Gráficos imprescindibles: evolución de cada test (línea por mano, marcas de fase), carga semanal, bienestar vs rendimiento, peso y composición corporal. [DECIDIDO]
- Pantalla principal: sesión de hoy + semáforo, semana en curso, últimos tests con tendencia, próximo hito con cuenta atrás. [DECIDIDO]
- Interacción: tocar punto para detalle, filtrar fechas y tipo, comparar dos periodos, zoom y desplazamiento. [DECIDIDO]
- Referencias por nivel (intermedio, avanzado, élite) como **bandas** sobre el gráfico, editables; valores a importar del estudio. [DECIDIDO]
- Estilo limpio y oscuro; color por mano y por fase. [DECIDIDO]
- Exportar como imagen o PDF, y compartir informe periódico o enlace de solo lectura con el entrenador. [DECIDIDO]

---

## 11. Nutrición y suplementos

### 11.1 Cálculo
- Energía = TMB (fórmula o bioimpedancia) × factor según carga del día (descanso, entreno, doble sesión, expedición). [DECIDIDO]
- Objetivo corporal **por fase** (mantener, ganar masa, bajar grasa) con límites editables. [DECIDIDO]
- Macros provisionales: proteína ~1,6 g/kg/día; carbohidratos 5-7 g/kg en días de entreno. Criterios definitivos del estudio. [PROVISIONAL]
- Se recalcula al subir peso, bioimpedancia o analítica. [DECIDIDO]

### 11.2 Alimentos y comidas
- Lista editable de alimentos permitidos y vetados (poca fruta y verdura, pasta solo blanca, huevo solo revuelto, lácteos solo leche y yogur sin trozos). [DECIDIDO]
- Ingredientes se introducen por foto de etiqueta, código de barras, formulario manual o importación Excel/CSV/PDF, con revisión. Si falta un dato nutricional, el ingrediente queda **incompleto**; no se inventa. [DECIDIDO]
- Tony define nombre e ingredientes de una comida; la app calcula **cantidades** (ajusta gramos para cuadrar macros, con límites por ingrediente) y la **preparación**. [DECIDIDO]
- Registro rápido con plantillas de comidas habituales. [DECIDIDO]

### 11.3 Suplementos
Gestión con horario por fase de **todos los que Tony tome**, entre ellos creatina y whey, beta-alanina en tomas ≤ 2 g, cafeína antes de sesiones clave, gelatina con vitamina C antes de sesiones de tendón, geles y electrolitos. Marca preferida: Vitastrong. Recordatorios. [DECIDIDO] Lista con dosis [PENDIENTE: la aporta Tony].

### 11.4 Vuelta de expedición
Pauta escalonada de rehidratación y recarga según duración y peso perdido (peso antes/después). Valores [PROVISIONAL] hasta el estudio, marcados como tales. [DECIDIDO]

---

## 12. Competiciones

- Datos: generales (nombre, fecha, lugar, categoría, circuito, tipo bloque/cuerda), resultado (puesto, participantes, puntuación), detalle por bloque (top, zona, intentos), fases (clasificación, semifinal, final). [DECIDIDO]
- Prioridad **A/B/C** (Campeonato de España = A). [DECIDIDO]
- Se integran en el calendario con semanas de pico y descarga; la app **propone** cambios. [DECIDIDO]
- Cuerda (absoluta de Andalucía) como competición de baja prioridad con campos propios (vía, altura, caídas). [DECIDIDO]
- **Campeonato de Andalucía de bloque** como circuito: pruebas disputadas (domingo y Jaén), puesto y puntos por prueba, clasificación general (actualmente 5º) y pruebas pendientes. [DECIDIDO]
- Calendario: lo introduce Tony, o importa PDF/foto con revisión. [DECIDIDO]
- Checklist: equipaje (editable), nutrición del día hora a hora, calentamiento guiado, cuenta atrás D-7/D-3/D-1. [DECIDIDO]
- Diario post-competición: qué salió bien/mal, estado físico y mental 1-10, bloques clave con foto/vídeo, aprendizajes que pasan a objetivos del siguiente mesociclo. [DECIDIDO]
- Estadísticas: evolución de puestos y puntuación, % de tops y zonas, relación con tests y carga, comparación con otros competidores (si se introducen). [DECIDIDO]

---

## 13. Modo entrenador y app cliente

### 13.1 Gestión
- Clientes individuales y **clases**. Una clase: mismo entreno para el grupo con ajustes individuales; lista de asistentes y asistencia; evolución individual; niveles o subgrupos. [DECIDIDO]
- Alta de cliente con **consentimiento aceptado en la app** (qué datos, quién los ve, exportar/borrar). Menores: consentimiento del tutor; edad mínima [PENDIENTE]. [DECIDIDO]

### 13.2 Diseño de planes
- Plantillas de Tony + **borrador de IA** (objetivo, nivel, disponibilidad, limitaciones) que Tony revisa y edita antes de subir. [DECIDIDO]
- Cada recomendación de la IA se etiqueta con su origen: documento subido por Tony o conocimiento general. Sin fuentes inventadas. La IA **sugiere, no decide**. [DECIDIDO]

### 13.3 App cliente
- Ve su entreno del día con temporizadores y registro, su evolución y tests, bienestar diario con semáforo, y mensajes/notas con Tony (sin chat completo). [DECIDIDO]
- **No usa IA.** Envía sus documentos a la app de Tony, donde Tony los descarga y analiza. [DECIDIDO]
- Tindeq para clientes: [PENDIENTE: confirmar si lo usarán].
- Solo Android en v1. [DECIDIDO]

### 13.4 Privacidad
- Los clientes solo ven lo suyo; Tony solo ve los suyos en modo entrenador. Políticas de acceso por usuario en la base de datos (RLS). [DECIDIDO]
- Los datos de clientes (salud, menores) exigen revisión RGPD antes de producción. [PENDIENTE]

---

## 14. Diseño

- Estilo oscuro deportivo de alto contraste; acento **naranja fuego** sobre casi negro. [DECIDIDO]
- Semáforo con verde, ámbar y carmesí oscuro, siempre con icono y texto. [DECIDIDO]
- Botones ≥ 56 px, uso con una mano y magnesio, modo sesión a pantalla completa. [DECIDIDO]
- Solo modo oscuro; tamaño de texto ajustable. [DECIDIDO]
- Nombre y **logo de TonyLocuras** en la pantalla de inicio. Logo [PENDIENTE: Tony lo pasa como archivo, PNG transparente o SVG].
- Sin referencias visuales: propondré dirección con pantallas clave antes de construir. [DECIDIDO]

---

## 15. Datos, copias y exportación

- Copia automática en la nube + exportación manual. [DECIDIDO]
- Exportación: JSON completo, CSV por tablas, PDF de informes, curvas del Tindeq en CSV. [DECIDIDO]
- Todos los datos en español. [DECIDIDO]

---

## 16. Modelo de datos (entidades principales)

`usuario`, `perfil_atleta`, `plan` (versionado), `macrociclo`, `mesociclo`, `microciclo`, `dia`, `sesion`, `bloque`, `ejercicio_prescrito`, `serie_prescrita`, `serie_realizada` (+ `curva_tindeq`), `registro_dolor`, `test_definicion`, `test_resultado`, `cuestionario_diario`, `regla_semaforo`, `expedicion`, `competicion`, `circuito`, `resultado_bloque`, `alimento`, `comida`, `registro_comida`, `suplemento`, `toma_suplemento`, `documento` (PDF), `medicion_corporal`, `analitica`, `cliente`, `clase`, `asistencia`, `mensaje`, `consentimiento`.

Todo registro de dato lleva `origen` (medido / manual / importado / IA) y `fecha`. Esquema SQL detallado en la fase de diseño técnico.

---

## 17. Módulo de cálculos (aparte y con tests)

Módulo independiente, documentado y con tests unitarios para: cargas por % (máximo del test y pico Tindeq), fuerza relativa, asimetría, RFD, tiempo hasta el pico, CF y W′, sRPE y carga semanal, ratio de carga aguda/crónica o subida semanal, semáforo, energía y macros, recarga tras expedición. [DECIDIDO]

---

## 18. Notificaciones

Cuestionario matinal, recordatorio pre-sesión, EPG/EPL a los 30 min, tests (3 días antes, mismo día, retraso), suplementos, vuelta de expedición, cuenta atrás de competición. Horarios [PENDIENTE: Tony los define].

---

## 19. Seguridad

- Clave de Anthropic solo en el Worker. Nunca en el código ni en el repositorio. [DECIDIDO]
- RLS en la base de datos; JWT por usuario; el Worker valida el usuario antes de llamar a la IA.
- Tony es el único que dispara la IA; los clientes no tienen acceso. [DECIDIDO]
- Opción de bloqueo por huella o PIN: no solicitada; prevista como mejora.

---

## 20. Fuera de alcance de v1

Reloj, espejo móvil-tablet en directo, iPhone, carga específica de dedos desde la curva, integración GoPro/Garmin, informe de contenido para TonyLocuras, modo coach asistido por IA avanzado, varias temporadas (modelo preparado, interfaz posterior), búsqueda online del calendario.

---

## 21. Pendientes consolidados

De Tony:
1. Lista de suplementos con dosis y horarios.
2. Últimos valores de fuerza (pico Tindeq por agarre y mano, dominada) para calcular % desde el día 1.
3. Plan actual del entrenador (fase y semana en curso).
4. Resultados del domingo y de Jaén, y calendario restante del Campeonato de Andalucía.
5. Horas de los recordatorios.
6. Estudio biomecánico y pruebas médicas (cuando los tenga).
7. Logo del canal como archivo.
8. Edad mínima de clientes y gestión del consentimiento de tutores.
9. Si los clientes usarán Tindeq.

Mías (verificación):
1. Protocolo BLE del Tindeq Progressor y si admite una sola conexión.
2. Límites gratuitos de Supabase y Cloudflare, y pausa por inactividad.
3. Modelo de Claude concreto y coste mensual estimado.
4. Fórmula exacta de CF y W′.
5. Si este entorno puede compilar el APK.
6. Requisitos RGPD para datos de salud de terceros y menores.

---

## 22. Plan por fases propuesto (para aprobar)

1. **Fase 0 — Cimientos:** proyecto Flutter, base local, login, sincronización básica, módulo de cálculos con tests, tema y navegación.
2. **Fase 1 — MVP atleta:** plan manual, sesión del día con temporizadores, registro, calendario, bienestar y semáforo.
3. **Fase 2 — Tindeq y tests:** conexión Bluetooth, biofeedback, batería de tests, derivados, recálculo de cargas.
4. **Fase 3 — Importación PDF:** Worker, esquema, pantalla de revisión, versiones del plan y otros PDF.
5. **Fase 4 — Gráficos y competiciones:** gráficos, bandas de referencia, Campeonato de Andalucía, checklist y diario.
6. **Fase 5 — Nutrición y suplementos.**
7. **Fase 6 — Modo entrenador y app cliente:** clientes, clases, planes con IA, mensajes, consentimientos.
8. **Fase 7 — Pulido:** widget, copias, exportación, rendimiento y revisión de privacidad.

Cada fase termina con un APK de prueba y pasos para probarla. Tony pidió tener el modo entrenador antes del primer APK; se contrasta con el riesgo de construir mucho sin probar y se decide al aprobar el plan.
