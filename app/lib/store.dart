import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'calc.dart';

/// Colecciones de la base local.
class Col {
  static const plan = 'plan'; // sesiones planificadas
  static const logs = 'logs'; // sesiones realizadas
  static const wellbeing = 'wellbeing'; // id = yyyy-MM-dd
  static const tests = 'tests'; // resultados de tests
  static const competitions = 'competitions';
  static const expeditions = 'expeditions';
  static const settings = 'settings'; // doc 'main'
  static const curves = 'curves'; // curvas Tindeq
  static const messages = 'messages'; // mensajes entrenador <-> cliente
  static const coachNotes = 'coachnotes'; // notas del entrenador sobre un cliente
  static const studies = 'studies'; // estudios importados (valores, reglas)
  static const foods = 'foods'; // alimentos con etiqueta
  static const meals = 'meals'; // comidas (receta)
  static const mealLog = 'meallog'; // registro de comidas
  static const supplements = 'supplements'; // suplementos y horarios
  static const supLog = 'suplog'; // tomas registradas
  static const classes = 'classes'; // clases (entrenador)
  static const docs = 'docs'; // documentos subidos
  static const bodycomp = 'bodycomp'; // bioimpedancia
  static const labs = 'labs'; // analíticas
  static const consent = 'consent'; // consentimientos
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

String _nowUtc() => DateTime.now().toUtc().toIso8601String();

/// Almacén local offline. Una tabla genérica (col, id, json) en SQLite, una base
/// de datos por cuenta. Todo vive en memoria y se persiste en cada cambio.
/// Cada cambio queda marcado como «pendiente» (dirty) hasta que se sincroniza.
class Store extends ChangeNotifier {
  final String uid;
  Store(this.uid);

  late Database _db;
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};
  int _changeCounter = 0;

  /// Se incrementa con cada cambio local (para disparar la sincronización).
  int get changeCounter => _changeCounter;

  static const _cols = [
    Col.plan, Col.logs, Col.wellbeing, Col.tests, Col.competitions, Col.expeditions, Col.settings,
    Col.curves, Col.messages, Col.coachNotes, Col.studies, Col.foods, Col.meals, Col.mealLog,
    Col.supplements, Col.supLog, Col.classes, Col.docs, Col.bodycomp, Col.labs, Col.consent,
  ];

