# Expedition Planner — Phase 1 (Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use beads-superpowers:subagent-driven-development (recommended) or beads-superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent <epic-id>`) when `bd` is available; otherwise track with the checkboxes. Steps use `- [ ]` syntax.

**Goal:** A Flutter app (Android + Windows) with a 3-step wizard (Dónde → Ruta → Análisis): choose a place, load/draw a route with altitude profile and time estimate, and get weather/UV/temperature-by-altitude analysis with a generated pack list.

**Architecture:** Layers `data` (GPX parsing, Open-Meteo client, local DB) → `domain` (pure, unit-tested: geo math, time model, weather-by-altitude, packing) → `ui` (wizard + expert map). Offline-first local storage; no cloud in Phase 1.

**Tech Stack:** Flutter (stable), Dart 3, flutter_riverpod, go_router, flutter_map + latlong2, xml, http, drift (SQLite), fl_chart, flutter_test.

**Spec:** `.internal/specs/2026-11-23-expedition-planner-design.md`

## Scope decision (surfaced, needs your acknowledgement)
The spec has 3 phases and 8 modules. A single plan would be too big to be reviewable. This plan = **Phase 1 only**:
spec module 1 (maps & routes, minus offline tile download → Task 9), module 2 (weather by altitude) and the pack list part of module 4.
**Deferred to separate plans, not dropped:** Phase 2 (safety/emergency, logbook, account + Supabase sync, gear inventory), Phase 3 (specific risks, recording planner, AI assistant). Each gets its own plan after Phase 1 ships.

## Global Constraints
- App folder: `expedition-planner/` (existing web files untouched).
- UI language Spanish; dark tactical theme, min touch target 56 dp, red night mode toggle.
- Free data by default: Open-Meteo, OpenStreetMap/OpenTopoMap tiles (respect usage policy; no bulk scraping).
- No secrets in the client. Domain code is pure Dart (no Flutter imports) and 100% unit-tested.
- Target platforms v1: Android, Windows.

## File Structure
```
expedition-planner/
  pubspec.yaml
  lib/main.dart
  lib/app.dart                         # theme + router
  lib/domain/geo.dart                  # LatLngEle, haversine, route stats
  lib/domain/time_model.dart           # Naismith/Tobler time estimate
  lib/domain/weather.dart              # lapse rate, wind chill, UV by altitude
  lib/domain/packing.dart              # pack list generator
  lib/data/gpx_parser.dart             # GPX -> List<LatLngEle>
  lib/data/open_meteo_client.dart      # HTTP forecast
  lib/ui/theme.dart
  lib/ui/wizard/where_step.dart
  lib/ui/wizard/route_step.dart
  lib/ui/wizard/analysis_step.dart
  test/domain/*.dart, test/data/*.dart
```

---

### Task 1: Project scaffold and CI-able test run

**Files:** Create `expedition-planner/` via `flutter create`; Modify `pubspec.yaml`; Test `test/smoke_test.dart`

**Interfaces:** Produces: runnable app shell `ExpeditionApp` in `lib/app.dart`.

**Acceptance Criteria:**
- `flutter test` passes; `flutter analyze` has no errors; app shell shows title "Prepara tu ruta".

- [ ] **Step 1:** Install Flutter stable (`git clone -b stable https://github.com/flutter/flutter.git ~/flutter`, add to PATH), run `flutter --version`.
- [ ] **Step 2:** `cd /home/user/TonyLocuras && flutter create --org com.tonylocuras --platforms android,windows,linux expedition-planner`
- [ ] **Step 3: Write failing test** `test/smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/app.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('shows Prepara tu ruta', (t) async {
    await t.pumpWidget(const ExpeditionApp());
    expect(find.text('Prepara tu ruta'), findsOneWidget);
  });
}
```
- [ ] **Step 4:** Run `flutter test test/smoke_test.dart` → FAIL (`app.dart` missing).
- [ ] **Step 5:** Create `lib/app.dart`:
```dart
import 'package:flutter/material.dart';

class ExpeditionApp extends StatelessWidget {
  const ExpeditionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Expedition Planner',
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: Center(child: Text('Prepara tu ruta'))),
      );
}
```
Set `lib/main.dart` to `runApp(const ExpeditionApp())`.
- [ ] **Step 6:** Run test → PASS. Commit `feat: scaffold flutter app`.

