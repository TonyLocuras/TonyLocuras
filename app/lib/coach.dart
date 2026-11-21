import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'store.dart';

const _epoch = '1970-01-01T00:00:00.000Z';

/// Operaciones del entrenador sobre sus clientes vinculados.
/// Los permisos reales los aplica la base de datos (RLS): el entrenador lee todo
/// de sus clientes y solo escribe plan, mensajes y notas.
class CoachService extends ChangeNotifier {
  final Api api;
  final Store store;
  CoachService(this.api, this.store);

  List<Map<String, dynamic>> clients = [];
  bool loading = false;
  String? error;

  String get uid => api.session!.uid;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final l = await api.rpc('my_clients') as List;
      clients = [for (final c in l) Map<String, dynamic>.from(c as Map)];
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Sin conexión';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? clientByUid(String uid) {
    for (final c in clients) {
      if (c['uid'] == uid) return c;
    }
    return null;
  }

  /// Registros de una colección de un cliente (sin borrados).
  Future<List<Map<String, dynamic>>> clientRecords(String clientUid, String col) async {
    final rows = await api.pullRecords(clientUid, _epoch, col: col);
    return [
      for (final r in rows)
        if (r['deleted'] != true) Map<String, dynamic>.from(r['json'] as Map)
    ];
  }

  /// Escribe (crea o modifica) un registro en los datos del cliente.
  Future<Map<String, dynamic>> writeToClient(String clientUid, String col, Map<String, dynamic> doc, {bool deleted = false}) async {
    final m = Map<String, dynamic>.from(doc);
    m['id'] = (m['id'] as String?) ?? newId();
    m['updated'] = DateTime.now().toUtc().toIso8601String();
    m['byCoach'] = true;
    await api.upsertRecords(clientUid, [
      {'col': col, 'id': m['id'], 'json': m, 'deleted': deleted}
    ]);
    return m;
  }

  /// Envía una sesión a un cliente.
  Future<void> assignSession(String clientUid, Map<String, dynamic> session) =>
      writeToClient(clientUid, Col.plan, {...session, 'fromCoach': true});

  // ------------------------------------------------------------ invitaciones

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/O/1/I

  String _randomCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  Future<String> createInvite({String classId = '', String note = ''}) async {
    for (var i = 0; i < 5; i++) {
      final code = _randomCode();
      try {
        await api.post('invites', {'code': code, 'coach': uid, 'class_id': classId, 'note': note},
            prefer: {'Prefer': 'return=minimal'});
        return code;
      } on ApiException catch (e) {
        if (e.status != 409) rethrow; // 409 = código repetido, reintenta
      }
    }
    throw ApiException('No se pudo generar un código. Inténtalo de nuevo.');
  }

  Future<List<Map<String, dynamic>>> invites() async {
    final l = await api.get('invites?coach=eq.$uid&order=created_at.desc&select=*') as List;
    return [for (final e in l) Map<String, dynamic>.from(e as Map)];
  }

  Future<void> deleteInvite(String code) => api.delete('invites?code=eq.$code');

  /// El entrenador rompe el vínculo con un cliente.
  Future<void> unlink(String clientUid) async {
    await api.delete('coach_links?coach=eq.$uid&client=eq.$clientUid');
    await refresh();
  }
}
