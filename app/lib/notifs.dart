import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// Recordatorios locales (funcionan sin conexión). Zona horaria fija: Europe/Madrid.
class Notifs {
  Notifs._();
  static final Notifs instance = Notifs._();

  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      await _p.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      await _p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  NotificationDetails _details(String channel, String name) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  Future<void> _daily(int id, String title, String body, int h, int m, {String channel = 'recordatorios'}) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _p.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: _details(channel, 'Recordatorios'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _once(int id, DateTime when, String title, String body, {String channel = 'recordatorios'}) async {
    final at = tz.TZDateTime.from(when, tz.local);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _p.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: _details(channel, 'Recordatorios'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// EPG/EPL a los 30 min de terminar una sesión.
  Future<void> scheduleEpg(String logId, String title, {Duration after = const Duration(minutes: 30)}) async {
    await init();
    if (!_ready) return;
    final id = 2000 + (logId.hashCode.abs() % 900);
    await _once(id, DateTime.now().add(after), 'Valora tu sesión', '$title: pon tu EPG y EPL (esfuerzo global y local).');
  }

  Future<void> cancelEpg(String logId) async {
    if (!_ready) return;
    await _p.cancel(id: 2000 + (logId.hashCode.abs() % 900));
  }

  (int, int) _hm(String? s, String def) {
    final t = (s ?? def).split(':');
    return (int.tryParse(t[0]) ?? 8, int.tryParse(t.length > 1 ? t[1] : '0') ?? 0);
  }

  /// Recalcula todos los recordatorios fijos a partir de los datos y ajustes.
  Future<void> rescheduleAll(Store store, {bool isClient = false}) async {
    await init();
    if (!_ready) return;
    for (final id in [1, ...List.generate(100, (i) => 100 + i), ...List.generate(100, (i) => 3000 + i), ...List.generate(6, (i) => 4000 + i)]) {
      await _p.cancel(id: id);
    }
    final s = store.settings;

    // Cuestionario de bienestar por la mañana
    if (s['remMorningOn'] != false) {
      final (h, m) = _hm(s['remMorning'] as String?, '08:30');
      await _daily(1, 'Bienestar de hoy', '30 segundos: sueño, cansancio y dolor para ver tu semáforo.', h, m);
    }
    if (isClient) return;

    // Suplementos
    var i = 0;
    for (final sup in store.list(Col.supplements)) {
      if (sup['enabled'] == false) continue;
      var k = 0;
      for (final t in ((sup['times'] as List?) ?? [])) {
        final (h, m) = _hm('$t', '09:00');
        await _daily(100 + i * 4 + k, '${sup['name']}', 'Toma: ${sup['dose'] ?? ''} ${sup['unit'] ?? ''} ${sup['note'] ?? ''}'.trim(), h, m);
        k++;
        if (k >= 4) break;
      }
      i++;
      if (i >= 24) break;
    }

    // Cuenta atrás de competiciones: D-7, D-3, D-1
    var c = 0;
    final now = DateTime.now();
    for (final comp in store.list(Col.competitions)) {
      if (comp['result'] == true) continue;
      final d = DateTime.tryParse('${comp['date']}');
      if (d == null || d.isBefore(DateTime(now.year, now.month, now.day))) continue;
      for (final (k, days, msg) in [
        (0, 7, 'Falta una semana: empieza la semana de pico y revisa el checklist.'),
        (1, 3, 'Faltan 3 días: descarga, sueño y comida de competición.'),
        (2, 1, 'Mañana compites: equipaje, comida y calentamiento.'),
      ]) {
        await _once(3000 + c * 3 + k, DateTime(d.year, d.month, d.day, 9).subtract(Duration(days: days)), '${comp['name']}', msg);
      }
      c++;
      if (c >= 30) break;
    }

    // Batería de tests
    final td = DateTime.tryParse('${s['testDate'] ?? ''}');
    if (td != null) {
      await _once(4000, DateTime(td.year, td.month, td.day, 9).subtract(const Duration(days: 3)), 'Batería de tests en 3 días', 'Descansa bien y prepara el calentamiento guiado.');
      await _once(4001, DateTime(td.year, td.month, td.day, 8), 'Hoy toca la batería de tests', 'Calentamiento guiado y protocolo en Más > Tests.');
      if (s['testDoneDate'] != s['testDate']) {
        await _once(4002, DateTime(td.year, td.month, td.day, 9).add(const Duration(days: 2)), 'Test pendiente', 'Han pasado 2 días de la fecha de la batería sin registrarla.');
      }
    }
  }
}
