import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tonylocuras_entreno/auth.dart';
import 'package:tonylocuras_entreno/main.dart';
import 'package:tonylocuras_entreno/store.dart';
import 'package:tonylocuras_entreno/tindeq.dart';

/// Prueba de humo: arranca la app en modo local, navega por todas las pestañas
/// y abre las pantallas principales sin que salte ninguna excepción.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('arranca y recorre las secciones del atleta', (t) async {
    SharedPreferences.setMockInitialValues({});
    late AuthController auth;
    await t.runAsync(() async {
      await initializeDateFormatting('es');
      auth = AuthController();
      await auth.init();
    });
    expect(auth.loggedIn, isTrue);

    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => TindeqService()),
      ],
      child: const TonyApp(),
    ));
    await t.pump(const Duration(milliseconds: 300));

    // datos de ejemplo para que las pantallas tengan contenido
    final st = auth.store!;
    await t.runAsync(() async {
      await st.put(Col.plan, {
        'date': dayKey(DateTime.now()),
        'title': 'Fuerza máxima',
        'exercises': [
          {'name': 'Suspensión 20 mm', 'type': 'hang', 'sets': 2, 'workS': 10, 'restS': 60, 'reps': 1},
          {'name': 'Dominadas', 'type': 'gym', 'sets': 3, 'reps': 5, 'restS': 90},
        ],
      });
      await st.put(Col.tests, {'testId': 'peak_half', 'date': dayKey(DateTime.now()), 'left': 50.0, 'right': 48.0});
      await st.put(Col.competitions, {'name': 'Andaluza Jaén', 'date': dayKey(DateTime.now().add(const Duration(days: 9))), 'priority': 'B', 'result': false});
    });
    await t.pump(const Duration(milliseconds: 300));

    for (final label in ['Plan', 'Progreso', 'Nutrición', 'Más', 'Hoy']) {
      await t.tap(find.text(label).last);
      await t.pump(const Duration(milliseconds: 400));
      expect(tester(t), isNull, reason: 'excepción al abrir $label');
    }
    expect(find.text('Fuerza máxima'), findsWidgets);

    // pestañas internas de Progreso y Nutrición
    await t.tap(find.text('Progreso').last);
    await t.pump(const Duration(milliseconds: 300));
    for (final tab in ['Carga', 'Bienestar', 'Tests']) {
      await t.tap(find.text(tab).last);
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.tap(find.text('Nutrición').last);
    await t.pump(const Duration(milliseconds: 300));
    for (final tab in ['Comidas', 'Alimentos', 'Suplementos', 'Hoy']) {
      await t.tap(find.text(tab).last);
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(tester(t), isNull);
  });
}

Object? tester(WidgetTester t) => t.takeException();
