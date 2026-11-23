import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/open_meteo_client.dart';
import '../../domain/geo.dart';
import '../../domain/packing.dart';
import '../../domain/time_model.dart';
import '../../domain/weather.dart';
import '../state.dart';

class AnalysisStep extends ConsumerStatefulWidget {
  const AnalysisStep({super.key});
  @override
  ConsumerState<AnalysisStep> createState() => _AnalysisStepState();
}

class _AnalysisStepState extends ConsumerState<AnalysisStep> {
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider);
    final activity = ref.watch(activityProvider);
    final fc = ref.watch(forecastProvider);
    return fc.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No se pudo obtener la previsión: $e'))),
      data: (all) => _content(context, route, activity, all),
    );
  }

  Widget _content(BuildContext context, List<LatLngEle> route, Activity activity,
      List<HourlyForecast> all) {
    if (all.isEmpty || route.isEmpty) {
      return const Center(child: Text('Sin datos de previsión.'));
    }
    final days = {for (final h in all) DateTime(h.time.year, h.time.month, h.time.day)}.toList()
      ..sort();
    final d = days[_day.clamp(0, days.length - 1)];
    final hours = all
        .where((h) => h.time.year == d.year && h.time.month == d.month && h.time.day == d.day)
        .toList();
    final stats = computeStats(route);
    final baseEle = route.first.ele;
    final time = estimateTime(stats, activity: activity);
    final minT = hours.map((h) => h.tempC).reduce((a, b) => a < b ? a : b);
    final maxUvBase = hours.map((h) => h.uv).reduce((a, b) => a > b ? a : b);
    final maxWind = hours.map((h) => h.windKmh).reduce((a, b) => a > b ? a : b);
    final rain = hours.fold<double>(0, (s, h) => s + h.precipMm);
    final minTop = windChill(tempAtAltitude(minT, baseEle, stats.maxEle), maxWind);
    final uvTop = uvAtAltitude(maxUvBase, stats.maxEle, eleBaseM: baseEle);
    final pack = buildPackList(PackContext(activity, time, minTop, uvTop, maxWind, rain));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, children: [
        for (var i = 0; i < days.length; i++)
          ChoiceChip(
            label: Text('${days[i].day}/${days[i].month}'),
            selected: i == _day,
            onSelected: (_) => setState(() => _day = i),
          ),
      ]),
      const SizedBox(height: 16),
      Text('A ${stats.maxEle.round()} m',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text('Mínima con viento: ${minTop.toStringAsFixed(1)} °C'),
      Text('UV máx: ${uvTop.toStringAsFixed(1)}'),
      Text('Piel tipo II: ${burnMinutes(uvTop).round()} min hasta quemarse'),
      Text('cota de 0 °C ≈ ${freezingLevelM(minT, baseEle).round()} m'),
      const SizedBox(height: 16),
      const Text('TU MOCHILA PARA ESTA RUTA',
          style: TextStyle(fontWeight: FontWeight.w800)),
      for (final p in pack)
        ListTile(leading: const Icon(Icons.check_box), title: Text(p), dense: true),
    ]);
  }
}
