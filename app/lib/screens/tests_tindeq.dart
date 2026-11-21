import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../calc.dart';
import '../store.dart';
import '../test_defs.dart';
import '../theme.dart';
import '../tindeq.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tests')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Toca un test para ver el protocolo y registrar el resultado (mejor de 2-3 intentos).', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        for (final t in kTests)
          Card(
            child: ListTile(
              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_last(st, t)),
              trailing: t.tindeq ? const Icon(Icons.bluetooth, color: AppColors.left) : const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestEntry(def: t))),
            ),
          ),
      ]),
    );
  }

  static String _last(Store st, TestDef t) {
    final r = st.list(Col.tests).where((x) => x['testId'] == t.id).toList()..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    if (r.isEmpty) return 'Sin resultados';
    final l = r.last;
    return t.hands ? '${l['date']} · Izq ${l['left'] ?? '-'} · Der ${l['right'] ?? '-'} ${t.unit}' : '${l['date']} · ${l['value'] ?? '-'} ${t.unit}';
  }
}

class TestEntry extends StatefulWidget {
  final TestDef def;
  final double? presetLeft;
  final double? presetRight;
  final String? curveId;
  const TestEntry({super.key, required this.def, this.presetLeft, this.presetRight, this.curveId});
  @override
  State<TestEntry> createState() => _TestEntryState();
}

class _TestEntryState extends State<TestEntry> {
  late double left, right, value;
  DateTime date = DateTime.now();
  final notes = TextEditingController();
  bool bad = false;

  @override
  void initState() {
    super.initState();
    left = widget.presetLeft ?? 0;
    right = widget.presetRight ?? 0;
    value = widget.presetLeft ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    final st = context.read<Store>();
    final step = d.unit == 'kg' ? 0.5 : 1.0;
    return Scaffold(
      appBar: AppBar(title: Text(d.name, style: const TextStyle(fontSize: 18))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(d.protocol))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (p != null) setState(() => date = p);
          },
          icon: const Icon(Icons.event),
          label: Text(DateFormat('d MMM y', 'es').format(date)),
        ),
        const SizedBox(height: 12),
        if (d.hands) ...[
          Stepper2(label: 'Izquierda (${d.unit})', value: left, step: step, max: 999, onChanged: (x) => setState(() => left = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Derecha (${d.unit})', value: right, step: step, max: 999, onChanged: (x) => setState(() => right = x)),
          if (left > 0 && right > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Asimetría ${asymmetryPct(left, right).toStringAsFixed(1)} %'
                  '${d.unit == 'kg' ? ' · relativa izq ${relativeStrength(left, st.weightKg).toStringAsFixed(2)} / der ${relativeStrength(right, st.weightKg).toStringAsFixed(2)} × PC' : ''}',
                  style: const TextStyle(color: AppColors.muted)),
            ),
        ] else
          Stepper2(label: d.unit, value: value, step: step, max: 999, onChanged: (x) => setState(() => value = x)),
        const SizedBox(height: 12),
        SwitchListTile(
          value: bad,
          onChanged: (x) => setState(() => bad = x),
          title: const Text('Fue un mal día (cansancio, mala forma)'),
          subtitle: const Text('Se guarda marcado para no bajar tus cargas por un solo dato.'),
        ),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas (agarre, canto, ángulo...)')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await st.put(Col.tests, {
              'testId': d.id,
              'date': dayKey(date),
              if (d.hands) 'left': left,
              if (d.hands) 'right': right,
              if (!d.hands) 'value': value,
              'badDay': bad,
              'notes': notes.text.trim(),
              'origin': widget.curveId != null ? 'medido' : 'manual',
              if (widget.curveId != null) 'curveId': widget.curveId,
            });
            if (d.id == 'peso' && !d.hands) {
              await st.saveSettings({'weightKg': value});
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('GUARDAR RESULTADO'),
        ),
      ]),
    );
  }
}

/// Pantalla de conexión y medición con el Tindeq Progressor.
class TindeqScreen extends StatelessWidget {
  const TindeqScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TindeqService>();
    final st = context.read<Store>();
    final seg = t.segment.isNotEmpty ? t.segment : t.all;
    final show = seg.length > 800 ? seg.sublist(seg.length - 800) : seg;
    return Scaffold(
      appBar: AppBar(title: const Text('Tindeq Progressor')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: Icon(t.connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: t.connected ? AppColors.left : AppColors.muted, size: 32),
            title: Text(t.status),
            subtitle: const Text('Cierra la app oficial del Tindeq: solo admite una conexión.'),
          ),
        ),
        Row(children: [
          Expanded(
            child: FilledButton(onPressed: t.connected ? t.disconnect : t.connect, child: Text(t.connected ? 'DESCONECTAR' : 'CONECTAR')),
          ),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(onPressed: t.connected ? t.tare : null, child: const Text('TARA'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 72)),
              onPressed: t.connected ? (t.streaming ? t.stop : t.start) : null,
              child: Text(t.streaming ? 'PARAR' : 'MEDIR'),
            ),
          ),
        ]),
        sectionTitle('En directo'),
        Center(
          child: Column(children: [
            Text('${t.lastKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppColors.accent)),
            Text('${nFromKg(t.lastKg).toStringAsFixed(0)} N', style: const TextStyle(fontSize: 28, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _stat('PICO', '${t.peakKg.toStringAsFixed(1)} kg', '${nFromKg(t.peakKg).toStringAsFixed(0)} N')),
          Expanded(child: _stat('MEDIA', '${t.meanKg.toStringAsFixed(1)} kg', '${nFromKg(t.meanKg).toStringAsFixed(0)} N')),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: show.length < 2
              ? const Center(child: Text('La curva aparecerá al medir', style: TextStyle(color: AppColors.muted)))
              : LineChart(LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final s in show) FlSpot(s.t, s.kg)],
                      color: AppColors.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surface2)),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                  ),
                  lineTouchData: const LineTouchData(enabled: false),
                )),
        ),
        if (t.segment.length > 10) ...[
          Text('Serie detectada: ${t.segment.last.t - t.segment.first.t > 0 ? (t.segment.last.t - t.segment.first.t).toStringAsFixed(1) : '0'} s · '
              'tiempo hasta el pico ${timeToPeak(t.segment).toStringAsFixed(2)} s · RFD(200 ms) ${rfd(t.segment).toStringAsFixed(0)} kg/s',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in ['peak_half', 'peak_open', 'peak_full', 'pinza', 'romo'])
              for (final side in ['Izq', 'Der'])
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () async {
                    final def = testById(id)!;
                    final curve = await st.put(Col.curves, {
                      'testId': id,
                      'side': side,
                      'peakKg': t.peakKg,
                      'samples': [for (final s in t.segment) [double.parse(s.t.toStringAsFixed(4)), double.parse(s.kg.toStringAsFixed(3))]],
                    });
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestEntry(
                            def: def,
                            presetLeft: side == 'Izq' ? t.peakKg : 0,
                            presetRight: side == 'Der' ? t.peakKg : 0,
                            curveId: curve['id'] as String,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text('${testById(id)!.name.split(' 20').first} $side'),
                ),
          ]),
        ],
        const SizedBox(height: 12),
        const Text(
          'Experimental: el protocolo Bluetooth está escrito de memoria y se verifica con tu Progressor real. Si no conecta, usa la entrada manual en Tests.',
          style: TextStyle(color: AppColors.amber, fontSize: 12),
        ),
      ]),
    );
  }

  static Widget _stat(String l, String kg, String n) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(l, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
            Text(kg, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            Text(n, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}