  Future<void> init({bool importLegacy = false}) async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'tonylocuras_$uid.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE records (col TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, '
            'dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (col, id))');
        await db.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
      },
    );
    for (final c in _cols) {
      _data[c] = {};
    }
    if (importLegacy) await _importLegacy(dir);
    final rows = await _db.query('records', where: 'deleted = 0');
    for (final r in rows) {
      final col = r['col'] as String;
      _data.putIfAbsent(col, () => {});
      _data[col]![r['id'] as String] = jsonDecode(r['json'] as String) as Map<String, dynamic>;
    }
    if (settings.isEmpty) {
      // updated = 1970: así cualquier ajuste que venga de la nube gana al valor por defecto.
      final doc = {
        'id': 'main',
        'updated': '1970-01-01T00:00:00.000Z',
        'weightKg': 60.8,
        'heightCm': 173,
        'age': 19,
        'greenFrom': 75,
        'amberFrom': 50,
        'rules': [for (final r in defaultRules) r.toJson()],
        'tindeqThresholdKg': 1.0,
      };
      _data[Col.settings]!['main'] = doc;
      await _db.insert('records', {'col': Col.settings, 'id': 'main', 'json': jsonEncode(doc), 'dirty': 0, 'deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Copia los datos de la v0.1 (base local sin cuentas) a esta cuenta, una sola vez.
  Future<void> _importLegacy(String dir) async {
    final flag = await _meta('legacy_imported');
    if (flag != null) return;
    final f = File(p.join(dir, 'tonylocuras.db'));
    if (await f.exists()) {
      try {
        final old = await openDatabase(f.path, readOnly: true);
        final rows = await old.query('records');
        for (final r in rows) {
          final col = r['col'] as String;
          if (col == Col.settings) continue;
          await _db.insert('records', {'col': col, 'id': r['id'], 'json': r['json'], 'dirty': 1, 'deleted': 0},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await old.close();
      } catch (_) {}
    }
    await _setMeta('legacy_imported', '1');
  }

  Future<String?> _meta(String k) async {
    final r = await _db.query('meta', where: 'k = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> _setMeta(String k, String v) =>
      _db.insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String> get lastSync async => (await _meta('last_sync')) ?? '1970-01-01T00:00:00.000Z';
  Future<void> setLastSync(String v) => _setMeta('last_sync', v);

  Map<String, dynamic> get settings => _data[Col.settings]!['main'] ?? {};

  double get weightKg => (settings['weightKg'] as num?)?.toDouble() ?? 60.8;

  List<TrafficRule> get rules {
    final raw = settings['rules'];
    if (raw is List) {
      return [for (final r in raw) TrafficRule.fromJson(Map<String, dynamic>.from(r as Map))];
    }
    return defaultRules;
  }

  List<Map<String, dynamic>> list(String col) => (_data[col] ?? {}).values.toList(growable: false);

  Map<String, dynamic>? get(String col, String id) => _data[col]?[id];

  Future<Map<String, dynamic>> put(String col, Map<String, dynamic> doc, {bool notify = true}) async {
    final m = Map<String, dynamic>.from(doc);
    m['id'] = (m['id'] as String?) ?? newId();
    m['updated'] = _nowUtc();
    _data.putIfAbsent(col, () => {})[m['id'] as String] = m;
    await _db.insert('records', {'col': col, 'id': m['id'], 'json': jsonEncode(m), 'dirty': 1, 'deleted': 0},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _changeCounter++;
    if (notify) notifyListeners();
    return m;
  }

  Future<void> remove(String col, String id) async {
    final old = _data[col]?.remove(id);
    final m = Map<String, dynamic>.from(old ?? {'id': id});
    m['updated'] = _nowUtc();
    await _db.insert('records', {'col': col, 'id': id, 'json': jsonEncode(m), 'dirty': 1, 'deleted': 1},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _changeCounter++;
    notifyListeners();
  }

  Future<void> saveSettings(Map<String, dynamic> patch) async {
    final s = Map<String, dynamic>.from(settings)..addAll(patch);
    s['id'] = 'main';
    await put(Col.settings, s);
  }

  // ---------------------------------------------------------------- Sincronización

  Future<List<Map<String, dynamic>>> dirtyRows() async {
    final rows = await _db.query('records', where: 'dirty = 1');
    return [
      for (final r in rows)
        {
          'col': r['col'],
          'id': r['id'],
          'json': jsonDecode(r['json'] as String),
          'deleted': (r['deleted'] as int) == 1,
        }
    ];
  }

  Future<void> markClean(List<Map<String, dynamic>> rows) async {
    final b = _db.batch();
    for (final r in rows) {
      b.update('records', {'dirty': 0}, where: 'col = ? AND id = ? AND json = ?',
          whereArgs: [r['col'], r['id'], jsonEncode(r['json'])]);
    }
    await b.commit(noResult: true);
  }

  /// Aplica registros remotos. Gana el más reciente (campo json.updated) cuando
  /// hay cambio local pendiente; si no, gana siempre el remoto.
  Future<int> applyRemote(List<Map<String, dynamic>> remote) async {
    var n = 0;
    final b = _db.batch();
    for (final r in remote) {
      final col = r['col'] as String;
      final id = r['id'] as String;
      final js = Map<String, dynamic>.from(r['json'] as Map);
      final del = r['deleted'] == true;
      final localRows = await _db.query('records', where: 'col = ? AND id = ?', whereArgs: [col, id]);
      if (localRows.isNotEmpty && (localRows.first['dirty'] as int) == 1) {
        final lj = jsonDecode(localRows.first['json'] as String) as Map<String, dynamic>;
        final lu = DateTime.tryParse('${lj['updated']}');
        final ru = DateTime.tryParse('${js['updated']}');
        if (lu != null && ru != null && lu.isAfter(ru)) continue; // el local es más nuevo
      }
      b.insert('records', {'col': col, 'id': id, 'json': jsonEncode(js), 'dirty': 0, 'deleted': del ? 1 : 0},
          conflictAlgorithm: ConflictAlgorithm.replace);
      final m = _data.putIfAbsent(col, () => {});
      if (del) {
        m.remove(id);
      } else {
        m[id] = js;
      }
      n++;
    }
    await b.commit(noResult: true);
    if (n > 0) notifyListeners();
    return n;
  }

  // ---------------------------------------------------------------- Consultas

  /// Sesiones planificadas de un día concreto, ordenadas por hora.
  List<Map<String, dynamic>> planFor(DateTime d) {
    final k = dayKey(d);
    final l = list(Col.plan).where((s) => s['date'] == k).toList();
    l.sort((a, b) => ((a['time'] ?? '') as String).compareTo((b['time'] ?? '') as String));
    return l;
  }

  Map<String, dynamic>? wellbeingFor(DateTime d) => _data[Col.wellbeing]?[dayKey(d)];

  /// Horas desde el fin de la última expedición cerrada.
  double? hoursSinceLastExpedition(DateTime now) {
    DateTime? last;
    for (final e in list(Col.expeditions)) {
      final end = DateTime.tryParse((e['end'] ?? '') as String);
      if (end != null && (last == null || end.isAfter(last))) last = end;
    }
    if (last == null) return null;
    final h = now.difference(last).inMinutes / 60.0;
    return h < 0 ? 0 : h;
  }

  /// Valores del semáforo del día. Los campos que faltan no se rellenan.
  Map<String, double> trafficValues(DateTime d) {
    final w = wellbeingFor(d);
    final v = <String, double>{};
    if (w != null) {
      for (final k in ['sleepH', 'sleepQ', 'fatigue', 'stress', 'motivation']) {
        final x = w[k];
        if (x is num) v[k] = x.toDouble();
      }
      final pains = (w['pain'] as Map?)?.values.whereType<num>().map((e) => e.toDouble()).toList();
      if (pains != null && pains.isNotEmpty) {
        v['pain'] = pains.reduce((a, b) => a > b ? a : b);
      }
    }
    final h = hoursSinceLastExpedition(d);
    if (h != null) v['expH'] = h;
    return v;
  }

  TrafficResult trafficFor(DateTime d) => trafficLight(
        trafficValues(d),
        rules,
        greenFrom: (settings['greenFrom'] as num?)?.toDouble() ?? 75,
        amberFrom: (settings['amberFrom'] as num?)?.toDouble() ?? 50,
      );

  // ---------------------------------------------------------------- Copias

  /// Exporta todos los datos a un JSON completo y lo comparte.
  Future<void> exportJson() async {
    final out = <String, dynamic>{
      'app': 'tonylocuras_entreno',
      'exported': DateTime.now().toIso8601String(),
      for (final c in _cols) c: list(c),
    };
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'tonylocuras_backup_${dayKey(DateTime.now())}.json'));
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(out));
    await Share.shareXFiles([XFile(f.path)], text: 'Copia de seguridad TonyLocuras');
  }

  /// Exporta una colección a CSV (valores simples) y la comparte.
  Future<void> exportCsv(String col) async {
    final rows = list(col);
    final keys = <String>{};
    for (final r in rows) {
      for (final e in r.entries) {
        if (e.value is! Map && e.value is! List) keys.add(e.key);
      }
    }
    final ks = keys.toList()..sort();
    String esc(Object? v) {
      final s = v == null ? '' : '$v';
      return s.contains(RegExp(r'[",\n;]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final sb = StringBuffer()..writeln(ks.join(','));
    for (final r in rows) {
      sb.writeln(ks.map((k) => esc(r[k])).join(','));
    }
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'tonylocuras_${col}_${dayKey(DateTime.now())}.csv'));
    await f.writeAsString(sb.toString());
    await Share.shareXFiles([XFile(f.path)], text: 'Datos $col');
  }

  /// Importa una copia JSON (sustituye registros con el mismo id).
  Future<int> importJson(String content) async {
    final j = jsonDecode(content) as Map<String, dynamic>;
    var n = 0;
    for (final c in _cols) {
      final l = j[c];
      if (l is List) {
        for (final d in l) {
          await put(c, Map<String, dynamic>.from(d as Map), notify: false);
          n++;
        }
      }
    }
    notifyListeners();
    return n;
  }

  /// Borra TODOS los datos locales de esta cuenta (derecho de supresión).
  Future<void> wipeLocal() async {
    await _db.delete('records');
    for (final c in _cols) {
      _data[c] = {};
    }
    notifyListeners();
  }

  /// Fuerza el redibujado de las pantallas que escuchan el almacén.
  void refresh() => notifyListeners();

  @visibleForTesting
  Map<String, Map<String, Map<String, dynamic>>> get raw => _data;
}
