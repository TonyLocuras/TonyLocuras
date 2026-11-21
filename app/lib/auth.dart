import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'store.dart';
import 'sync.dart';

/// Estado de sesión de toda la app: cuenta, perfil, almacén local y sincronización.
class AuthController extends ChangeNotifier {
  final Api api = Api();
  Store? store;
  SyncService? sync;
  Map<String, dynamic>? profile; // uid, role, name, birth...
  bool ready = false;

  bool get cloud => Config.cloudConfigured;
  bool get loggedIn => store != null;
  String get role => (profile?['role'] as String?) ?? 'athlete';
  String get name => (profile?['name'] as String?) ?? '';
  bool get isCoach => role == 'coach';
  bool get isClient => role == 'client';
  String? get uid => api.session?.uid ?? (cloud ? null : 'local');

  Future<void> init() async {
    if (!cloud) {
      // Sin nube configurada: modo local como la v0.1.
      profile = {'uid': 'local', 'role': 'athlete', 'name': 'Tony'};
      await _open('local', 'athlete');
      ready = true;
      notifyListeners();
      return;
    }
    await api.loadSession();
    final s = api.session;
    if (s != null) {
      final p = await SharedPreferences.getInstance();
      final cached = p.getString('profile_${s.uid}');
      if (cached != null) {
        profile = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        if (_roleAllowed(role)) {
          await _open(s.uid, role);
        } else {
          profile = null;
        }
      }
      // refresca el perfil si hay red (sin bloquear el arranque offline)
      _refreshProfile();
    }
    ready = true;
    notifyListeners();
  }

  bool _roleAllowed(String r) => Config.isClientApp ? r == 'client' : (r == 'athlete' || r == 'coach');

  Future<void> _refreshProfile() async {
    try {
      final s = api.session;
      if (s == null || !await api.ensureFresh()) return;
      final pr = await api.getProfile(s.uid);
      if (pr != null) {
        profile = pr;
        final p = await SharedPreferences.getInstance();
        await p.setString('profile_${s.uid}', jsonEncode(pr));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _open(String uid, String role) async {
    final st = Store(uid);
    await st.init(importLegacy: role == 'athlete');
    store = st;
    if (cloud && uid != 'local') {
      sync = SyncService(api, st)..start();
    }
  }

  Future<void> _close() async {
    sync?.dispose();
    sync = null;
    store?.dispose();
    store = null;
    profile = null;
  }

  /// Inicia sesión. Lanza ApiException con un mensaje en español si falla.
  Future<void> login(String email, String password) async {
    final s = await api.signIn(email.trim(), password);
    var pr = await api.getProfile(s.uid);
    if (pr == null) {
      await api.signOut();
      throw ApiException('Esta cuenta no tiene perfil. Crea la cuenta desde «Crear cuenta».');
    }
    final r = pr['role'] as String;
    if (!_roleAllowed(r)) {
      await api.signOut();
      throw ApiException(r == 'client'
          ? 'Esta cuenta es de cliente. Usa la app de clientes.'
          : 'Esta cuenta es de atleta/entrenador. Usa la app de entrenador.');
    }
    profile = pr;
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_${s.uid}', jsonEncode(pr));
    await _close();
    profile = pr;
    await _open(s.uid, r);
    notifyListeners();
  }

  /// Crea cuenta + perfil + consentimiento.
  Future<void> register({
    required String email,
    required String password,
    required String role,
    required String name,
    DateTime? birth,
    String guardianName = '',
    bool guardianConsent = false,
  }) async {
    if (!_roleAllowed(role)) throw ApiException('Rol no permitido en esta app');
    final s = await api.signUp(email.trim(), password);
    final now = DateTime.now().toUtc().toIso8601String();
    final pr = {
      'uid': s.uid,
      'role': role,
      'name': name.trim(),
      'birth': birth == null ? null : dayKey(birth),
      'guardian_name': guardianName.trim(),
      'guardian_consent': guardianConsent,
      'consent_at': now,
      'consent_version': Config.consentVersion,
    };
    try {
      await api.upsertProfile(pr);
    } catch (e) {
      await api.signOut();
      rethrow;
    }
    profile = pr;
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_${s.uid}', jsonEncode(pr));
    await _close();
    profile = pr;
    await _open(s.uid, role);
    await store!.put(Col.consent, {
      'id': 'consent-${Config.consentVersion}',
      'version': Config.consentVersion,
      'at': now,
      'guardianName': guardianName.trim(),
      'guardianConsent': guardianConsent,
    });
    notifyListeners();
  }

  Future<void> logout() async {
    await sync?.sync();
    await api.signOut();
    await _close();
    notifyListeners();
  }

  /// Derecho de supresión: borra datos en la nube y en el dispositivo.
  Future<void> eraseMyData() async {
    await api.rpc('erase_my_data');
    await store?.wipeLocal();
  }

  /// Un cliente canjea un código de invitación.
  Future<Map<String, dynamic>> redeemInvite(String code) async {
    final r = await api.rpc('redeem_invite', {'p_code': code});
    return Map<String, dynamic>.from(r as Map);
  }
}
