# TODO OK — Fase 1 (MVP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use beads-superpowers:subagent-driven-development (recommended) or beads-superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent <epic-id>`). Steps within tasks use checkbox (`- [ ]`) syntax for human readability.

**Goal:** App Flutter donde Tony confirma con un botón TODO OK y, si vence la hora límite sin Finalizar, el móvil Android del contacto hace sonar una alarma a pantalla completa aunque Tony no tenga cobertura.

**Architecture:** Lógica pura en Dart (hora límite, código de vinculación, orquestador de alarmas) cubierta con tests. Firestore con reglas estrictas es la única barrera de seguridad (sin Cloud Functions). La alarma es nativa Android (`setAlarmClock` + actividad a pantalla completa) y un servicio en primer plano en el móvil del contacto mantiene vivo el listener para reprogramarla.

**Tech Stack:** Flutter 3.x / Dart, Firebase (Auth con Google, Firestore con persistencia offline, plan Spark), Kotlin para la alarma nativa, `@firebase/rules-unit-testing` + Node para las reglas, `flutter_foreground_task`, `geolocator`, `battery_plus`, `mobile_scanner`, `qr_flutter`.

## Código fuente de la spec y precisiones

Spec: `.internal/specs/2026-11-20-todo-ok-design.md`. Este plan **corrige o precisa** la spec en tres puntos (aceptados al aprobar el plan):

1. **Estado `planned`** añadido (`planned | active | alarm | finished`). Hace falta para que los contactos armen la alarma antes de que Tony salga.
2. **Servicio en primer plano en el contacto** mientras haya una expedición `planned`/`active`. Sin servidor no hay push; sin listener vivo la alarma local no se reprogramaría tras un check-in y daría falsas alarmas. Si el servicio muere, la alarma sigue en la última hora programada (falsa alarma posible, nunca alarma perdida por esta causa).
3. **Extensión manual del límite:** acotada por el servidor a `request.time + checkinIntervalMin` (o 24 h si no hay intervalo). Un reloj de cliente adelantado no puede estirar el límite más allá de lo permitido por la hora de recepción.

## Global Constraints

- Repo **privado** separado; `google-services.json` fuera de git; claves de API restringidas por paquete y huella SHA-1.
- Firebase plan **Spark**; prohibido usar Cloud Functions/Blaze en fase 1.
- Todas las horas en UTC; formato local solo al mostrar.
- Estados: `planned | active | alarm | finished`. **TODO OK nunca desarma la alarma**; solo `finished` la cancela.
- Hora efectiva del check-in = `min(hora_cliente, hora_servidor)`; límite nuevo = `max(límite_actual, efectiva + intervalo)`; sin intervalo el check-in no mueve el límite.
- Ante la duda, suena: ningún dato dudoso apaga una alarma. Un check-in tardío no apaga una alarma ya disparada.
- Código de vinculación: 10 caracteres base32 (alfabeto Crockford), un solo uso, caduca a 10 min, `get` sí / `list` no.
- Alarma Android: `setAlarmClock`, canal de alarma, pantalla completa; acuse "Recibida" obligatorio; sin acuse en 5 min vuelve a sonar.
- Retención: TTL de Firestore sobre `expireAt` (30 días tras finalizar).
- Línea fija de límites visible en el primer arranque y en cada expedición.
- iPhone: notificación local degradada; instalación fuera de la gratuidad (Apple Developer + Mac).
- Tests de reglas con el emulador en cada cambio de reglas. Validación en móvil físico antes de la primera expedición real.

## Verificación y entorno (leer antes de ejecutar)

El contenedor en la nube **no tiene Flutter ni Dart** (solo Node 22). Los tests de Dart (`flutter test`) y la compilación Android se ejecutan en la máquina de Tony o tras instalar el SDK en el entorno de sesión. Los tests de reglas de Firestore (Node) sí se pueden ejecutar aquí. Ningún criterio de alarma se da por verificado sin el checklist en móvil físico (Task 14).

## File Structure

```
todo_ok/
  pubspec.yaml
  analysis_options.yaml
  .gitignore
  firebase.json, firestore.indexes.json
  firebase/firestore.rules
  firebase/test/rules.test.js, firebase/package.json
  docs/SETUP.md, docs/DEVICE_CHECKLIST.md
  lib/main.dart, lib/app.dart
  lib/domain/deadline.dart          # horas efectivas y límite
  lib/domain/pairing_code.dart      # generar/normalizar código
  lib/domain/expedition.dart        # modelo + estados
  lib/alarm/alarm_scheduler.dart    # interfaz + AlarmSpec + fake
  lib/alarm/android_alarm_scheduler.dart  # MethodChannel
  lib/alarm/alarm_orchestrator.dart # reglas de armado/reprogramación
  lib/data/auth_repository.dart, pairing_repository.dart,
           expedition_repository.dart, arming_repository.dart
  lib/service/watch_service.dart    # servicio primer plano del contacto
  lib/ui/... (login, role, pairing, explorer_home, create_expedition,
              contact_home, permissions, limits_banner)
  test/domain/*.dart, test/alarm/alarm_orchestrator_test.dart
  android/app/src/main/kotlin/com/tonylocuras/todook/
     MainActivity.kt, AlarmChannel.kt, AlarmStore.kt, AlarmRinger.kt,
     AlarmReceiver.kt, AlarmActivity.kt, BootReceiver.kt
```

---

### Task 1: Guía de montaje y andamiaje del proyecto

**Files:**
- Create: `docs/SETUP.md`, `.gitignore`, `analysis_options.yaml`, `pubspec.yaml`, `lib/main.dart`, `firebase.json`, `firestore.indexes.json`

**Interfaces:**
- Produces: proyecto Flutter que compila vacío; `Firebase.initializeApp` y persistencia offline activada en `main()`.

**Acceptance Criteria:**
- `docs/SETUP.md` permite a alguien sin nada instalado dejar Flutter, Android Studio y Firebase listos.
- `google-services.json` y `lib/firebase_options.dart` generados no están versionados.
- `flutter analyze` sin errores.

- [ ] **Step 1: Crear el repo privado y el proyecto**

```bash
gh repo create todo-ok --private --clone && cd todo-ok
flutter create --org com.tonylocuras --project-name todo_ok --platforms=android,ios .
```

- [ ] **Step 2: `.gitignore` (añadir al final del generado)**

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
firebase/node_modules/
*.keystore
key.properties
```

- [ ] **Step 3: `docs/SETUP.md`** con estos apartados, cada uno con pasos numerados y comandos exactos: (1) instalar Flutter y Android Studio; `flutter doctor`; (2) crear proyecto Firebase en la consola, **dejar el plan Spark**; (3) activar Authentication → Google y Firestore (modo producción, región `eur3`); (4) `dart pub global activate flutterfire_cli && flutterfire configure --project=<id> --platforms=android,ios`; (5) añadir la huella SHA-1 (`cd android && ./gradlew signingReport`) en Firebase y restringir la clave de API por paquete `com.tonylocuras.todook` y SHA-1 en Google Cloud → Credenciales; (6) política TTL: Firestore → Ajustes → TTL → colección `expeditions`, campo `expireAt`; (7) `firebase deploy --only firestore:rules,firestore:indexes`; (8) instalar el APK en el móvil del contacto permitiendo "instalar apps desconocidas".

- [ ] **Step 4: `pubspec.yaml` dependencias**

```yaml
dependencies:
  flutter: {sdk: flutter}
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  google_sign_in: ^6.2.1
  geolocator: ^13.0.1
  battery_plus: ^6.1.0
  mobile_scanner: ^5.2.3
  qr_flutter: ^4.1.0
  flutter_foreground_task: ^8.14.0
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
  intl: ^0.19.0
dev_dependencies:
  flutter_test: {sdk: flutter}
  flutter_lints: ^5.0.0
