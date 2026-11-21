import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class SessionData {
  final String uid;
  final String email;
  final String access;
  final String refresh;
  final int expiresAt; // epoch segundos
  const SessionData(this.uid, this.email, this.access, this.refresh, this.expiresAt);

  Map<String, dynamic> toJson() => {'uid': uid, 'email': email, 'access': access, 'refresh': refresh, 'exp': expiresAt};
  factory SessionData.fromJson(Map<String, dynamic> j) =>
      SessionData(j['uid'] as String, j['email'] as String, j['access'] as String, j['refresh'] as String, (j['exp'] as num).toInt());
}

/// Cliente mínimo de Supabase por HTTP (auth, REST, storage y funciones).
class Api {
  SessionData? session;
  final http.Client _c = http.Client();

  String get _base => Config.supabaseUrl;

  Map<String, String> _h({bool auth = true, Map<String, String>? extra}) => {
        'apikey': Config.anonKey,
        'Content-Type': 'application/json',
        if (auth && session != null) 'Authorization': 'Bearer ${session!.access}',
        if (auth && session == null) 'Authorization': 'Bearer ${Config.anonKey}',
        ...?extra,
      };

  // ---------------------------------------------------------------- sesión

  Future<void> loadSession() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('session');
    if (s != null) {
      try {
        session = SessionData.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (session == null) {
      await p.remove('session');
    } else {
      await p.setString('session', jsonEncode(session!.toJson()));
    }
  }

  SessionData _parseSession(Map<String, dynamic> j, String fallbackEmail) {
    final user = (j['user'] as Map?) ?? {};
    final exp = (j['expires_at'] as num?)?.toInt() ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000 + ((j['expires_in'] as num?)?.toInt() ?? 3600));
    return SessionData(
      (user['id'] ?? session?.uid ?? '') as String,
      (user['email'] ?? fallbackEmail) as String,
      j['access_token'] as String,
      j['refresh_token'] as String,
      exp,
    );
  }

