import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'store.dart';

/// Sincronización offline-first: primero baja lo nuevo de la nube y luego sube
/// lo pendiente. Si hay conflicto en un registro, gana el más reciente.
class SyncService extends ChangeNotifier {
  final Api api;
  final Store store;
  SyncService(this.api, this.store);

  bool syncing = false;
  String status = 'Sin sincronizar';
  DateTime? lastOk;
  String? error;
  Timer? _timer;
  int _seenChanges = 0;
  bool _disposed = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _maybe());
    store.addListener(_maybeLocalChange);
    sync();
  }

  void _maybeLocalChange() {
    if (store.changeCounter != _seenChanges && !syncing) {
      _seenChanges = store.changeCounter;
      // pequeño retardo para agrupar cambios seguidos
      Future.delayed(const Duration(seconds: 4), () {
        if (!_disposed) sync();
      });
    }
  }

  void _maybe() {
    if (!syncing) sync();
  }

  Future<void> sync() async {
    if (syncing || _disposed) return;
    final s = api.session;
    if (s == null) return;
    syncing = true;
    status = 'Sincronizando...';
    notifyListeners();
    try {
      if (!await api.ensureFresh()) throw ApiException('Sin conexión');
      // 1) bajar
      final since = await store.lastSync;
      final remote = await api.pullRecords(s.uid, since);
      if (remote.isNotEmpty) {
        await store.applyRemote(remote);
        await store.setLastSync(remote.last['updated'] as String);
      }
      // 2) subir
      final dirty = await store.dirtyRows();
      for (var i = 0; i < dirty.length; i += 200) {
        final chunk = dirty.sublist(i, i + 200 > dirty.length ? dirty.length : i + 200);
        await api.upsertRecords(s.uid, chunk);
        await store.markClean(chunk);
      }
      lastOk = DateTime.now();
      error = null;
      status = dirty.isEmpty && remote.isEmpty ? 'Al día' : 'Sincronizado';
    } on ApiException catch (e) {
      error = e.message;
      status = e.message == 'Sin conexión' ? 'Sin conexión (los datos se suben al volver)' : 'Error: ${e.message}';
    } catch (e) {
      error = '$e';
      status = 'Sin conexión (los datos se suben al volver)';
    } finally {
      syncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    store.removeListener(_maybeLocalChange);
    super.dispose();
  }
}
