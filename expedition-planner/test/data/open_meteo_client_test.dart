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
  test('malformed body throws', () async {
    final mock = MockClient((_) async => http.Response('{"x":1}', 200));
    expect(() => OpenMeteoClient(client: mock).fetch(0, 0),
        throwsA(isA<ForecastException>()));
  });
}
