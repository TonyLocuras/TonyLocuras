import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gpx_parser.dart';
import '../../domain/geo.dart';
import '../../domain/time_model.dart';
import '../state.dart';

const activityLabels = {
  Activity.hiking: 'Senderismo',
  Activity.trail: 'Trail running',
  Activity.alpine: 'Alpinismo',
  Activity.caving: 'Espeleo',
};

class RouteStep extends ConsumerStatefulWidget {
  const RouteStep({super.key});
  @override
  ConsumerState<RouteStep> createState() => _RouteStepState();
}

class _RouteStepState extends ConsumerState<RouteStep> {
  String? _error;

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['gpx']);
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      ref.read(routeProvider.notifier).set(parseGpx(utf8.decode(bytes)));
      setState(() => _error = null);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo leer el archivo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider);
    final activity = ref.watch(activityProvider);
    final stats = computeStats(route);
    final time = estimateTime(stats, activity: activity);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _import,
          icon: const Icon(Icons.upload_file),
          label: const Text('Subir GPX'),
        ),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final a in Activity.values)
            ChoiceChip(
              label: Text(activityLabels[a]!),
              selected: a == activity,
              onSelected: (_) => ref.read(activityProvider.notifier).set(a),
            ),
        ]),
        const SizedBox(height: 12),
        if (route.length > 1) ...[
          Wrap(spacing: 16, runSpacing: 8, children: [
            _stat('${stats.km.toStringAsFixed(1)} km', 'DISTANCIA'),
            _stat('${stats.gainM.round()} m', 'D+'),
            _stat('${stats.maxEle.round()} m', 'ALT. MÁX'),
            _stat('${time.inHours} h ${time.inMinutes % 60} min', 'TIEMPO'),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: _profile(route)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: route.length > 1
              ? () => ref.read(stepProvider.notifier).go(2)
              : null,
          child: const Text('Analizar ruta'),
        ),
      ],
    );
  }

  Widget _stat(String v, String l) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(fontSize: 11)),
          ]);

  Widget _profile(List<LatLngEle> r) {
    var km = 0.0;
    final spots = <FlSpot>[FlSpot(0, r.first.ele)];
    for (var i = 1; i < r.length; i++) {
      km += haversineKm(r[i - 1], r[i]);
      spots.add(FlSpot(km, r[i].ele));
    }
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(spots: spots, isCurved: true, dotData: const FlDotData(show: false))
      ],
    ));
  }
}