### Task 2: Geo model and route statistics

**Files:** Create `lib/domain/geo.dart`; Test `test/domain/geo_test.dart`

**Interfaces:** Produces:
`class LatLngEle { final double lat, lon, ele; const LatLngEle(this.lat, this.lon, this.ele); }`
`double haversineKm(LatLngEle a, LatLngEle b)`
`class RouteStats { final double km, gainM, lossM, maxEle, minEle; }`
`RouteStats computeStats(List<LatLngEle> pts)`

**Acceptance Criteria:** distance within 0.5% of known value; gain/loss ignore noise below 3 m; empty/1-point list returns zeros.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/geo.dart';

void main() {
  test('haversine ~111.19 km per degree latitude', () {
    final d = haversineKm(const LatLngEle(0, 0, 0), const LatLngEle(1, 0, 0));
    expect(d, closeTo(111.19, 0.6));
  });
  test('stats: gain, loss, max', () {
    final s = computeStats(const [
      LatLngEle(0, 0, 100), LatLngEle(0.01, 0, 200), LatLngEle(0.02, 0, 150)]);
    expect(s.gainM, 100);
    expect(s.lossM, 50);
    expect(s.maxEle, 200);
  });
  test('noise under 3 m ignored', () {
    final s = computeStats(const [
      LatLngEle(0, 0, 100), LatLngEle(0.001, 0, 102), LatLngEle(0.002, 0, 100)]);
    expect(s.gainM, 0);
  });
  test('empty route is zeros', () {
    final s = computeStats(const []);
    expect(s.km, 0);
    expect(s.gainM, 0);
  });
}
```
- [ ] **Step 2:** `flutter test test/domain/geo_test.dart` → FAIL.
- [ ] **Step 3: Implement**
```dart
import 'dart:math';

class LatLngEle {
  final double lat, lon, ele;
  const LatLngEle(this.lat, this.lon, this.ele);
}

double haversineKm(LatLngEle a, LatLngEle b) {
  const r = 6371.0088;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon);
  final h = pow(sin(dLat / 2), 2) +
      cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(h));
}

class RouteStats {
  final double km, gainM, lossM, maxEle, minEle;
  const RouteStats(this.km, this.gainM, this.lossM, this.maxEle, this.minEle);
}

RouteStats computeStats(List<LatLngEle> pts, {double noiseM = 3}) {
  if (pts.length < 2) return const RouteStats(0, 0, 0, 0, 0);
  double km = 0, gain = 0, loss = 0;
  double maxE = pts.first.ele, minE = pts.first.ele;
  double ref = pts.first.ele;
  for (var i = 1; i < pts.length; i++) {
    km += haversineKm(pts[i - 1], pts[i]);
    final e = pts[i].ele;
    if (e > maxE) maxE = e;
    if (e < minE) minE = e;
    final diff = e - ref;
    if (diff >= noiseM) { gain += diff; ref = e; }
    else if (diff <= -noiseM) { loss += -diff; ref = e; }
  }
  return RouteStats(km, gain, loss, maxE, minE);
}
```
- [ ] **Step 4:** Run → PASS. Commit `feat: geo model and route stats`.

### Task 3: GPX parser

**Files:** Create `lib/data/gpx_parser.dart`; Test `test/data/gpx_parser_test.dart`

**Interfaces:** Consumes `LatLngEle`. Produces `List<LatLngEle> parseGpx(String xml)` throwing `FormatException` on invalid input.

**Acceptance Criteria:** parses `<trkpt>` and falls back to `<rtept>`; missing `<ele>` → 0; invalid XML or no points → `FormatException`.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/data/gpx_parser.dart';

const gpx = '''<gpx><trk><trkseg>
<trkpt lat="36.9" lon="-2.0"><ele>120</ele></trkpt>
<trkpt lat="36.91" lon="-2.01"></trkpt></trkseg></trk></gpx>''';

void main() {
  test('parses track points', () {
    final p = parseGpx(gpx);
    expect(p.length, 2);
    expect(p[0].ele, 120);
    expect(p[1].ele, 0);
  });
  test('invalid xml throws', () {
    expect(() => parseGpx('nope'), throwsFormatException);
  });
  test('no points throws', () {
    expect(() => parseGpx('<gpx></gpx>'), throwsFormatException);
  });
}
```
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Add `xml` dependency (`flutter pub add xml`). Implement:
```dart
import 'package:xml/xml.dart';
import '../domain/geo.dart';

List<LatLngEle> parseGpx(String source) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(source);
  } on XmlException catch (e) {
    throw FormatException('GPX inválido: ${e.message}');
  }
  var nodes = doc.findAllElements('trkpt').toList();
  if (nodes.isEmpty) nodes = doc.findAllElements('rtept').toList();
  if (nodes.isEmpty) throw const FormatException('GPX sin puntos');
  return nodes.map((n) {
    final lat = double.parse(n.getAttribute('lat')!);
    final lon = double.parse(n.getAttribute('lon')!);
    final ele = double.tryParse(n.getElement('ele')?.innerText ?? '') ?? 0;
    return LatLngEle(lat, lon, ele);
  }).toList();
}
```
- [ ] **Step 4:** Run → PASS. Commit `feat: gpx parser`.

