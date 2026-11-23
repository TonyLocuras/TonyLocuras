import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expedition_planner/app.dart';
import 'package:expedition_planner/data/open_meteo_client.dart';
import 'package:expedition_planner/domain/geo.dart';
import 'package:expedition_planner/ui/state.dart';

const _body = '{"hourly":{"time":["2026-11-24T08:00","2026-11-24T14:00"],'
    '"temperature_2m":[8.0,14.0],"wind_speed_10m":[10.0,20.0],'
    '"uv_index":[1.0,6.0],"precipitation":[0.0,0.0]}}';

Widget _app() => ProviderScope(
      overrides: [
        forecastClientProvider.overrideWithValue(
            OpenMeteoClient(client: MockClient((_) async => http.Response(_body, 200)))),
      ],
      child: const ExpeditionApp(),
    );

void main() {
  testWidgets('analizar ruta disabled until a route exists', (t) async {
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    final btn = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Analizar ruta'));
    expect(btn.onPressed, isNull);
  });

  testWidgets('step 3 renders pack list and cota de 0', (t) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    final c = ProviderScope.containerOf(t.element(find.byType(ExpeditionApp)));
    c.read(routeProvider.notifier).set(const [
      LatLngEle(36.9, -2.0, 100), LatLngEle(36.95, -2.0, 800), LatLngEle(37.0, -2.0, 1500)]);
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Analizar ruta'));
    await t.pumpAndSettle();
    expect(find.textContaining('cota de 0'), findsOneWidget);
    expect(find.text('Protector solar SPF50+'), findsOneWidget);
  });
}