```

- [ ] **Step 5: `lib/main.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  runApp(const TodoOkApp());
}
```

- [ ] **Step 6: `lib/app.dart`** con `MaterialApp` mínimo (`home: Scaffold(body: Center(child: Text('TODO OK')))`) y `class TodoOkApp extends StatelessWidget`.
- [ ] **Step 7: Verify** `flutter analyze` → sin errores. **Step 8: Commit** `git add -A && git commit -m "chore: andamiaje Flutter y guía de montaje"`.

---

### Task 2: Lógica de hora límite (TDD, Dart puro)

**Files:**
- Create: `lib/domain/deadline.dart`
- Test: `test/domain/deadline_test.dart`

**Interfaces:**
- Produces: `DateTime effectiveCheckinTime({required DateTime clientTime, required DateTime serverReceivedAt})`; `DateTime nextDeadline({required DateTime currentDeadline, required DateTime effectiveCheckin, Duration? interval})`.

**Acceptance Criteria:**
- Un reloj de cliente futuro se recorta a la hora del servidor.
- Sin intervalo el límite no cambia; con intervalo nunca se adelanta; un check-in no puede acortar el límite.

- [ ] **Step 1: Test que falla**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_ok/domain/deadline.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 12);
  test('reloj de cliente futuro se recorta a la hora del servidor', () {
    expect(effectiveCheckinTime(clientTime: t0.add(const Duration(hours: 2)), serverReceivedAt: t0), t0);
  });
  test('reloj de cliente pasado se conserva', () {
    final past = t0.subtract(const Duration(hours: 1));
    expect(effectiveCheckinTime(clientTime: past, serverReceivedAt: t0), past);
  });
  test('sin intervalo el límite no se mueve', () {
    final d = t0.add(const Duration(hours: 8));
    expect(nextDeadline(currentDeadline: d, effectiveCheckin: t0, interval: null), d);
  });
  test('con intervalo amplía el límite', () {
    final d = t0.add(const Duration(hours: 1));
    expect(nextDeadline(currentDeadline: d, effectiveCheckin: t0, interval: const Duration(hours: 3)), t0.add(const Duration(hours: 3)));
  });
  test('un check-in nunca acorta el límite', () {
    final d = t0.add(const Duration(hours: 10));
    expect(nextDeadline(currentDeadline: d, effectiveCheckin: t0, interval: const Duration(hours: 3)), d);
  });
}
```

- [ ] **Step 2:** `flutter test test/domain/deadline_test.dart` → FAIL (archivo inexistente).
- [ ] **Step 3: Implementación**

```dart
DateTime effectiveCheckinTime({required DateTime clientTime, required DateTime serverReceivedAt}) =>
    clientTime.isAfter(serverReceivedAt) ? serverReceivedAt : clientTime;

DateTime nextDeadline({required DateTime currentDeadline, required DateTime effectiveCheckin, Duration? interval}) {
  if (interval == null) return currentDeadline;
  final candidate = effectiveCheckin.add(interval);
  return candidate.isAfter(currentDeadline) ? candidate : currentDeadline;
}
```

- [ ] **Step 4:** test → PASS. **Step 5: Commit** `feat: lógica de hora límite y hora efectiva`.

---

### Task 3: Código de vinculación (TDD)

**Files:**
- Create: `lib/domain/pairing_code.dart`
- Test: `test/domain/pairing_code_test.dart`

**Interfaces:**
- Produces: `String generatePairingCode([Random? rng])`; `String? normalizePairingCode(String raw)`; `const pairingCodeLength = 10`.

**Acceptance Criteria:**
- Código de 10 caracteres del alfabeto Crockford, generado con `Random.secure()` por defecto.
- `normalizePairingCode` acepta minúsculas, espacios y guiones, y corrige O→0, I/L→1; devuelve `null` si no es válido.

- [ ] **Step 1: Test que falla**

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_ok/domain/pairing_code.dart';