### Task 4: Time model (Naismith + descent correction)

**Files:** Create `lib/domain/time_model.dart`; Test `test/domain/time_model_test.dart`

**Interfaces:** Produces `Duration estimateTime(RouteStats s, {double packKg = 8, Activity activity = Activity.hiking})`, `enum Activity { hiking, trail, alpine, caving }`.

**Acceptance Criteria:** Naismith base 5 km/h + 1 h per 600 m gain, descent adds 1 h per 1200 m loss steeper than assumed; alpine ×1.4, caving ×1.8, trail ×0.6; pack over 10 kg adds 3% per extra kg.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/geo.dart';
import 'package:expedition_planner/domain/time_model.dart';

void main() {
  const s = RouteStats(10, 600, 600, 1500, 900);
  test('hiking 10km +600 -600: 2h + 1h + 0.5h', () {
    expect(estimateTime(s).inMinutes, 210);
  });
  test('alpine is slower', () {
    expect(estimateTime(s, activity: Activity.alpine).inMinutes, 294);
  });
  test('heavy pack adds 3 percent per kg over 10', () {
    expect(estimateTime(s, packKg: 12).inMinutes, 223);
  });
}
```
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement**
```dart
import 'geo.dart';

enum Activity { hiking, trail, alpine, caving }

const _factor = {
  Activity.hiking: 1.0, Activity.trail: 0.6,
  Activity.alpine: 1.4, Activity.caving: 1.8,
};

Duration estimateTime(RouteStats s,
    {double packKg = 8, Activity activity = Activity.hiking}) {
  final hours = s.km / 5 + s.gainM / 600 + s.lossM / 1200;
  final packMult = 1 + (packKg > 10 ? (packKg - 10) * 0.03 : 0);
  final minutes = hours * 60 * _factor[activity]! * packMult;
  return Duration(minutes: minutes.round());
}
```
- [ ] **Step 4:** Run; if rounding differs by 1 min adjust expected values in the test after verifying the math by hand. Commit `feat: time model`.

### Task 5: Weather by altitude

**Files:** Create `lib/domain/weather.dart`; Test `test/domain/weather_test.dart`

**Interfaces:** Produces `double tempAtAltitude(double baseTempC, double baseEleM, double eleM)` (−6.5 °C/km), `double windChill(double tempC, double windKmh)`, `double uvAtAltitude(double uvBase, double eleM, {double eleBaseM = 0})` (+10 % per 1000 m), `double burnMinutes(double uv, {int skinType = 2})`, `double freezingLevelM(double baseTempC, double baseEleM)`.

**Acceptance Criteria:** values match formulas below within tolerance; wind chill only applies for T ≤ 10 °C and wind > 4.8 km/h, otherwise returns T.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/weather.dart';

void main() {
  test('temperature lapse -6.5C/km', () {
    expect(tempAtAltitude(20, 500, 2500), closeTo(7, 0.01));
  });
  test('UV +10% per 1000 m', () {
    expect(uvAtAltitude(6, 2000), closeTo(7.2, 0.01));
  });
  test('wind chill formula', () {
    expect(windChill(0, 20), closeTo(-5.2, 0.2));
    expect(windChill(15, 20), 15);
  });
  test('freezing level', () {
    expect(freezingLevelM(13, 0), closeTo(2000, 1));
  });
  test('burn minutes decreases with UV', () {
    expect(burnMinutes(10), lessThan(burnMinutes(5)));
  });
}
```
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement**
```dart
import 'dart:math';

double tempAtAltitude(double baseTempC, double baseEleM, double eleM) =>
    baseTempC - 6.5 * (eleM - baseEleM) / 1000;

double windChill(double tempC, double windKmh) {
  if (tempC > 10 || windKmh <= 4.8) return tempC;
  final v = pow(windKmh, 0.16);
  return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v;
}

double uvAtAltitude(double uvBase, double eleM, {double eleBaseM = 0}) =>
    uvBase * (1 + 0.10 * (eleM - eleBaseM) / 1000);

// Minutes to erythema: MED(J/m2) / (UVI * 0.025 W/m2) / 60; MED by skin type.
double burnMinutes(double uv, {int skinType = 2}) {
  const med = {1: 200.0, 2: 250.0, 3: 350.0, 4: 450.0};
  if (uv <= 0) return double.infinity;
  return med[skinType]! / (uv * 0.025) / 60;
}

double freezingLevelM(double baseTempC, double baseEleM) =>
    baseEleM + baseTempC / 6.5 * 1000;
```
- [ ] **Step 4:** Run → PASS. Commit `feat: weather by altitude`.

