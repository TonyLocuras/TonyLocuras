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
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Almacén local offline. Una sola tabla genérica (col, id, json) en SQLite.
/// Todo se mantiene en memoria y se persiste en cada cambio.
class Store extends ChangeNotifier {
  late Database _db;
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};

  static const _cols = [
    Col.plan,
    Col.logs,
    Col.wellbeing,
    Col.tests,
    Col.competitions,
    Col.expeditions,
    Col.settings,
    Col.curves,
  ];

  Future<void> init() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'tonylocuras.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
            'CREATE TABLE records (col TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, PRIMARY KEY (col, id))');
      },
    );
    for (final c in _cols) {
      _data[c] = {};
    }
    final rows = await _db.query('records');
    for (final r in rows) {
      final col = r['col'] as String;
      _data.putIfAbsent(col, () => {});
      _data[col]![r['id'] as String] =
          jsonDecode(r['json'] as String) as Map<String, dynamic>;
    }
    if (settings.isEmpty) {
      await put(Col.settings, {
        'id': 'main',
        'weightKg': 60.8,
        'heightCm': 173,
        'age': 19,
        'greenFrom': 75,
        'amberFrom': 50,
        'rules': [for (final r in defaultRules) r.toJson()],
        'tindeqThresholdKg': 1.0,
      }, notify: false);
    }
  }

  Map<String, dynamic> get settings => _data[Col.settings]!['main'] ?? {};

  double get weightKg => (settings['weightKg'] as num?)?.toDouble() ?? 60.8;

  List<TrafficRule> get rules {
    final raw = settings['rules'];
    if (raw is List) {
      return [for (final r in raw) TrafficRule.fromJson(Map<String, dynamic>.from(r as Map))];
    }
    return defaultRules;
  }

  List<Map<String, dynamic>> list(String col) =>
      _data[col]!.values.toList(growable: false);

  Map<String, dynamic>? get(String col, String id) => _data[col]![id];

  Future<Map<String, dynamic>> put(String col, Map<String, dynamic> doc,
      {bool notify = true}) async {
    final m = Map<String, dynamic>.from(doc);
    m['id'] = (m['id'] as String?) ?? newId();
    m['updated'] = DateTime.now().toIso8601String();
    _data[col]![m['id'] as String] = m;
    await _db.insert(
      'records',
      {'col': col, 'id': m['id'], 'json': jsonEncode(m)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (notify) notifyListeners();
    return m;
  }

  Future<void> remove(String col, String id) async {
    _data[col]!.remove(id);
    await _db.delete('records', where: 'col = ? AND id = ?', whereArgs: [col, id]);
    notifyListeners();
  }

  Future<void> saveSettings(Map<String, dynamic> patch) async {
    final s = Map<String, dynamic>.from(settings)..addAll(patch);
    s['id'] = 'main';
    await put(Col.settings, s);
  }

  /// Sesiones planificadas de un día concreto, ordenadas por hora.
  List<Map<String, dynamic>> planFor(DateTime d) {
    final k = dayKey(d);
    final l = list(Col.plan).where((s) => s['date'] == k).toList();
    l.sort((a, b) => ((a['time'] ?? '') as String).compareTo((b['time'] ?? '') as String));
    return l;
  }

  Map<String, dynamic>? wellbeingFor(DateTime d) => _data[Col.wellbeing]![dayKey(d)];

  /// Última expedición cerrada (con fin registrado) -> horas desde su fin.
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

  @visibleForTesting
  Map<String, Map<String, Map<String, dynamic>>> get raw => _data;
}
