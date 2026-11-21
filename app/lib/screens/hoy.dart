import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../calc.dart';
import '../store.dart';
import '../theme.dart';
import 'runner.dart';
import 'wellbeing.dart';

class HoyScreen extends StatelessWidget {
  const HoyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final now = DateTime.now();
    final tl = st.trafficFor(now);
    final style = trafficStyle(tl.color);
    final hasWell = st.wellbeingFor(now) != null;
    final sessions = st.planFor(now);
    final pending = st.list(Col.logs).where((l) => l['epg'] == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TONYLOCURAS', style: TextStyle(letterSpacing: 2, color: AppColors.accent, fontWeight: FontWeight.w900)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(DateFormat('EEEE d MMMM', 'es').format(now).toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        // Semáforo
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              builder: (_) => _WhySheet(tl: tl, hasWell: hasWell),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: style.color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: style.color, width: 3)),
                  child: Icon(style.icon, color: style.color, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hasWell ? '${style.label} · ${tl.score}' : 'SIN DATOS DE HOY',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: hasWell ? style.color : AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(hasWell ? _advice(tl.color) : 'Rellena el bienestar para ver el semáforo.',
                        style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    const Text('Toca para ver por qué', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        if (!hasWell || true)
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WellbeingScreen())),
            icon: const Icon(Icons.edit_note),
            label: Text(hasWell ? 'EDITAR BIENESTAR DE HOY' : 'RELLENAR BIENESTAR (30 s)'),
          ),
        sectionTitle('Sesión de hoy'),
        if (sessions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No hay sesión planificada para hoy. Añádela en Plan.', style: TextStyle(color: AppColors.muted, fontSize: 16)),
            ),
          ),
        for (final s in sessions) _SessionCard(s: s, tl: tl),
        if (pending.isNotEmpty) sectionTitle('Pendiente de valorar'),
        for (final l in pending) _EpgCard(log: l),
        sectionTitle('Próximo hito'),
        const _NextMilestone(),
      ]),
    );
  }

  static String _advice(String c) => switch (c) {
        'green' => 'Haz la sesión tal cual.',
        'amber' => 'Baja intensidad o volumen.',
        _ => 'Mejor técnica, recuperación o descanso. Tú decides.',
      };
}

class _WhySheet extends StatelessWidget {
  final TrafficResult tl;
  final bool hasWell;
  const _WhySheet({required this.tl, required this.hasWell});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('¿Por qué este color?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(hasWell ? 'Parte de 100 puntos.' : 'Sin cuestionario de hoy; solo cuentan los datos que existen.'),
        const SizedBox(height: 8),
        if (tl.reasons.isEmpty) const Text('Ninguna regla se ha activado.'),
        for (final r in tl.reasons) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $r')),
        const SizedBox(height: 12),
        const Text('Reglas provisionales: editables en Más > Ajustes.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final TrafficResult tl;
  const _SessionCard({required this.s, required this.tl});
  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    final n = ((s['exercises'] as List?) ?? []).length;
    final done = st.list(Col.logs).any((l) => l['planId'] == s['id']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s['title'] as String? ?? 'Sesión', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            if (done) const Chip(label: Text('HECHA')),
          ]),
          Text('${(s['time'] ?? '') == '' ? '' : '${s['time']} · '}$n ejercicios${(s['phase'] ?? '') == '' ? '' : ' · ${s['phase']}'}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final e in ((s['exercises'] as List?) ?? []).take(6))
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• ${(e as Map)['name']}')),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 64)),
            onPressed: n == 0
                ? null
                : () async {
                    if (tl.color == 'red') {
                      final go = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Semáforo en rojo'),
                          content: Text('Recomendación: técnica, recuperación o descanso.\n\n${tl.reasons.join('\n')}'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NO ENTRENAR')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('ENTRENAR IGUAL')),
                          ],
                        ),
                      );
                      if (go != true) return;
                      await st.put(Col.wellbeing, {...?st.wellbeingFor(DateTime.now()), 'id': dayKey(DateTime.now()), 'ignoredRed': true});
                    }
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RunnerScreen(session: s)));
                    }
                  },
            icon: const Icon(Icons.play_arrow, size: 30),
            label: const Text('EMPEZAR SESIÓN'),
          ),
        ]),
      ),
    );
  }
}

class _EpgCard extends StatefulWidget {
  final Map<String, dynamic> log;
  const _EpgCard({required this.log});
  @override
  State<_EpgCard> createState() => _EpgCardState();
}

class _EpgCardState extends State<_EpgCard> {
  double epg = 7;
  double epl = 7;
  @override
  Widget build(BuildContext context) {
    final ended = DateTime.tryParse('${widget.log['endedAt']}');
    final mins = ended == null ? 0 : DateTime.now().difference(ended).inMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.log['title']} · ${widget.log['date']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(mins >= 30 ? 'Ya puedes valorarla (han pasado $mins min).' : 'Valórala a partir de los 30 min (faltan ${30 - mins}).',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Stepper2(label: 'EPG global (1-10)', value: epg, min: 1, max: 10, onChanged: (x) => setState(() => epg = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'EPL local (1-10)', value: epl, min: 1, max: 10, onChanged: (x) => setState(() => epl = x)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<Store>().put(Col.logs, {...widget.log, 'epg': epg, 'epl': epl}),
            child: const Text('GUARDAR VALORACIÓN'),
          ),
        ]),
      ),
    );
  }
}

class _NextMilestone extends StatelessWidget {
  const _NextMilestone();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final today = dayKey(DateTime.now());
    final comps = st.list(Col.competitions).where((c) => (c['date'] ?? '').toString().compareTo(today) >= 0 && c['result'] != true).toList()
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    if (comps.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Sin hitos. Añade competiciones en Más.', style: TextStyle(color: AppColors.muted))));
    }
    final c = comps.first;
    final d = DateTime.parse(c['date'] as String);
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.emoji_events, color: AppColors.accent, size: 36),
        title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${c['place'] ?? ''} · ${DateFormat('d MMM', 'es').format(d)}'),
        trailing: Text(days == 0 ? 'HOY' : 'D-$days', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.accent)),
      ),
    );
  }
}