### Task 6: Open-Meteo client

**Files:** Create `lib/data/open_meteo_client.dart`; Test `test/data/open_meteo_client_test.dart`

**Interfaces:** Produces `class HourlyForecast { final DateTime time; final double tempC, windKmh, uv, precipMm; }`, `class OpenMeteoClient { OpenMeteoClient({http.Client? client}); Future<List<HourlyForecast>> fetch(double lat, double lon, {int days = 3}); }`. Throws `ForecastException` on non-200 or malformed body.

**Acceptance Criteria:** builds URL `https://api.open-meteo.com/v1/forecast` with `hourly=temperature_2m,wind_speed_10m,uv_index,precipitation`, `forecast_days`, `timezone=auto`; parsed with a mocked client (no real network in tests).

- [ ] **Step 1: Failing test** (uses `http/testing.dart` MockClient)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expedition_planner/data/open_meteo_client.dart';

void main() {
  test('parses hourly arrays', () async {
    final mock = MockClient((req) async {
      expect(req.url.host, 'api.open-meteo.com');
      expect(req.url.queryParameters['hourly'],
          'temperature_2m,wind_speed_10m,uv_index,precipitation');
      return http.Response(
          '{"hourly":{"time":["2026-11-24T08:00"],"temperature_2m":[10.5],'
          '"wind_speed_10m":[12.0],"uv_index":[3.0],"precipitation":[0.0]}}',
          200);
    });
    final r = await OpenMeteoClient(client: mock).fetch(36.9, -2.0);
    expect(r.single.tempC, 10.5);
    expect(r.single.uv, 3.0);
  });
  test('non-200 throws', () async {
    final mock = MockClient((_) async => http.Response('x', 500));
    expect(() => OpenMeteoClient(client: mock).fetch(0, 0),
        throwsA(isA<ForecastException>()));
  });
}
```
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** `flutter pub add http`. Implement:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ForecastException implements Exception {
  final String message;
  ForecastException(this.message);
  @override
  String toString() => 'ForecastException: $message';
}

class HourlyForecast {
  final DateTime time;
  final double tempC, windKmh, uv, precipMm;
  const HourlyForecast(this.time, this.tempC, this.windKmh, this.uv, this.precipMm);
}

class OpenMeteoClient {
  final http.Client _c;
  OpenMeteoClient({http.Client? client}) : _c = client ?? http.Client();

  Future<List<HourlyForecast>> fetch(double lat, double lon, {int days = 3}) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat', 'longitude': '$lon',
      'hourly': 'temperature_2m,wind_speed_10m,uv_index,precipitation',
      'forecast_days': '$days', 'timezone': 'auto',
    });
    final res = await _c.get(uri);
    if (res.statusCode != 200) {
      throw ForecastException('HTTP ${res.statusCode}');
    }
    try {
      final h = (jsonDecode(res.body) as Map<String, dynamic>)['hourly']
          as Map<String, dynamic>;
      final t = (h['time'] as List).cast<String>();
      List<double> d(String k) =>
          (h[k] as List).map((e) => (e as num).toDouble()).toList();
      final temp = d('temperature_2m'), wind = d('wind_speed_10m');
      final uv = d('uv_index'), pr = d('precipitation');
      return [for (var i = 0; i < t.length; i++)
        HourlyForecast(DateTime.parse(t[i]), temp[i], wind[i], uv[i], pr[i])];
    } catch (e) {
      throw ForecastException('respuesta inválida: $e');
    }
  }
}
```
- [ ] **Step 4:** Run → PASS. Commit `feat: open-meteo client`.