  String _friendly(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('invalid login')) return 'Correo o contraseña incorrectos';
    if (r.contains('already registered') || r.contains('already been registered')) return 'Ya existe una cuenta con ese correo';
    if (r.contains('password should be at least')) return 'La contraseña debe tener al menos 6 caracteres';
    if (r.contains('unable to validate email') || r.contains('invalid email')) return 'Correo no válido';
    if (r.contains('email not confirmed')) return 'Correo sin confirmar. Desactiva «Confirm email» en Supabase.';
    if (r.contains('rate limit')) return 'Demasiados intentos. Espera un minuto.';
    return raw;
  }

  Future<dynamic> _decode(http.Response r) async {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = r.body;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    String msg = 'Error ${r.statusCode}';
    if (body is Map) {
      msg = (body['msg'] ?? body['message'] ?? body['error_description'] ?? body['error'] ?? body['hint'] ?? msg).toString();
    } else if (body is String && body.isNotEmpty) {
      msg = body;
    }
    throw ApiException(_friendly(msg), r.statusCode);
  }

  Future<SessionData> signUp(String email, String password) async {
    final r = await _c.post(Uri.parse('$_base/auth/v1/signup'),
        headers: _h(auth: false), body: jsonEncode({'email': email, 'password': password}));
    final j = await _decode(r) as Map<String, dynamic>;
    if (j['access_token'] == null) {
      throw ApiException('Cuenta creada pero sin sesión. Desactiva «Confirm email» en Supabase (Authentication > Providers > Email).');
    }
    session = _parseSession(j, email);
    await _save();
    return session!;
  }

  Future<SessionData> signIn(String email, String password) async {
    final r = await _c.post(Uri.parse('$_base/auth/v1/token?grant_type=password'),
        headers: _h(auth: false), body: jsonEncode({'email': email, 'password': password}));
    final j = await _decode(r) as Map<String, dynamic>;
    session = _parseSession(j, email);
    await _save();
    return session!;
  }

  Future<void> signOut() async {
    try {
      if (session != null) {
        await _c.post(Uri.parse('$_base/auth/v1/logout'), headers: _h()).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    session = null;
    await _save();
  }

  /// Renueva el token si está a punto de caducar. Si no hay red, devuelve false.
  Future<bool> ensureFresh() async {
    final s = session;
    if (s == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (s.expiresAt - now > 90) return true;
    try {
      final r = await _c
          .post(Uri.parse('$_base/auth/v1/token?grant_type=refresh_token'),
              headers: _h(auth: false), body: jsonEncode({'refresh_token': s.refresh}))
          .timeout(const Duration(seconds: 15));
      final j = await _decode(r) as Map<String, dynamic>;
      session = _parseSession(j, s.email);
      await _save();
      return true;
    } on ApiException catch (e) {
      if (e.status == 400 || e.status == 401) {
        // Refresh token inválido: hay que volver a iniciar sesión.
        session = null;
        await _save();
      }
      return false;
    } catch (_) {
      return false; // sin red
    }
  }

  // ---------------------------------------------------------------- REST

  Future<dynamic> get(String path) async {
    await ensureFresh();
    final r = await _c.get(Uri.parse('$_base/rest/v1/$path'), headers: _h()).timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Future<dynamic> post(String path, Object body, {Map<String, String>? prefer}) async {
    await ensureFresh();
    final r = await _c
        .post(Uri.parse('$_base/rest/v1/$path'),
            headers: _h(extra: {if (prefer != null) ...prefer}), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    return _decode(r);
  }

  Future<dynamic> rpc(String fn, [Map<String, dynamic>? args]) async {
    await ensureFresh();
    final r = await _c
        .post(Uri.parse('$_base/rest/v1/rpc/$fn'), headers: _h(), body: jsonEncode(args ?? {}))
        .timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Future<void> delete(String path) async {
    await ensureFresh();
    final r = await _c.delete(Uri.parse('$_base/rest/v1/$path'), headers: _h()).timeout(const Duration(seconds: 30));
    await _decode(r);
  }

  // ---------------------------------------------------------------- Perfil

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final l = await get('profiles?uid=eq.$uid&select=*') as List;
    return l.isEmpty ? null : Map<String, dynamic>.from(l.first as Map);
  }

  Future<void> upsertProfile(Map<String, dynamic> p) async {
    await post('profiles?on_conflict=uid', p, prefer: {'Prefer': 'resolution=merge-duplicates,return=minimal'});
  }

  // ---------------------------------------------------------------- Registros

  Future<void> upsertRecords(String owner, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await post(
      'records?on_conflict=owner,col,id',
      [
        for (final r in rows)
          {
            'owner': owner,
            'col': r['col'],
            'id': r['id'],
            'json': r['json'],
            'deleted': r['deleted'] == true || r['deleted'] == 1,
          }
      ],
      prefer: {'Prefer': 'resolution=merge-duplicates,return=minimal'},
    );
  }

  /// Registros de [owner] modificados después de [since] (cursor del servidor).
  Future<List<Map<String, dynamic>>> pullRecords(String owner, String since, {String? col}) async {
    final out = <Map<String, dynamic>>[];
    var cursor = since;
    while (true) {
      final q = 'records?owner=eq.$owner&updated=gt.${Uri.encodeQueryComponent(cursor)}'
          '${col != null ? '&col=eq.$col' : ''}&order=updated.asc&limit=1000&select=col,id,json,updated,deleted';
      final l = (await get(q) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      out.addAll(l);
      if (l.length < 1000) break;
      cursor = l.last['updated'] as String;
    }
    return out;
  }

  // ---------------------------------------------------------------- Storage

  Future<void> uploadDoc(String path, List<int> bytes, String contentType) async {
    await ensureFresh();
    final r = await _c
        .post(Uri.parse('$_base/storage/v1/object/docs/$path'),
            headers: _h(extra: {'Content-Type': contentType, 'x-upsert': 'true'}), body: bytes)
        .timeout(const Duration(minutes: 3));
    await _decode(r);
  }

  Future<List<int>> downloadDoc(String path) async {
    await ensureFresh();
    final r = await _c
        .get(Uri.parse('$_base/storage/v1/object/authenticated/docs/$path'), headers: _h())
        .timeout(const Duration(minutes: 3));
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    await _decode(r);
    return [];
  }

  // ---------------------------------------------------------------- Funciones

  Future<Map<String, dynamic>> fn(String name, Map<String, dynamic> body) async {
    await ensureFresh();
    final r = await _c
        .post(Uri.parse('$_base/functions/v1/$name'), headers: _h(), body: jsonEncode(body))
        .timeout(const Duration(minutes: 4));
    final j = await _decode(r);
    return Map<String, dynamic>.from(j as Map);
  }
}
