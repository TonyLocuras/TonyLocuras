import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../calc.dart';
import '../store.dart';
import '../test_defs.dart';
import '../theme.dart';

class ProgresoScreen extends StatelessWidget {
  const ProgresoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progreso'),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            tabs: [Tab(text: 'Tests'), Tab(text: 'Carga'), Tab(text: 'Bienestar')],
          ),
        ),
        body: const TabBarView(children: [_TestsTab(), _LoadTab(), _WellTab()]),
      ),
    );
  }
}

double _x(String date) => DateTime.parse(date).millisecondsSinceEpoch / 86400000.0;

String _xLabel(double v) => DateFormat('d/M').format(DateTime.fromMillisecondsSinceEpoch((v * 86400000).round()));

LineChartData _lineData(List<LineChartBarData> bars) {
  return LineChartData(
    lineBarsData: bars,
    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surface2, strokeWidth: 1)),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 7,
          getTitlesWidget: (v, meta) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(_xLabel(v), style: const TextStyle(fontSize: 10, color: AppColors.muted))),
        ),
      ),
    ),
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (spots) => [
          for (final s in spots)
            LineTooltipItem('${_xLabel(s.x)}\n${s.y.toStringAsFixed(1)}', TextStyle(color: s.bar.color ?? Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

LineChartBarData _bar(List<FlSpot> s, Color c) => LineChartBarData(
      spots: s,
      isCurved: false,
      color: c,
      barWidth: 3,
      dotData: const FlDotData(show: true),
    );

class _TestsTab extends StatefulWidget {
  const _TestsTab();
  @override
  State<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<_TestsTab> {
  String sel = 'peak_half';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final def = testById(sel)!;
    final res = st.list(Col.tests).where((t) => t['testId'] == sel).toList()
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    final left = <FlSpot>[], right = <FlSpot>[], single = <FlSpot>[];
    for (final r in res) {
      final x = _x(r['date'] as String);
      if (def.hands) {
        if (r['left'] is num) left.add(FlSpot(x, (r['left'] as num).toDouble()));
        if (r['right'] is num) right.add(FlSpot(x, (r['right'] as num).toDouble()));
      } else if (r['value'] is num) {
        single.add(FlSpot(x, (r['value'] as num).toDouble()));
      }
    }
    final has = left.isNotEmpty || right.isNotEmpty || single.isNotEmpty;
    final last = res.isEmpty ? null : res.last;
    return ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        initialValue: sel,
        decoration: const InputDecoration(labelText: 'Test'),
        items: [for (final t in kTests) DropdownMenuItem(value: t.id, child: Text(t.name))],
        onChanged: (v) => setState(() => sel = v ?? sel),
      ),
      const SizedBox(height: 16),
      if (!has)
        const Padding(padding: EdgeInsets.all(24), child: Text('Sin resultados todavía. Regístralos en Más > Tests.', style: TextStyle(color: AppColors.muted, fontSize: 16)))
      else
        SizedBox(
          height: 260,
          child: LineChart(_lineData([
            if (def.hands) ...[_bar(left, AppColors.left), _bar(right, AppColors.right)] else _bar(single, AppColors.accent),
          ])),
        ),
      if (def.hands && has)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.circle, color: AppColors.left, size: 12),
            Text(' Izquierda   '),
            Icon(Icons.circle, color: AppColors.right, size: 12),
            Text(' Derecha'),
          ]),
        ),
      if (last != null) ...[
        sectionTitle('Último resultado · ${last['date']}'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (def.hands) ...[
                Text('Izq: ${last['left'] ?? '-'} ${def.unit}  ·  Der: ${last['right'] ?? '-'} ${def.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (last['left'] is num && last['right'] is num)
                  Text('Asimetría: ${asymmetryPct((last['left'] as num).toDouble(), (last['right'] as num).toDouble()).toStringAsFixed(1)} %',
                      style: const TextStyle(color: AppColors.muted)),
                if (def.unit == 'kg' && last['left'] is num)
                  Text('Relativa izq: ${relativeStrength((last['left'] as num).toDouble(), st.weightKg).toStringAsFixed(2)} × PC', style: const TextStyle(color: AppColors.muted)),
                if (def.unit == 'kg' && last['right'] is num)
                  Text('Relativa der: ${relativeStrength((last['right'] as num).toDouble(), st.weightKg).toStringAsFixed(2)} × PC', style: const TextStyle(color: AppColors.muted)),
              ] else
                Text('${last['value'] ?? '-'} ${def.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if ('${last['notes'] ?? ''}'.isNotEmpty) Text('${last['notes']}', style: const TextStyle(color: AppColors.muted)),
              Text('Origen: ${last['origin'] ?? 'manual'}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

/// Carga semanal = suma de (EPG × minutos) de las sesiones valoradas de cada semana.
Map<DateTime, double> weeklyLoads(Store st) {
  final out = <DateTime, double>{};
  for (final l in st.list(Col.logs)) {
    final epg = l['epg'];
    final min = l['minutes'];
    if (epg is! num || min is! num) continue;
    final d = DateTime.parse(l['date'] as String);
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    out[monday] = (out[monday] ?? 0) + sessionLoad(epg.toDouble(), min.toDouble());
  }
  return out;
}

class _LoadTab extends StatelessWidget {
  const _LoadTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final w = weeklyLoads(st);
    final weeks = w.keys.toList()..sort();
    if (weeks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sin datos. La carga semanal = EPG × minutos de cada sesión valorada (a los 30 min).', style: TextStyle(color: AppColors.muted, fontSize: 16)),
      );
    }
    final last = weeks.length > 10 ? weeks.sublist(weeks.length - 10) : weeks;
    final cur = w[last.last]!;
    final prev = [for (final k in weeks.where((k) => k.isBefore(last.last)).toList().reversed.take(4)) w[k]!];
    final jump = weeklyLoadJumpPct(cur, prev);
    return ListView(padding: const EdgeInsets.all(16), children: [
      SizedBox(
        height: 260,
        child: BarChart(BarChartData(
          barGroups: [
            for (var i = 0; i < last.length; i++)
              BarChartGroupData(x: i, barRods: [BarChartRodData(toY: w[last[i]]!, color: AppColors.accent, width: 18, borderRadius: BorderRadius.circular(4))]),
          ],
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surface2, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d/M').format(last[v.toInt()]), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
              ),
            ),
          ),
        )),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          title: Text('Semana actual: ${cur.round()} u.a.', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(jump == null ? 'Sin semanas previas para comparar.' : 'Frente a la media de 4 semanas: ${jump >= 0 ? '+' : ''}${jump.toStringAsFixed(0)} %'),
          trailing: jump != null && jump > 30 ? const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 32) : null,
        ),
      ),
      const Text('Carga = EPG × minutos reales (sRPE). Las expediciones se suman cuando se registre su esfuerzo (próxima fase).', style: TextStyle(color: AppColors.muted, fontSize: 12)),
    ]);
  }
}

class _WellTab extends StatelessWidget {
  const _WellTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final w = st.list(Col.wellbeing).where((x) => x['id'] is String && (x['id'] as String).length == 10).toList()
      ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    if (w.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('Sin datos de bienestar todavía.', style: TextStyle(color: AppColors.muted, fontSize: 16)));
    }
    List<FlSpot> s(String k) => [for (final r in w) if (r[k] is num) FlSpot(_x(r['id'] as String), (r[k] as num).toDouble())];
    return ListView(padding: const EdgeInsets.all(16), children: [
      SizedBox(
        height: 260,
        child: LineChart(_lineData([_bar(s('sleepQ'), AppColors.green), _bar(s('fatigue'), AppColors.amber), _bar(s('motivation'), AppColors.left)])),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, color: AppColors.green, size: 12), Text(' Sueño   '),
          Icon(Icons.circle, color: AppColors.amber, size: 12), Text(' Cansancio   '),
          Icon(Icons.circle, color: AppColors.left, size: 12), Text(' Motivación'),
        ]),
      ),
    ]);
  }
}