### Task 7: Pack list generator

**Files:** Create `lib/domain/packing.dart`; Test `test/domain/packing_test.dart`

**Interfaces:** Consumes `Activity`, `RouteStats`. Produces `class PackContext { final Activity activity; final Duration duration; final double minTempC, maxUv, maxWindKmh, precipMm; }`, `List<String> buildPackList(PackContext c)`.

**Acceptance Criteria:** always water (3 L min, +0.5 L per hour over 4 h) and headlamp when duration > 3 h; sun protection when UV ≥ 3; gloves/insulation when minTemp < 5; caving → helmet + 2 lights + rope kit; alpine → crampons if minTemp < 0; no duplicates.

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/packing.dart';
import 'package:expedition_planner/domain/time_model.dart';

PackContext ctx({Activity a = Activity.hiking, int h = 5, double t = 10,
        double uv = 2, double w = 10, double p = 0}) =>
    PackContext(a, Duration(hours: h), t, uv, w, p);

void main() {
  test('water scales with duration', () {
    expect(buildPackList(ctx(h: 8)), contains('Agua: 5.0 L'));
  });
  test('sun protection at UV 3+', () {
    expect(buildPackList(ctx(uv: 5)), contains('Protector solar SPF50+'));
    expect(buildPackList(ctx(uv: 1)), isNot(contains('Protector solar SPF50+')));
  });
  test('cold gear below 5C', () {
    expect(buildPackList(ctx(t: 2)), contains('Guantes y capa de abrigo'));
  });
  test('caving kit', () {
    final l = buildPackList(ctx(a: Activity.caving));
    expect(l, containsAll(['Casco', 'Segunda luz frontal', 'Kit de cuerdas']));
  });
  test('crampons only alpine below 0C', () {
    expect(buildPackList(ctx(a: Activity.alpine, t: -3)), contains('Crampones'));
    expect(buildPackList(ctx(a: Activity.hiking, t: -3)), isNot(contains('Crampones')));
  });
  test('no duplicates', () {
    final l = buildPackList(ctx(a: Activity.caving, h: 9));
    expect(l.toSet().length, l.length);
  });
}
```
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement**
```dart
import 'time_model.dart';

class PackContext {
  final Activity activity;
  final Duration duration;
  final double minTempC, maxUv, maxWindKmh, precipMm;
  const PackContext(this.activity, this.duration, this.minTempC, this.maxUv,
      this.maxWindKmh, this.precipMm);
}

