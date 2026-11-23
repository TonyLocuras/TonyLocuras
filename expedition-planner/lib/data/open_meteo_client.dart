import 'dart:convert';
import 'package:http/http.dart' as http;

class ForecastException implements Exception {
  final String message;
  ForecastException(this.message);
  @override
  String toString() => 'ForecastException: $message';
}

class HourlyForecast {
  final DateTime time;
  final double tempC, windKmh, uv, precipMm;
  const HourlyForecast(
      this.time, this.tempC, this.windKmh, this.uv, this.precipMm);
}

class OpenMeteoClient {
  final http.Client _c;
  OpenMeteoClient({http.Client? client}) : _c = client ?? http.Client();

  Future<List<HourlyForecast>> fetch(double lat, double lon,
      {int days = 3}) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'hourly': 'temperature_2m,wind_speed_10m,uv_index,precipitation',
      'forecast_days': '$days',
      'timezone': 'auto',
    });
    final res = await _c.get(uri);
    if (res.statusCode != 200) {
      throw ForecastException('HTTP ${res.statusCode}');
    }
    try {
      final h = (jsonDecode(res.body) as Map<String, dynamic>)['hourly']
          as Map<String, dynamic>;
      final t = (h['time'] as List).cast<String>();
      List<double> d(String k) =>
          (h[k] as List).map((e) => (e as num).toDouble()).toList();
      final temp = d('temperature_2m'), wind = d('wind_speed_10m');
      final uv = d('uv_index'), pr = d('precipitation');
      return [
        for (var i = 0; i < t.length; i++)
          HourlyForecast(DateTime.parse(t[i]), temp[i], wind[i], uv[i], pr[i])
      ];
    } catch (e) {
      throw ForecastException('respuesta inválida: $e');
    }
  }
}