void main() {
  test('genera 10 caracteres válidos', () {
    final c = generatePairingCode(Random(1));
    expect(c.length, pairingCodeLength);
    expect(normalizePairingCode(c), c);
  });
  test('normaliza minúsculas, guiones y confusiones', () {
    expect(normalizePairingCode('ab12-cd34 ef'), 'AB12CD34EF');
    expect(normalizePairingCode('OIL0000000'), '0110000000');
  });
  test('rechaza longitud o caracteres inválidos', () {
    expect(normalizePairingCode('ABC'), isNull);
    expect(normalizePairingCode('UUUUUUUUUU'), isNull); // U no está en el alfabeto
  });
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implementación**

```dart
import 'dart:math';

const pairingCodeLength = 10;
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String generatePairingCode([Random? rng]) {
  final r = rng ?? Random.secure();
  return List.generate(pairingCodeLength, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

String? normalizePairingCode(String raw) {
  final s = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '').replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
  if (s.length != pairingCodeLength) return null;
  return s.split('').every(_alphabet.contains) ? s : null;
}
```

- [ ] **Step 4:** PASS. **Step 5: Commit** `feat: código de vinculación base32`.

---

### Task 4: Reglas de Firestore y tests con emulador

**Files:**
- Create: `firebase/firestore.rules`, `firebase/package.json`, `firebase/test/rules.test.js`
- Modify: `firebase.json`

**Interfaces:**
- Produces: colecciones `users/{uid}`, `pairingCodes/{code}`, `pairings/{explorerUid}_{contactUid}`, `expeditions/{id}` (campos: `explorerUid, explorerName, contactUids[], name, zone, startAt, deadlineAt, status, checkinIntervalMin?, lastCheckinAt?, lastLat?, lastLng?, lastBattery?, createdAt, expireAt?`), `expeditions/{id}/checkins/{id}` (`at, serverAt, lat?, lng?, battery`), `expeditions/{id}/contacts/{uid}` (`armedAt?, armedDeadlineMs?, ackAt?`).

**Acceptance Criteria:**
- Solo el explorador crea/edita la expedición; ningún usuario ajeno lee nada.
- El canje del código solo funciona si existe, no caducó, no se usó y el canjeador es el autenticado.
- Un contacto solo escribe su propio documento de `contacts/{uid}` y solo puede poner `status: alarm` si `request.time >= deadlineAt`.
- El límite solo puede ampliarse hasta `request.time + checkinIntervalMin` (24 h sin intervalo).
- Desvincular revoca la lectura.

- [ ] **Step 1: `firebase/package.json`**

```json
{ "name": "todo-ok-rules", "private": true, "scripts": { "test": "firebase emulators:exec --only firestore --project demo-todook \"node --test test/\"" },
  "devDependencies": { "@firebase/rules-unit-testing": "^3.0.4", "firebase": "^10.14.0", "firebase-tools": "^13.22.0" } }
```
Y en `firebase.json`: `{"firestore":{"rules":"firebase/firestore.rules","indexes":"firestore.indexes.json"},"emulators":{"firestore":{"port":8080}}}`.

- [ ] **Step 2: Test que falla (`firebase/test/rules.test.js`)**

```js
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs, writeBatch, Timestamp } = require('firebase/firestore');

let env;
const ts = (ms) => Timestamp.fromMillis(Date.now() + ms);
const H = 3600 * 1000;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-todook', firestore: { rules: fs.readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const exp = (over = {}) => ({ explorerUid: 'tony', explorerName: 'Tony', contactUids: ['ana'], name: 'Mina', zone: 'Rodalquilar',
  startAt: ts(0), deadlineAt: ts(8 * H), status: 'active', checkinIntervalMin: 180, createdAt: ts(0), ...over });
const seed = (data = exp()) => env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'expeditions/e1'), data));

test('ajeno no lee la expedición', async () => {
  await seed();
  await assertFails(getDoc(doc(db('eve'), 'expeditions/e1')));
  await assertSucceeds(getDoc(doc(db('ana'), 'expeditions/e1')));
  await assertSucceeds(getDoc(doc(db('tony'), 'expeditions/e1')));
});
test('solo el explorador crea su expedición', async () => {
  await assertSucceeds(setDoc(doc(db('tony'), 'expeditions/e2'), exp({ status: 'planned' })));
  await assertFails(setDoc(doc(db('ana'), 'expeditions/e3'), exp({ status: 'planned' })));
});
test('el límite no se amplía más allá de request.time + intervalo', async () => {
  await seed(exp({ deadlineAt: ts(1 * H) }));
  await assertSucceeds(updateDoc(doc(db('tony'), 'expeditions/e1'), { deadlineAt: ts(2.9 * H) }));
  await assertFails(updateDoc(doc(db('tony'), 'expeditions/e1'), { deadlineAt: ts(10 * H) }));
});
test('el límite puede acortarse', async () => {
  await seed();
  await assertSucceeds(updateDoc(doc(db('tony'), 'expeditions/e1'), { deadlineAt: ts(1 * H) }));
});
test('el contacto solo pone alarm si venció el límite', async () => {
  await seed(exp({ deadlineAt: ts(2 * H) }));
  await assertFails(updateDoc(doc(db('ana'), 'expeditions/e1'), { status: 'alarm' }));
  await seed(exp({ deadlineAt: ts(-1 * H) }));
  await assertSucceeds(updateDoc(doc(db('ana'), 'expeditions/e1'), { status: 'alarm' }));
  await assertFails(updateDoc(doc(db('ana'), 'expeditions/e1'), { status: 'finished' }));
});
test('el contacto solo escribe su propio armado', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db('ana'), 'expeditions/e1/contacts/ana'), { armedAt: ts(0), armedDeadlineMs: 1 }));
  await assertFails(setDoc(doc(db('ana'), 'expeditions/e1/contacts/bob'), { armedAt: ts(0) }));
  await assertFails(setDoc(doc(db('tony'), 'expeditions/e1/contacts/ana'), { armedAt: ts(0) }));
});
test('canje de código: válido una vez, no caducado, solo el autenticado', async () => {
  await assertSucceeds(setDoc(doc(db('tony'), 'pairingCodes/ABC1234567'), { explorerUid: 'tony', used: false, expiresAt: ts(9 * 60 * 1000) }));
  await assertFails(getDocs(collection(db('ana'), 'pairingCodes')));
  const redeem = async (uid, code) => {
    const b = writeBatch(db(uid));
    b.update(doc(db(uid), `pairingCodes/${code}`), { used: true, redeemedBy: uid });
    b.set(doc(db(uid), `pairings/tony_${uid}`), { explorerUid: 'tony', contactUid: uid, code });
    return b.commit();
  };
  await assertSucceeds(redeem('ana', 'ABC1234567'));
  await assertFails(redeem('bob', 'ABC1234567')); // ya usado
});
test('código caducado no se canjea', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'pairingCodes/OLD1234567'), { explorerUid: 'tony', used: false, expiresAt: Timestamp.fromMillis(Date.now() - 1000) }));
  const b = writeBatch(db('ana'));
  b.update(doc(db('ana'), 'pairingCodes/OLD1234567'), { used: true, redeemedBy: 'ana' });
  b.set(doc(db('ana'), 'pairings/tony_ana'), { explorerUid: 'tony', contactUid: 'ana', code: 'OLD1234567' });
  await assertFails(b.commit());
});
test('desvincular: solo el explorador borra el vínculo', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'pairings/tony_ana'), { explorerUid: 'tony', contactUid: 'ana', code: 'X' }));
  await assertFails(deleteDoc(doc(db('ana'), 'pairings/tony_ana')));
  await assertSucceeds(deleteDoc(doc(db('tony'), 'pairings/tony_ana')));
});
test('check-ins solo los escribe el explorador', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db('tony'), 'expeditions/e1/checkins/c1'), { at: ts(0), battery: 80 }));
  await assertFails(setDoc(doc(db('ana'), 'expeditions/e1/checkins/c2'), { at: ts(0), battery: 80 }));
  await assertSucceeds(getDoc(doc(db('ana'), 'expeditions/e1/checkins/c1')));
});
```

- [ ] **Step 3:** `cd firebase && npm install && npm test` → FAIL (no existen reglas).
- [ ] **Step 4: `firebase/firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }
    function expDoc(id) { return get(/databases/$(db)/documents/expeditions/$(id)).data; }
    function isExplorerOf(id) { return signedIn() && expDoc(id).explorerUid == request.auth.uid; }
    function isContactOf(id) { return signedIn() && request.auth.uid in expDoc(id).contactUids; }
    function intervalMin() { return request.resource.data.get('checkinIntervalMin', 1440); }

    match /users/{uid} {
      allow read, write: if signedIn() && request.auth.uid == uid;
    }

    match /pairingCodes/{code} {
      allow get: if signedIn();
      allow list: if false;
      allow create: if signedIn()
        && request.resource.data.explorerUid == request.auth.uid
        && request.resource.data.used == false
        && request.resource.data.expiresAt > request.time
        && request.resource.data.expiresAt <= request.time + duration.value(10, 'm');
      allow update: if signedIn()
        && resource.data.used == false
        && resource.data.expiresAt > request.time
        && request.resource.data.used == true
        && request.resource.data.redeemedBy == request.auth.uid
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['used', 'redeemedBy'])
        && existsAfter(/databases/$(db)/documents/pairings/$(resource.data.explorerUid + '_' + request.auth.uid));
      allow delete: if signedIn() && resource.data.explorerUid == request.auth.uid;
    }

    match /pairings/{pid} {
      allow read: if signedIn() && (resource.data.explorerUid == request.auth.uid || resource.data.contactUid == request.auth.uid);
      allow create: if signedIn()
        && request.resource.data.contactUid == request.auth.uid
        && pid == request.resource.data.explorerUid + '_' + request.auth.uid
        && getAfter(/databases/$(db)/documents/pairingCodes/$(request.resource.data.code)).data.redeemedBy == request.auth.uid
        && getAfter(/databases/$(db)/documents/pairingCodes/$(request.resource.data.code)).data.explorerUid == request.resource.data.explorerUid
        && get(/databases/$(db)/documents/pairingCodes/$(request.resource.data.code)).data.used == false;
      allow delete: if signedIn() && resource.data.explorerUid == request.auth.uid;
    }

    match /expeditions/{id} {
      allow read: if signedIn() && (resource.data.explorerUid == request.auth.uid || request.auth.uid in resource.data.contactUids);
      allow create: if signedIn()
        && request.resource.data.explorerUid == request.auth.uid
        && request.resource.data.status in ['planned', 'active']
        && request.resource.data.deadlineAt > request.time;
      allow update: if signedIn() && (
        // explorador
        (resource.data.explorerUid == request.auth.uid
          && request.resource.data.explorerUid == resource.data.explorerUid
          && request.resource.data.status in ['planned', 'active', 'alarm', 'finished']
          && (request.resource.data.deadlineAt <= resource.data.deadlineAt
              || request.resource.data.deadlineAt <= request.time + duration.value(intervalMin(), 'm')))
        ||
        // contacto: solo puede disparar alarm tras vencer el límite
        (request.auth.uid in resource.data.contactUids
          && resource.data.status == 'active'
          && request.resource.data.status == 'alarm'
          && request.time >= resource.data.deadlineAt
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'alarmFiredAt'])));
      allow delete: if false;

      match /checkins/{cid} {
        allow read: if isExplorerOf(id) || isContactOf(id);
        allow create: if isExplorerOf(id);
        allow update, delete: if false;
      }
      match /contacts/{uid} {
        allow read: if isExplorerOf(id) || (signedIn() && request.auth.uid == uid);
        allow create, update: if signedIn() && request.auth.uid == uid && isContactOf(id);
        allow delete: if false;
      }
    }
  }
}
```

- [ ] **Step 5:** `npm test` → PASS (todos). Si un test de `get()` con `extension` falla por el emulador, ajustar la regla, nunca el test.
- [ ] **Step 6: Commit** `feat: reglas de Firestore y tests de emulador`.

---

### Task 5: Modelo de dominio de la expedición

**Files:**
- Create: `lib/domain/expedition.dart`
- Test: `test/domain/expedition_test.dart`

**Interfaces:**
- Produces: `enum ExpeditionStatus { planned, active, alarm, finished }`; `class Expedition` con `id, explorerUid, explorerName, contactUids, name, zone, startAt, deadlineAt, status, checkinInterval (Duration?), lastCheckinAt?, lastLat?, lastLng?, lastBattery?, alarmFiredAt? (DateTime?, lo escribe el contacto con serverTimestamp al disparar)`; `factory Expedition.fromMap(String id, Map<String, dynamic> m)` (Timestamps vía `toDate().toUtc()`); `Map<String, dynamic> toMap()`; `bool get isOverdue(DateTime now)`.

**Acceptance Criteria:**
- Ida y vuelta `toMap`/`fromMap` conserva todos los campos y las horas en UTC.
- `ExpeditionStatus` se serializa por nombre; un valor desconocido lanza `FormatException`.

- [ ] **Step 1: Test que falla**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_ok/domain/expedition.dart';

void main() {
  test('ida y vuelta conserva campos en UTC', () {
    final e = Expedition(id: 'e1', explorerUid: 't', explorerName: 'Tony', contactUids: ['a'], name: 'Mina', zone: 'Rodalquilar',
      startAt: DateTime.utc(2026, 11, 20, 8), deadlineAt: DateTime.utc(2026, 11, 20, 20), status: ExpeditionStatus.active,
      checkinInterval: const Duration(hours: 3));
    final back = Expedition.fromMap('e1', e.toMap());
    expect(back.deadlineAt, e.deadlineAt);
    expect(back.deadlineAt.isUtc, isTrue);
    expect(back.checkinInterval, const Duration(hours: 3));
    expect(back.status, ExpeditionStatus.active);
  });
  test('estado desconocido falla', () {
    expect(() => Expedition.fromMap('x', {'status': 'zzz'}), throwsFormatException);
  });
  test('isOverdue', () {
    final e = Expedition(id: 'e', explorerUid: 't', explorerName: 'T', contactUids: [], name: 'n', zone: 'z',
      startAt: DateTime.utc(2026), deadlineAt: DateTime.utc(2026, 1, 1, 10), status: ExpeditionStatus.active);
    expect(e.isOverdue(DateTime.utc(2026, 1, 1, 10, 1)), isTrue);
    expect(e.isOverdue(DateTime.utc(2026, 1, 1, 9)), isFalse);
  });
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implementación**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpeditionStatus { planned, active, alarm, finished }

ExpeditionStatus _parseStatus(Object? v) => ExpeditionStatus.values.firstWhere((s) => s.name == v, orElse: () => throw FormatException('estado desconocido: $v'));
DateTime _ts(Object? v) => (v as Timestamp).toDate().toUtc();

class Expedition {
  Expedition({required this.id, required this.explorerUid, required this.explorerName, required this.contactUids, required this.name,
    required this.zone, required this.startAt, required this.deadlineAt, required this.status, this.checkinInterval,
    this.lastCheckinAt, this.lastLat, this.lastLng, this.lastBattery});

  final String id, explorerUid, explorerName, name, zone;
  final List<String> contactUids;
  final DateTime startAt, deadlineAt;
  final ExpeditionStatus status;
  final Duration? checkinInterval;
  final DateTime? lastCheckinAt;
  final double? lastLat, lastLng;
  final int? lastBattery;

  bool isOverdue(DateTime now) => !now.isBefore(deadlineAt);

  factory Expedition.fromMap(String id, Map<String, dynamic> m) => Expedition(
    id: id, explorerUid: m['explorerUid'] as String? ?? '', explorerName: m['explorerName'] as String? ?? '',
    contactUids: List<String>.from(m['contactUids'] ?? const []), name: m['name'] as String? ?? '', zone: m['zone'] as String? ?? '',
    startAt: m['startAt'] == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : _ts(m['startAt']),
    deadlineAt: m['deadlineAt'] == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : _ts(m['deadlineAt']),
    status: _parseStatus(m['status']),
    checkinInterval: m['checkinIntervalMin'] == null ? null : Duration(minutes: m['checkinIntervalMin'] as int),
    lastCheckinAt: m['lastCheckinAt'] == null ? null : _ts(m['lastCheckinAt']),
    lastLat: (m['lastLat'] as num?)?.toDouble(), lastLng: (m['lastLng'] as num?)?.toDouble(), lastBattery: m['lastBattery'] as int?);

  Map<String, dynamic> toMap() => {
    'explorerUid': explorerUid, 'explorerName': explorerName, 'contactUids': contactUids, 'name': name, 'zone': zone,
    'startAt': Timestamp.fromDate(startAt), 'deadlineAt': Timestamp.fromDate(deadlineAt), 'status': status.name,
    if (checkinInterval != null) 'checkinIntervalMin': checkinInterval!.inMinutes,
    if (lastCheckinAt != null) 'lastCheckinAt': Timestamp.fromDate(lastCheckinAt!),
    if (lastLat != null) 'lastLat': lastLat, if (lastLng != null) 'lastLng': lastLng, if (lastBattery != null) 'lastBattery': lastBattery,
  };
}
```

- [ ] **Step 4:** PASS. **Step 5: Commit** `feat: modelo de expedición`.

---

### Task 6: Orquestador de alarmas (TDD con scheduler falso)

**Files:**
- Create: `lib/alarm/alarm_scheduler.dart`, `lib/alarm/alarm_orchestrator.dart`
- Test: `test/alarm/alarm_orchestrator_test.dart`

**Interfaces:**
- Consumes: `Expedition`, `ExpeditionStatus` (Task 5).
- Produces:
  - `class AlarmSpec { String expeditionId, explorerName, name, zone; DateTime fireAt; DateTime? lastCheckinAt; double? lastLat, lastLng; Map<String, dynamic> toMap(); }`
  - `abstract class AlarmScheduler { Future<bool> permissionsOk(); Future<void> schedule(AlarmSpec s); Future<void> cancel(String expeditionId); }`
  - `class FakeAlarmScheduler implements AlarmScheduler` (campos `scheduled` Map y `permissions` bool, para tests).
  - `abstract class ArmReporter { Future<void> reportArmed(String expeditionId, int deadlineMs); Future<void> clearArmed(String expeditionId); }`
  - `class AlarmOrchestrator { AlarmOrchestrator(AlarmScheduler s, ArmReporter r); Future<void> apply(Expedition e); }`

**Acceptance Criteria:**
- `planned`/`active` con permisos: programa a `deadlineAt` y reporta armado con la versión del límite.
- Sin permisos: no programa y limpia el armado.
- `finished`: cancela. `alarm`: **no cancela** (ni reprograma).
- Un límite ampliado reprograma y reporta la nueva versión; el límite no se adelanta con un check-in.

- [ ] **Step 1: Test que falla**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_ok/alarm/alarm_orchestrator.dart';
import 'package:todo_ok/alarm/alarm_scheduler.dart';
import 'package:todo_ok/domain/expedition.dart';

class _Reporter implements ArmReporter {
  final armed = <String, int>{};
  @override Future<void> reportArmed(String id, int ms) async => armed[id] = ms;
  @override Future<void> clearArmed(String id) async => armed.remove(id);
}

Expedition _e(ExpeditionStatus s, DateTime d) => Expedition(id: 'e1', explorerUid: 't', explorerName: 'Tony', contactUids: ['a'], name: 'Mina',
  zone: 'Rodalquilar', startAt: DateTime.utc(2026, 11, 20, 8), deadlineAt: d, status: s);

void main() {
  late FakeAlarmScheduler sch; late _Reporter rep; late AlarmOrchestrator o;
  final d1 = DateTime.utc(2026, 11, 20, 20);
  setUp(() { sch = FakeAlarmScheduler(); rep = _Reporter(); o = AlarmOrchestrator(sch, rep); });

  test('active con permisos programa y reporta armado', () async {
    await o.apply(_e(ExpeditionStatus.active, d1));
    expect(sch.scheduled['e1']!.fireAt, d1);
    expect(rep.armed['e1'], d1.millisecondsSinceEpoch);
  });
  test('planned también arma', () async {
    await o.apply(_e(ExpeditionStatus.planned, d1));
    expect(sch.scheduled.containsKey('e1'), isTrue);
  });
  test('sin permisos no programa y limpia el armado', () async {
    sch.permissions = false; rep.armed['e1'] = 1;
    await o.apply(_e(ExpeditionStatus.active, d1));
    expect(sch.scheduled, isEmpty);
    expect(rep.armed, isEmpty);
  });
  test('finished cancela', () async {
    await o.apply(_e(ExpeditionStatus.active, d1));
    await o.apply(_e(ExpeditionStatus.finished, d1));
    expect(sch.scheduled, isEmpty);
  });
  test('alarm NO cancela ni reprograma', () async {
    await o.apply(_e(ExpeditionStatus.active, d1));
    await o.apply(_e(ExpeditionStatus.alarm, d1.add(const Duration(hours: 5))));
    expect(sch.scheduled['e1']!.fireAt, d1);
  });
  test('límite ampliado reprograma y reporta nueva versión', () async {
    await o.apply(_e(ExpeditionStatus.active, d1));
    final d2 = d1.add(const Duration(hours: 3));
    await o.apply(_e(ExpeditionStatus.active, d2));
    expect(sch.scheduled['e1']!.fireAt, d2);
    expect(rep.armed['e1'], d2.millisecondsSinceEpoch);
  });
}
```

- [ ] **Step 2:** FAIL. **Step 3: `lib/alarm/alarm_scheduler.dart`**

```dart
class AlarmSpec {
  AlarmSpec({required this.expeditionId, required this.explorerName, required this.name, required this.zone, required this.fireAt,
    this.lastCheckinAt, this.lastLat, this.lastLng});
  final String expeditionId, explorerName, name, zone;
  final DateTime fireAt;
  final DateTime? lastCheckinAt;
  final double? lastLat, lastLng;
  Map<String, dynamic> toMap() => {
    'expeditionId': expeditionId, 'explorerName': explorerName, 'name': name, 'zone': zone,
    'fireAtMillis': fireAt.millisecondsSinceEpoch, 'lastCheckinMillis': lastCheckinAt?.millisecondsSinceEpoch,
    'lastLat': lastLat, 'lastLng': lastLng,
  };
}

abstract class AlarmScheduler {
  Future<bool> permissionsOk();
  Future<void> schedule(AlarmSpec s);
  Future<void> cancel(String expeditionId);
}

class FakeAlarmScheduler implements AlarmScheduler {
  final scheduled = <String, AlarmSpec>{};
  bool permissions = true;
  @override Future<bool> permissionsOk() async => permissions;
  @override Future<void> schedule(AlarmSpec s) async => scheduled[s.expeditionId] = s;
  @override Future<void> cancel(String id) async => scheduled.remove(id);
}
```

- [ ] **Step 4: `lib/alarm/alarm_orchestrator.dart`**

```dart
import '../domain/expedition.dart';
import 'alarm_scheduler.dart';

abstract class ArmReporter {
  Future<void> reportArmed(String expeditionId, int deadlineMs);
  Future<void> clearArmed(String expeditionId);
}

class AlarmOrchestrator {
  AlarmOrchestrator(this._scheduler, this._reporter);
  final AlarmScheduler _scheduler;
  final ArmReporter _reporter;

  Future<void> apply(Expedition e) async {
    switch (e.status) {
      case ExpeditionStatus.finished:
        await _scheduler.cancel(e.id);
        await _reporter.clearArmed(e.id);
      case ExpeditionStatus.alarm:
        return; // ya sonó: nunca se cancela ni reprograma por datos
      case ExpeditionStatus.planned:
      case ExpeditionStatus.active:
        if (!await _scheduler.permissionsOk()) {
          await _reporter.clearArmed(e.id);
          return;
        }
        await _scheduler.schedule(AlarmSpec(expeditionId: e.id, explorerName: e.explorerName, name: e.name, zone: e.zone,
          fireAt: e.deadlineAt, lastCheckinAt: e.lastCheckinAt, lastLat: e.lastLat, lastLng: e.lastLng));
        await _reporter.reportArmed(e.id, e.deadlineAt.millisecondsSinceEpoch);
    }
  }
}
```

- [ ] **Step 5:** PASS. **Step 6: Commit** `feat: orquestador de alarmas`.

---

### Task 7: Alarma nativa Android (Kotlin)

**Files:**
- Create: `android/app/src/main/kotlin/com/tonylocuras/todook/{AlarmStore,AlarmRinger,AlarmReceiver,AlarmActivity,BootReceiver,AlarmChannel}.kt`, `lib/alarm/android_alarm_scheduler.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`

**Interfaces:**
- Consumes: `AlarmSpec.toMap()`, `AlarmScheduler` (Task 6).
- Produces: canal `todook/alarm` con métodos `schedule(Map)`, `cancel(String)`, `permissions() → Map<String,bool>{exactAlarm,fullScreen,notifications,batteryExempt}`, `openSetting(String)`, `testAlarm()`, `pendingAcks() → List<String>`, `clearAck(String)`; `class AndroidAlarmScheduler implements AlarmScheduler` con `Future<Map<String,bool>> permissions()`.

**Acceptance Criteria:**
- La alarma se programa con `setAlarmClock` y sobrevive al cierre de la app.
- Al disparar: notificación de pantalla completa en el canal de alarma (sonido por `STREAM_ALARM`, vibración) y `AlarmActivity` sobre la pantalla bloqueada.
- Sin acuse en 5 min vuelve a programarse a sí misma y suena otra vez.
- Tras reiniciar el móvil se reprograman las alarmas guardadas.
- Pulsar "Recibida" detiene el sonido y registra el acuse local para sincronizarlo.

- [ ] **Step 1: Manifest** (dentro de `<manifest>`): permisos `SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`. Dentro de `<application>`:

```xml
<activity android:name=".AlarmActivity" android:exported="false" android:showWhenLocked="true" android:turnScreenOn="true"
          android:launchMode="singleTask" android:excludeFromRecents="true"/>
<receiver android:name=".AlarmReceiver" android:exported="false"/>
<receiver android:name=".BootReceiver" android:exported="true">
  <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter>
</receiver>
```

- [ ] **Step 2: `AlarmStore.kt`** (persistencia local de alarmas y acuses)

```kotlin
package com.tonylocuras.todook
import android.content.Context
import org.json.JSONObject

object AlarmStore {
  private fun p(c: Context) = c.getSharedPreferences("todook_alarms", Context.MODE_PRIVATE)
  fun save(c: Context, id: String, spec: JSONObject) = p(c).edit().putString("alarm_$id", spec.toString()).apply()
  fun remove(c: Context, id: String) = p(c).edit().remove("alarm_$id").apply()
  fun get(c: Context, id: String): JSONObject? = p(c).getString("alarm_$id", null)?.let { JSONObject(it) }
  fun all(c: Context): List<JSONObject> = p(c).all.filterKeys { it.startsWith("alarm_") }.values.map { JSONObject(it as String) }
  fun addAck(c: Context, id: String) = p(c).edit().putStringSet("acks", (p(c).getStringSet("acks", emptySet())!! + id)).apply()
  fun acks(c: Context): List<String> = p(c).getStringSet("acks", emptySet())!!.toList()
  fun clearAck(c: Context, id: String) = p(c).edit().putStringSet("acks", (p(c).getStringSet("acks", emptySet())!! - id)).apply()
}
```

- [ ] **Step 3: `AlarmReceiver.kt`** (programar, disparar, reintento a 5 min)

```kotlin
package com.tonylocuras.todook
import android.app.*
import android.content.*
import android.os.Build
import androidx.core.app.NotificationCompat

object Alarms {
  const val CHANNEL = "todook_alarm"
  fun pending(c: Context, id: String): PendingIntent =
    PendingIntent.getBroadcast(c, id.hashCode(), Intent(c, AlarmReceiver::class.java).putExtra("id", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  fun set(c: Context, id: String, atMillis: Long) {
    val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val show = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
    am.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, show), pending(c, id))
  }
  fun cancel(c: Context, id: String) { (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(c, id)); AlarmStore.remove(c, id) }
}

class AlarmReceiver : BroadcastReceiver() {
  override fun onReceive(c: Context, i: Intent) {
    val id = i.getStringExtra("id") ?: return
    val spec = AlarmStore.get(c, id) ?: return
    val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 26) {
      nm.createNotificationChannel(NotificationChannel(Alarms.CHANNEL, "Alarma TODO OK", NotificationManager.IMPORTANCE_HIGH).apply {
        setSound(null, null); enableVibration(true); lockscreenVisibility = Notification.VISIBILITY_PUBLIC; setBypassDnd(true) })
    }
    val full = PendingIntent.getActivity(c, id.hashCode(), Intent(c, AlarmActivity::class.java).putExtra("id", id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val n = NotificationCompat.Builder(c, Alarms.CHANNEL).setSmallIcon(android.R.drawable.ic_dialog_alert)
      .setContentTitle("ALARMA: ${spec.optString("explorerName")} no ha confirmado").setContentText("${spec.optString("name")} · ${spec.optString("zone")}")
      .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX).setFullScreenIntent(full, true)
      .setOngoing(true).setAutoCancel(false).build()
    nm.notify(id.hashCode(), n)
    AlarmRinger.start(c)
    // reintento: si nadie da acuse en 5 min vuelve a sonar
    Alarms.set(c, id, System.currentTimeMillis() + 5 * 60 * 1000)
  }
}
```

- [ ] **Step 4: `AlarmRinger.kt`** (sonido por canal de alarma, ignora silencio)

```kotlin
package com.tonylocuras.todook
import android.content.Context
import android.media.*
import android.os.*

object AlarmRinger {
  private var player: MediaPlayer? = null
  private var vib: Vibrator? = null
  @Synchronized fun start(c: Context) {
    if (player?.isPlaying == true) return
    val am = c.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
    player = MediaPlayer().apply {
      setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
      setDataSource(c, uri); isLooping = true; prepare(); start()
    }
    vib = c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    vib?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 400), 0))
  }
  @Synchronized fun stop() { player?.stop(); player?.release(); player = null; vib?.cancel() }
}
```

- [ ] **Step 5: `AlarmActivity.kt`** (pantalla completa con "Recibida")

```kotlin
package com.tonylocuras.todook
import android.app.*
import android.os.Bundle
import android.view.*
import android.widget.*
import java.text.SimpleDateFormat
import java.util.*

class AlarmActivity : Activity() {
  override fun onCreate(b: Bundle?) {
    super.onCreate(b)
    setShowWhenLocked(true); setTurnScreenOn(true)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    val id = intent.getStringExtra("id") ?: return finish()
    val s = AlarmStore.get(this, id)
    val fmt = SimpleDateFormat("dd/MM HH:mm", Locale.getDefault())
    val last = s?.optLong("lastCheckinMillis", 0L) ?: 0L
    val pos = if (s != null && !s.isNull("lastLat")) "${s.optDouble("lastLat")}, ${s.optDouble("lastLng")}" else "sin posición"
    val tv = TextView(this).apply {
      textSize = 22f; setPadding(48, 96, 48, 48)
      text = "⚠ ${s?.optString("explorerName")} NO HA CONFIRMADO\n\nExpedición: ${s?.optString("name")}\nZona: ${s?.optString("zone")}\n" +
        "Último check-in: ${if (last > 0) fmt.format(Date(last)) else "ninguno"}\nÚltima posición: $pos"
    }
    val btn = Button(this).apply {
      text = "RECIBIDA"; textSize = 24f
      setOnClickListener {
        AlarmRinger.stop(); Alarms.cancel(this@AlarmActivity, id)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(id.hashCode())
        AlarmStore.addAck(this@AlarmActivity, id); finish()
      }
    }
    setContentView(LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; addView(tv); addView(btn) })
  }
}
```

Nota: `Alarms.cancel` borra el registro local; el acuse queda en `acks` y Dart lo sincroniza (Task 9). El estado de la expedición no se toca aquí.

- [ ] **Step 6: `BootReceiver.kt`**

```kotlin
package com.tonylocuras.todook
import android.content.*

class BootReceiver : BroadcastReceiver() {
  override fun onReceive(c: Context, i: Intent) {
    AlarmStore.all(c).forEach { Alarms.set(c, it.getString("expeditionId"), maxOf(it.getLong("fireAtMillis"), System.currentTimeMillis() + 5000)) }
  }
}
```

Si el límite ya pasó durante el apagado, suena 5 s después del arranque (ante la duda, suena).

- [ ] **Step 7: `AlarmChannel.kt` + registro en `MainActivity.kt`**

```kotlin
package com.tonylocuras.todook
import android.app.*
import android.content.*
import android.net.Uri
import android.os.*
import android.provider.Settings
import io.flutter.plugin.common.*
import org.json.JSONObject

class AlarmChannel(private val c: Context) : MethodChannel.MethodCallHandler {
  override fun onMethodCall(call: MethodCall, r: MethodChannel.Result) {
    when (call.method) {
      "schedule" -> { val m = call.arguments as Map<*, *>; val id = m["expeditionId"] as String
        AlarmStore.save(c, id, JSONObject(m)); Alarms.set(c, id, (m["fireAtMillis"] as Number).toLong()); r.success(null) }
      "cancel" -> { Alarms.cancel(c, call.arguments as String); r.success(null) }
      "permissions" -> r.success(mapOf("exactAlarm" to canExact(), "fullScreen" to canFull(), "notifications" to notifOk(), "batteryExempt" to batteryOk()))
      "openSetting" -> { open(call.arguments as String); r.success(null) }
      "testAlarm" -> { val spec = JSONObject(mapOf("expeditionId" to "__test__", "explorerName" to "PRUEBA", "name" to "Prueba de alarma", "zone" to "-", "fireAtMillis" to System.currentTimeMillis() + 60000))
        AlarmStore.save(c, "__test__", spec); Alarms.set(c, "__test__", System.currentTimeMillis() + 60000); r.success(null) }
      "pendingAcks" -> r.success(AlarmStore.acks(c).filter { it != "__test__" })
      "clearAck" -> { AlarmStore.clearAck(c, call.arguments as String); r.success(null) }
      else -> r.notImplemented()
    }
  }
  private fun canExact() = Build.VERSION.SDK_INT < 31 || (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
  private fun canFull() = Build.VERSION.SDK_INT < 34 || (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
  private fun notifOk() = (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
  private fun batteryOk() = (c.getSystemService(Context.POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(c.packageName)
  private fun open(which: String) {
    val i = when (which) {
      "exactAlarm" -> Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${c.packageName}"))
      "fullScreen" -> Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${c.packageName}"))
      "batteryExempt" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${c.packageName}"))
      else -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, c.packageName)
    }
    c.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  }
}
```

`MainActivity.kt`: sobreescribir `configureFlutterEngine` con `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todook/alarm").setMethodCallHandler(AlarmChannel(applicationContext))`.

- [ ] **Step 8: `lib/alarm/android_alarm_scheduler.dart`**

```dart
import 'package:flutter/services.dart';
import 'alarm_scheduler.dart';

class AndroidAlarmScheduler implements AlarmScheduler {
  static const _ch = MethodChannel('todook/alarm');
  Future<Map<String, bool>> permissions() async => Map<String, bool>.from(await _ch.invokeMethod('permissions'));
  @override Future<bool> permissionsOk() async => (await permissions()).values.every((v) => v);
  @override Future<void> schedule(AlarmSpec s) => _ch.invokeMethod('schedule', s.toMap());
  @override Future<void> cancel(String id) => _ch.invokeMethod('cancel', id);
  Future<void> openSetting(String which) => _ch.invokeMethod('openSetting', which);
  Future<void> testAlarm() => _ch.invokeMethod('testAlarm');
  Future<List<String>> pendingAcks() async => List<String>.from(await _ch.invokeMethod('pendingAcks'));
  Future<void> clearAck(String id) => _ch.invokeMethod('clearAck', id);
}
```

- [ ] **Step 9: Verify** `flutter analyze` y `flutter build apk --debug` sin errores (en la máquina de Tony). **Los tests reales de sonido son del checklist (Task 14).**
- [ ] **Step 10: Commit** `feat: alarma nativa Android con reintento y arranque`.

---

### Task 8: Repositorios de Firebase (auth, vinculación, expediciones, armado)

**Files:**
- Create: `lib/data/{auth,pairing,expedition,arming}_repository.dart`

**Interfaces:**
- Consumes: `generatePairingCode`, `normalizePairingCode` (Task 3), `Expedition` (Task 5), `nextDeadline`, `effectiveCheckinTime` (Task 2), `ArmReporter` (Task 6).
- Produces:
  - `AuthRepository`: `Stream<User?> authState()`, `Future<void> signInWithGoogle()`, `Future<void> signOut()`, `Future<String?> role()`, `Future<void> setRole(String role, String displayName)`.
  - `PairingRepository`: `Future<String> createCode()`, `Future<void> redeem(String raw)`, `Stream<List<Pairing>> contacts()`, `Future<void> unpair(String contactUid)`.
  - `ExpeditionRepository`: `Future<String> create(...)`, `Stream<Expedition?> activeForExplorer()`, `Stream<List<Expedition>> watchForContact()`, `void checkIn(Expedition e, {double? lat, double? lng, required int battery})`, `void extend(Expedition e, DateTime newDeadline)`, `Future<void> start(String id)`, `Future<void> finish(String id)`, `Future<void> markAlarm(String id)`.
  - `ArmingRepository implements ArmReporter` + `Stream<Map<String, ContactArm>> watchContacts(String expeditionId)`, `Future<void> ack(String expeditionId)`.

**Acceptance Criteria:**
- `redeem` escribe el canje y el vínculo en un único batch y falla con mensaje claro si el código es inválido.
- `checkIn` escribe el check-in y actualiza los `last*` y el límite en un único batch y **no espera** a la red (devuelve de inmediato; la cola offline de Firestore lo reintenta).
- `finish` fija `status: finished` y `expireAt = ahora + 30 días`.
- Las reglas de Task 4 aceptan todas las escrituras de estos métodos (se comprueba en el emulador en Task 14).

- [ ] **Step 1:** Implementar `AuthRepository` con `GoogleSignIn().signIn()` → `FirebaseAuth.signInWithCredential`; `role()` lee `users/{uid}.role`.
- [ ] **Step 2:** `PairingRepository.createCode()` genera código, escribe `pairingCodes/{code}` con `explorerUid`, `used:false`, `expiresAt: now+10min`, y lo devuelve. `redeem(raw)`:

```dart
Future<void> redeem(String raw) async {
  final code = normalizePairingCode(raw);
  if (code == null) throw const FormatException('Código no válido');
  final uid = _auth.currentUser!.uid;
  final snap = await _db.doc('pairingCodes/$code').get();
  if (!snap.exists) throw StateError('Código inexistente');
  final data = snap.data()!;
  if (data['used'] == true || (data['expiresAt'] as Timestamp).toDate().isBefore(DateTime.now())) throw StateError('Código caducado o usado');
  final explorerUid = data['explorerUid'] as String;
  final b = _db.batch();
  b.update(_db.doc('pairingCodes/$code'), {'used': true, 'redeemedBy': uid});
  b.set(_db.doc('pairings/${explorerUid}_$uid'), {'explorerUid': explorerUid, 'contactUid': uid, 'code': code, 'contactName': _auth.currentUser!.displayName ?? ''});
  await b.commit();
}
```

(Las reglas de Task 4 exigen que `pairings` tenga `code`, `explorerUid` y `contactUid`; `contactName` es un campo extra permitido.)

- [ ] **Step 3:** `unpair(contactUid)` borra `pairings/{uid}_{contactUid}` y, en batch, quita el `contactUid` de `contactUids` de las expediciones `planned`/`active` de Tony.
- [ ] **Step 4:** `ExpeditionRepository.checkIn`:

```dart
void checkIn(Expedition e, {double? lat, double? lng, required int battery}) {
  final now = DateTime.now().toUtc();
  final next = nextDeadline(currentDeadline: e.deadlineAt, effectiveCheckin: now, interval: e.checkinInterval);
  final ref = _db.doc('expeditions/${e.id}');
  final b = _db.batch();
  b.set(ref.collection('checkins').doc(), {'at': Timestamp.fromDate(now), 'serverAt': FieldValue.serverTimestamp(), 'lat': lat, 'lng': lng, 'battery': battery});
  b.update(ref, {'deadlineAt': Timestamp.fromDate(next), 'lastCheckinAt': Timestamp.fromDate(now), 'lastLat': lat, 'lastLng': lng, 'lastBattery': battery});
  b.commit(); // sin await: la cola offline de Firestore lo reintenta
}
```

La hora efectiva servidor la aplica la regla (`deadlineAt <= request.time + intervalo`): si el reloj de Tony iba adelantado, el batch se rechaza al sincronizar y la UI lo muestra como error; `effectiveCheckinTime` se usa en la pantalla para avisar de un reloj desfasado comparando con `serverAt` de los check-ins ya sincronizados.

- [ ] **Step 5:** `start(id)` → `status: active`, `startAt: ahora`. `finish(id)` → `status: finished`, `expireAt: Timestamp(ahora+30d)`. `markAlarm(id)` → `status: alarm` (solo lo llama el contacto cuando `isOverdue`). `extend(e, newDeadline)` actualiza `deadlineAt` (la regla acota).
- [ ] **Step 6:** `ArmingRepository`: `reportArmed(id, ms)` → `set(expeditions/{id}/contacts/{uid}, {armedAt: serverTimestamp, armedDeadlineMs: ms})`; `clearArmed` → `set` con `armedAt: null`; `ack(id)` → `set(..., {ackAt: serverTimestamp}, merge)`.
- [ ] **Step 7: Verify** `flutter analyze`. **Step 8: Commit** `feat: repositorios Firebase`.

---

### Task 9: Servicio en primer plano del contacto

**Files:**
- Create: `lib/service/watch_service.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `ExpeditionRepository.watchForContact()`, `AlarmOrchestrator`, `AndroidAlarmScheduler.pendingAcks/clearAck`, `ArmingRepository.ack`.
- Produces: `class WatchService { static Future<void> startIfNeeded(); static Future<void> stop(); }` y un `TaskHandler` que al iniciar: (a) suscribe `watchForContact()` y llama `orchestrator.apply(e)` para cada cambio; (b) si `e.status == active && e.isOverdue(now)` llama `markAlarm(e.id)`; (c) sincroniza acuses pendientes.

**Acceptance Criteria:**
- Mientras haya una expedición `planned`/`active` el contacto ve una notificación persistente "TODO OK vigilando".
- Un check-in de Tony reprograma la alarma local del contacto con la app en segundo plano.
- Al terminar todas las expediciones, el servicio se detiene.
- Los acuses guardados en nativo se suben a Firestore cuando hay red.

- [ ] **Step 1:** Configurar `FlutterForegroundTask.init` (`serviceTypes: [ForegroundServiceTypes.dataSync]`, canal `todook_watch`, intervalo de evento 60 s) y `startService(notificationTitle: 'TODO OK vigilando', ...)`.
- [ ] **Step 2:** En el `TaskHandler.onStart`, inicializar Firebase (`Firebase.initializeApp`) y suscribirse al stream; cada 60 s (`onRepeatEvent`) repetir las comprobaciones (b) y (c) para cubrir el caso de que el límite venza sin eventos nuevos.
- [ ] **Step 3:** `startIfNeeded()` se llama desde la pantalla del contacto al detectar una expedición `planned`/`active` y al arrancar la app; `stop()` cuando no queda ninguna.
- [ ] **Step 4: Verify** `flutter analyze`; prueba manual descrita en `docs/DEVICE_CHECKLIST.md` (Task 14, ítem "check-in con app cerrada").
- [ ] **Step 5: Commit** `feat: servicio de vigilancia del contacto`.

---

### Task 10: Pantallas de acceso, rol y vinculación

**Files:**
- Create: `lib/ui/{login,role,pairing}_screen.dart`, `lib/ui/limits_banner.dart`
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `PairingRepository` (Task 8).
- Produces: `LimitsBanner` (widget con el texto fijo de límites); flujo `login → role → (explorer|contact)`.

**Acceptance Criteria:**
- Google Sign-In funciona y la sesión sobrevive a reiniciar la app.
- Tony ve su código y su QR con cuenta atrás de 10 min y regenera uno nuevo con un toque; el contacto introduce o escanea el código.
- Un código inválido, caducado o usado muestra el motivo.
- `LimitsBanner` aparece en el primer arranque y en cada expedición con el texto exacto:

  `La alarma depende de la hora límite y del móvil del contacto. Si ese móvil está apagado, sin batería o con la app cerrada a la fuerza, no suena. Sin señal no llega tu posición. En iPhone la alarma puede quedar silenciada.`

- [ ] **Step 1:** `LoginScreen` con botón "Entrar con Google"; `RoleScreen` con dos botones (Soy Tony / Soy contacto) que llama `setRole`.
- [ ] **Step 2:** `PairingScreen` (explorador): `createCode()`, `QrImageView(data: code)`, temporizador. (contacto): `TextField` + `MobileScanner` que llaman `redeem`.
- [ ] **Step 3:** Widget test de `LimitsBanner` (el texto exacto) en `test/ui/limits_banner_test.dart`; `flutter test` → PASS.
- [ ] **Step 4: Commit** `feat: login, rol y vinculación`.

---

### Task 11: Tony — crear expedición, armado visible y botón TODO OK

**Files:**
- Create: `lib/ui/{explorer_home,create_expedition}_screen.dart`, `lib/ui/todo_ok_button.dart`
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `ExpeditionRepository`, `ArmingRepository.watchContacts`, `PairingRepository.contacts()`, `geolocator`, `battery_plus`.
- Produces: pantalla de inicio de Tony con la expedición, el estado de armado por contacto y el botón TODO OK.

**Acceptance Criteria:**
- Crear expedición: nombre, zona, salida, hora límite (> ahora), intervalo opcional (15–1440 min) y selección de contactos. Se crea como `planned`.
- Tony ve "Contacto X armado ✓ / sin confirmar ✗" en tiempo real. "Iniciar" solo se habilita con ≥1 contacto armado **para el límite vigente** (`armedDeadlineMs == deadlineAt.millisecondsSinceEpoch`); si no, ofrece "Salir sin alarma activa" con diálogo de confirmación explícito. Aviso (no bloqueo) si hay un solo contacto.
- Aviso al crear si la hora automática del móvil está desactivada (comparar con la hora de servidor devuelta por una escritura de prueba en `users/{uid}`, desfase > 2 min).
- Botón TODO OK grande, un toque, sin esperar a la red; muestra "pendiente de enviar" mientras `hasPendingWrites` y "enviado" después.
- Botón "Finalizar" con confirmación; pone `finished`.
- Con intervalo configurado se muestra la próxima hora límite tras cada check-in.
- `LimitsBanner` visible en la pantalla de la expedición.

- [ ] **Step 1:** `CreateExpeditionScreen` con validación (hora límite > ahora, intervalo en rango) y creación vía `ExpeditionRepository.create`.
- [ ] **Step 2:** `ExplorerHome` escucha `activeForExplorer()` (stream con `includeMetadataChanges: true` para `hasPendingWrites`) y `ArmingRepository.watchContacts`.
- [ ] **Step 3:** `TodoOkButton`: al pulsar, obtiene `Geolocator.getLastKnownPosition()` (sin esperar al GPS) y `Battery().batteryLevel`, y llama a `checkIn(...)` sin `await`.
- [ ] **Step 4:** Test de widget del gate de inicio: con contactos sin armar el botón "Iniciar" está deshabilitado y aparece "Salir sin alarma activa" (`test/ui/start_gate_test.dart`, con repositorios falsos) → PASS.
- [ ] **Step 5: Commit** `feat: pantallas de Tony`.

---

### Task 12: Contacto — estado, cuenta atrás, permisos y "Probar alarma"

**Files:**
- Create: `lib/ui/{contact_home,permissions}_screen.dart`
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `ExpeditionRepository.watchForContact`, `AndroidAlarmScheduler.permissions/openSetting/testAlarm`, `WatchService`.
- Produces: pantalla del contacto con estado derivado: `OK` (último check-in dentro del intervalo), `pendiente` (sin check-in reciente pero antes del límite), `ALARMA` (status `alarm`), `ALARMA con check-in tardío` (naranja: status `alarm` y `lastCheckinAt` posterior a la hora del disparo).

**Acceptance Criteria:**
- Cuenta atrás hasta `deadlineAt`, última posición con hora y "hace X", zona y nombre.
- Pantalla de permisos guiados con estado verde/rojo por permiso (alarmas exactas, pantalla completa, notificaciones, exención de batería) y botón que abre el ajuste correspondiente; mientras falte alguno aparece "Alarma NO armada" y el orquestador no programa.
- Botón "Probar alarma": suena en 60 s con la pantalla bloqueada y la app cerrada.
- Un check-in tardío con la alarma ya disparada **no la apaga**: se muestra el aviso naranja "X hizo check-in a las HH:MM (llegó con retraso)" y se cierra solo con "Recibida".
- Se sincronizan los acuses pendientes y la pantalla muestra "Recibida".

- [ ] **Step 1:** Función pura `ContactStatus contactStatus(Expedition e, DateTime now)` en `lib/domain/contact_status.dart` con tests en `test/domain/contact_status_test.dart` cubriendo los cuatro casos (TDD: test primero, `flutter test` FAIL → implementar → PASS).

```dart
enum ContactStatus { ok, pending, alarm, alarmLateCheckin }
ContactStatus contactStatus(Expedition e, DateTime now) {
  if (e.status == ExpeditionStatus.alarm) {
    final fired = e.deadlineAt; // el límite no se acorta; el disparo ocurre en/tras deadlineAt original
    return (e.lastCheckinAt != null && e.lastCheckinAt!.isAfter(fired)) ? ContactStatus.alarmLateCheckin : ContactStatus.alarm;
  }
  final iv = e.checkinInterval;
  if (e.lastCheckinAt != null && iv != null && now.difference(e.lastCheckinAt!) <= iv) return ContactStatus.ok;
  return ContactStatus.pending;
}
```

Nota: si tras un check-in tardío el límite se amplió, `deadlineAt` ya es posterior al disparo; para distinguir correctamente se guarda `alarmFiredAt` (`FieldValue.serverTimestamp()`) en `markAlarm` junto a `status: alarm` y se compara `lastCheckinAt > alarmFiredAt`. Añadir `alarmFiredAt` al modelo (`Expedition.alarmFiredAt`, `toMap`/`fromMap`) y a la regla del contacto (`hasOnly(['status','alarmFiredAt'])`), con su test en Task 4.

- [ ] **Step 2:** `PermissionsScreen` y `ContactHome`.
- [ ] **Step 3: Commit** `feat: pantallas del contacto y permisos`.

---

### Task 13: iPhone — notificación local degradada

**Files:**
- Create: `lib/alarm/ios_alarm_scheduler.dart`
- Modify: `lib/main.dart`, `pubspec.yaml` (`flutter_local_notifications`)

**Interfaces:**
- Consumes: `AlarmScheduler`, `AlarmSpec`.
- Produces: `IosAlarmScheduler implements AlarmScheduler` con notificación local programada a `fireAt` (`interruptionLevel: timeSensitive` si el entitlement existe), y selección de implementación por plataforma (`Platform.isIOS`).

**Acceptance Criteria:**
- En iOS se programa una notificación local a la hora límite y se cancela con `finished`.
- En la pantalla del contacto iOS aparece el aviso permanente: "En iPhone la alarma puede quedar silenciada. La alarma fiable es en Android."
- Si hay más de 64 notificaciones pendientes se prioriza la más próxima (límite de iOS) — con un test de unidad de la selección.
- Queda documentado en `docs/SETUP.md` que instalar en iPhone requiere Apple Developer y un Mac, fuera de la gratuidad.

- [ ] **Step 1:** Test de `IosAlarmScheduler` con un plugin falso (programa a `fireAt`, cancela por id). **Step 2:** implementar. **Step 3:** `flutter test` → PASS. **Step 4: Commit** `feat: notificación local en iOS (degradada)`.

---

### Task 14: Checklist en móvil real, emulador y cierre de la fase

**Files:**
- Create: `docs/DEVICE_CHECKLIST.md`
- Modify: `docs/SETUP.md`

**Acceptance Criteria:**
- Todo el checklist pasa en el **móvil Android real de un contacto** antes de la primera expedición.
- `npm test` de reglas y `flutter test` pasan; `flutter analyze` limpio.

- [ ] **Step 1: `docs/DEVICE_CHECKLIST.md`**, cada ítem con resultado "OK / FALLA / fabricante y modelo":
  1. Permisos guiados: los cuatro en verde; sin uno de ellos aparece "Alarma NO armada".
  2. "Probar alarma" con pantalla bloqueada, app cerrada y móvil en silencio: suena a pantalla completa y vibra.
  3. Alarma real: expedición con límite a +3 min; sin check-in suena a la hora; pulsar "Recibida" la detiene; sin pulsar, vuelve a sonar a los 5 min.
  4. Modo No Molestar activado: suena.
  5. App del contacto forzada a cerrar tras armar: anotar el resultado (esperado: la alarma NO suena; la verificación de armado lo detecta al abrir). Documentar.
  6. Reinicio del móvil con una alarma armada: vuelve a programarse y suena.
  7. Check-in de Tony con la app del contacto cerrada y el servicio activo: la alarma se reprograma a la nueva hora (comprobar que no suena a la antigua).
  8. Tony sin datos: TODO OK queda "pendiente de enviar"; al volver la señal sube y se actualiza al contacto.
  9. Check-in tardío tras el disparo: aviso naranja, no se apaga sola.
  10. Finalizar cancela la alarma en todos los contactos.
  11. Fabricante concreto: seguir `dontkillmyapp.com` y repetir 3 con el móvil bloqueado 1 h.
  12. iPhone (si aplica): llega la notificación local; anotar si se silencia.
- [ ] **Step 2:** Ejecutar `cd firebase && npm test` y `flutter test && flutter analyze`.
- [ ] **Step 3: Commit** `docs: checklist de validación en móvil real`.

---

## Cobertura de la spec (Self-Review)

| Requisito de la spec | Task |
|---|---|
| Vincular con código/QR, 10 caracteres, un solo uso, caducidad, canje atómico, revocación | 3, 4, 8, 10 |
| Crear expedición, sincronizar al contacto | 5, 8, 11 |
| TODO OK con cola offline | 8, 11 |
| Semántica (TODO OK no desarma; solo Finalizar; check-in amplía con `max`) | 2, 6, 8 |
| Hora efectiva UTC y aviso de hora automática | 2, 8, 11 |
| Falsa alarma vs perdida; check-in tardío no apaga | 6, 12 |
| Armado visible y obligatorio antes de salir; ≥1 contacto armado, mínimo 2 recomendado | 8, 11 |
| Acuse con reintento a 5 min | 7, 9, 12 |
| Reprogramación tras reinicio (`BOOT_COMPLETED`) | 7 |
| `setAlarmClock`, canal de alarma, pantalla completa, permisos guiados, "Probar alarma" | 7, 12 |
| Reglas por campo, TTL de retención, tests de emulador | 1, 4, 8 |
| Línea de límites en la app | 10, 11 |
| iPhone degradado + aviso de instalación | 13, 1 |
| Repo privado, claves restringidas, Spark | 1 |
| Validación en móvil físico | 14 |
| **Hueco encontrado en el plan:** servicio en primer plano del contacto | 9 |
| **Precisión:** estado `planned`, `alarmFiredAt`, tope de extensión | cabecera, 4, 5, 12 |

**Recortes deliberados:** ninguno. La fase 2 (GPS en segundo plano, mapas, GPX) y la fase 3 (Cloud Function, escalado) quedan fuera por decisión previa de Tony.

**Placeholders:** ninguno; los pasos de UI de las Tasks 8–13 dan interfaz, comportamiento y tests exactos, y el código largo de pantallas se escribe durante la ejecución siguiendo esas interfaces.

**Consistencia de tipos:** `AlarmSpec`, `ArmReporter`, `AlarmOrchestrator`, `Expedition` y los métodos de los repositorios usan los mismos nombres en todas las tasks. `alarmFiredAt` está en el modelo (Task 5), en la regla del contacto (Task 4) y se usa en `markAlarm` (Task 8) y `contactStatus` (Task 12). Al ejecutar la Task 4 se añade además un test: el contacto puede escribir `status` + `alarmFiredAt` tras vencer el límite y ningún otro campo. En la Task 12, `contactStatus` compara `lastCheckinAt > alarmFiredAt`.