List<String> buildPackList(PackContext c) {
  final hours = c.duration.inMinutes / 60;
  final water = 3.0 + (hours > 4 ? (hours - 4) * 0.5 : 0);
  final l = <String>{'Agua: ${water.toStringAsFixed(1)} L', 'Botiquín básico'};
  if (hours > 3) l.add('Linterna frontal');
  if (c.maxUv >= 3) {
    l..add('Protector solar SPF50+')..add('Gafas de sol categoría 4');
  }
  if (c.minTempC < 5) l.add('Guantes y capa de abrigo');
  if (c.maxWindKmh > 40) l.add('Cortavientos');
  if (c.precipMm > 0.5) l.add('Impermeable');
  if (c.activity == Activity.caving) {
    l..add('Casco')..add('Segunda luz frontal')..add('Kit de cuerdas');
  }
  if (c.activity == Activity.alpine && c.minTempC < 0) l.add('Crampones');
  return l.toList();
}
```
- [ ] **Step 4:** Run → PASS. Commit `feat: pack list generator`.

### Task 8: Wizard UI (Dónde → Ruta → Análisis) and theme

**Files:** Create `lib/ui/theme.dart`, `lib/ui/wizard/where_step.dart`, `route_step.dart`, `analysis_step.dart`; Modify `lib/app.dart`; Test `test/ui/wizard_test.dart`

**Interfaces:** Consumes everything above. Produces `class WizardState` (Riverpod `StateNotifier`) with `route`, `activity`, `forecast`; `ExpeditionApp` shows a stepper with 3 steps; "Analizar ruta" disabled until a route exists.

**Acceptance Criteria:**
- Step 1 offers "Usar mi ubicación" and manual search; Step 2 imports a GPX file (file_picker) and shows km, D+, alt. máx, tiempo, perfil (fl_chart) and activity chips; Step 3 shows day picker, hourly temperature/UV at route max altitude, "cota de 0 °C", burn minutes, and the pack list.
- Buttons ≥ 56 dp; night-red theme toggle; all texts in Spanish.
- Widget test: with an injected route and fake forecast, step 3 renders the pack list and "cota de 0 °C".

- [ ] **Step 1:** Write widget test pumping `ExpeditionApp` with provider overrides (fake route of 3 points, fake `OpenMeteoClient`), navigate to step 3, assert `find.text('Protector solar SPF50+')` when fake UV = 6 and `find.textContaining('cota de 0')`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** `flutter pub add flutter_riverpod fl_chart file_picker flutter_map latlong2 geolocator`. Implement theme, state notifier and three step widgets calling `parseGpx`, `computeStats`, `estimateTime`, `OpenMeteoClient.fetch`, `tempAtAltitude`, `uvAtAltitude`, `burnMinutes`, `freezingLevelM`, `buildPackList` exactly as defined in Tasks 2–7.
- [ ] **Step 4:** Run `flutter test` (all) → PASS; `flutter analyze` clean. Commit `feat: wizard ui`.

### Task 9: Expert map mode with offline tile cache

**Files:** Create `lib/ui/expert/map_page.dart`, `lib/data/tile_cache.dart`; Test `test/data/tile_cache_test.dart`

**Interfaces:** Produces `class TileCache { Future<void> downloadArea(LatLngBounds b, int minZoom, int maxZoom); int estimateTiles(LatLngBounds b, int minZoom, int maxZoom); }`.

**Acceptance Criteria:** `estimateTiles` unit-tested against known tile counts; download refuses > 2 000 tiles per request (tile-server usage policy) and shows the count before downloading; map shows route polyline over OpenTopoMap tiles served from cache first.

- [ ] **Step 1:** Failing test: `estimateTiles` for a 0.1°×0.1° box at z12–z13 equals the hand-computed count; `downloadArea` over the limit throws `ArgumentError`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** implement slippy-map tile math (`x = floor((lon+180)/360 * 2^z)`, `y` via Mercator) and cache to app documents dir. **Step 4:** Run → PASS. Commit `feat: expert map and tile cache`.

### Task 10: Build instructions and Windows/Android packaging script

**Files:** Create `expedition-planner/README.md`, `expedition-planner/tools/build.ps1`, `expedition-planner/tools/build.sh`

**Acceptance Criteria:** README lists prerequisites (Flutter, Android SDK, Visual Studio "Desktop development with C++"), commands `flutter build windows --release` and `flutter build apk --release`, and where outputs land; `build.sh` runs `flutter test && flutter analyze` before building web/linux in CI.

- [ ] **Step 1:** Write files. **Step 2:** In the container run `flutter build linux` or `flutter build web` to prove the project compiles. **Step 3:** Commit `docs: build instructions`.

---

## Self-Review

**Spec coverage (Phase 1):** maps & routes → Tasks 2, 3, 8, 9; time model → 4; weather by altitude/UV/temperature → 5, 6, 8; pack list → 7, 8; guided wizard + expert mode → 8, 9; Windows + Android build → 10; Spanish/dark tactical/large targets → 8 constraints.
**Not in this plan (deferred, acknowledged above):** safety/emergency plan, logbook, account + sync, gear inventory, specific risks, recording planner, AI assistant, daylight window (deferred to Phase 2 with sunrise/sunset from the API).
**Placeholder scan:** Task 8 and 9 steps describe UI work at a higher level than domain tasks; code for widgets will be written test-first during execution against the stated interfaces.
**Type consistency:** `LatLngEle`, `RouteStats`, `Activity`, `HourlyForecast`, `PackContext` names match across tasks.
