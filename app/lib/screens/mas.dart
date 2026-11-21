import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../calc.dart';
import '../notifs.dart';
import '../store.dart';
import '../theme.dart';
import 'ai_screens.dart';
import 'tests_tindeq.dart';

class MasScreen extends StatelessWidget {
  const MasScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String sub, Widget page) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(i, color: AppColors.accent, size: 30),
            title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        item(Icons.emoji_events, 'Competiciones', 'Campeonato de Andalucía, resultados y calendario', const CompeticionesScreen()),
        item(Icons.fitness_center, 'Tests', 'Batería de tests y resultados', const TestsScreen()),
        item(Icons.bluetooth, 'Tindeq', 'Conectar y medir con el Progressor', const TindeqScreen()),
        item(Icons.terrain, 'Expediciones', 'Registro y recuperación', const ExpedicionesScreen()),
        item(Icons.auto_awesome, 'Importar con IA', 'PDF o foto: plan, estudio, etiqueta, analítica...', const AiImportScreen()),
        item(Icons.biotech, 'Estudios y referencias', 'Criterios de recuperación y valores del estudio', const EstudiosScreen()),
        item(Icons.settings, 'Ajustes y cuenta', 'Peso, semáforo, recordatorios, copia, sesión', const AjustesScreen()),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Competiciones

class CompeticionesScreen extends StatelessWidget {
  const CompeticionesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final all = st.list(Col.competitions)..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    final and = (st.settings['andalucia'] as Map?) ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Competiciones')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Competición', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _editAndalucia(context, st),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 3)),
                  child: Text(and['pos'] == null ? '-' : '${and['pos']}º', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.accent)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Campeonato de Andalucía · Bloque absoluta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(and['points'] == null ? 'Clasificación general · toca para editar' : 'Puntos: ${and['points']} · toca para editar', style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Añade las pruebas del circuito (la del domingo, la de Jaén y las que quedan) con «Competición».', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          ),
        for (final c in all)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text([
                if ('${c['date'] ?? ''}'.isNotEmpty) DateFormat('d MMM y', 'es').format(DateTime.parse(c['date'] as String)),
                if ('${c['place'] ?? ''}'.isNotEmpty) '${c['place']}',
                'Prioridad ${c['priority'] ?? 'B'}',
                if (c['result'] == true) 'Puesto ${c['puesto'] ?? '-'} · ${c['tops'] ?? '-'}T ${c['zonas'] ?? '-'}Z',
              ].join(' · ')),
              trailing: c['result'] == true ? const Icon(Icons.check_circle, color: AppColors.green) : const Icon(Icons.schedule, color: AppColors.muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompEditor(comp: c))),
            ),
          ),
      ]),
    );
  }

  Future<void> _editAndalucia(BuildContext context, Store st) async {
    final and = Map<String, dynamic>.from((st.settings['andalucia'] as Map?) ?? {});
    final pos = TextEditingController(text: '${and['pos'] ?? ''}');
    final pts = TextEditingController(text: '${and['points'] ?? ''}');
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clasificación general'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: pos, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Puesto actual')),
          const SizedBox(height: 12),
          TextField(controller: pts, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Puntos (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              await st.saveSettings({
                'andalucia': {'pos': int.tryParse(pos.text), 'points': double.tryParse(pts.text.replaceAll(',', '.'))},
              });
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}

class CompEditor extends StatefulWidget {
  final Map<String, dynamic>? comp;
  const CompEditor({super.key, this.comp});
  @override
  State<CompEditor> createState() => _CompEditorState();
}

class _CompEditorState extends State<CompEditor> {
  final name = TextEditingController();
  final place = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  String priority = 'B';
  String circuit = 'Andalucía bloque absoluta';
  bool played = false;
  double puesto = 0, partic = 0, tops = 0, zonas = 0, attTop = 0, attZone = 0, points = 0;
  double wellB = 7, energyB = 7, nervesB = 5;
  final good = TextEditingController();
  final bad = TextEditingController();
  final learn = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.comp;
    if (c != null) {
      name.text = '${c['name'] ?? ''}';
      place.text = '${c['place'] ?? ''}';
      notes.text = '${c['notes'] ?? ''}';
      date = DateTime.tryParse('${c['date']}') ?? date;
      priority = '${c['priority'] ?? 'B'}';
      circuit = '${c['circuit'] ?? circuit}';
      played = c['result'] == true;
      double g(String k) => (c[k] as num?)?.toDouble() ?? 0;
      puesto = g('puesto');
      partic = g('participantes');
      tops = g('tops');
      zonas = g('zonas');
      attTop = g('intentosTop');
      attZone = g('intentosZona');
      points = g('puntos');
      good.text = '${c['bien'] ?? ''}';
      bad.text = '${c['mal'] ?? ''}';
      learn.text = '${c['aprendizajes'] ?? ''}';
    } else {
      name.text = 'Campeonato de Andalucía de bloque';
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.comp == null ? 'Nueva competición' : 'Competición'), actions: [
        if (widget.comp != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await st.remove(Col.competitions, widget.comp!['id'] as String);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre (ej. Andaluza de bloque · Jaén)')),
        const SizedBox(height: 12),
        TextField(controller: place, decoration: const InputDecoration(labelText: 'Lugar')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (p != null) setState(() => date = p);
          },
          icon: const Icon(Icons.event),
          label: Text(DateFormat('EEE d MMM y', 'es').format(date)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: priority,
          decoration: const InputDecoration(labelText: 'Prioridad'),
          items: const [
            DropdownMenuItem(value: 'A', child: Text('A · objetivo principal')),
            DropdownMenuItem(value: 'B', child: Text('B · importante')),
            DropdownMenuItem(value: 'C', child: Text('C · preparación')),
          ],
          onChanged: (x) => setState(() => priority = x ?? priority),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: circuit,
          decoration: const InputDecoration(labelText: 'Circuito'),
          items: const [
            DropdownMenuItem(value: 'Andalucía bloque absoluta', child: Text('Andalucía · bloque absoluta')),
            DropdownMenuItem(value: 'Andalucía cuerda absoluta', child: Text('Andalucía · cuerda absoluta')),
            DropdownMenuItem(value: 'Campeonato de España', child: Text('Campeonato de España')),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          onChanged: (x) => setState(() => circuit = x ?? circuit),
        ),
        SwitchListTile(value: played, onChanged: (x) => setState(() => played = x), title: const Text('Ya disputada (registrar resultado)')),
        if (played) ...[
          Stepper2(label: 'Puesto', value: puesto, max: 999, onChanged: (x) => setState(() => puesto = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Participantes', value: partic, max: 999, onChanged: (x) => setState(() => partic = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Puntos', value: points, step: 1, max: 9999, onChanged: (x) => setState(() => points = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Tops', value: tops, max: 99, onChanged: (x) => setState(() => tops = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Zonas', value: zonas, max: 99, onChanged: (x) => setState(() => zonas = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Intentos hasta tops', value: attTop, max: 999, onChanged: (x) => setState(() => attTop = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Intentos hasta zonas', value: attZone, max: 999, onChanged: (x) => setState(() => attZone = x)),
          sectionTitle('Diario post-competición'),
          Stepper2(label: 'Energía (1-10)', value: energyB, min: 1, max: 10, onChanged: (x) => setState(() => energyB = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Nervios (1-10)', value: nervesB, min: 1, max: 10, onChanged: (x) => setState(() => nervesB = x)),
          const SizedBox(height: 8),
          TextField(controller: good, maxLines: 2, decoration: const InputDecoration(labelText: 'Qué salió bien')),
          const SizedBox(height: 8),
          TextField(controller: bad, maxLines: 2, decoration: const InputDecoration(labelText: 'Qué salió mal')),
          const SizedBox(height: 8),
          TextField(controller: learn, maxLines: 2, decoration: const InputDecoration(labelText: 'Aprendizajes para entrenar')),
        ],
        const SizedBox(height: 8),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await st.put(Col.competitions, {
              'id': widget.comp?['id'],
              'name': name.text.trim(),
              'place': place.text.trim(),
              'date': dayKey(date),
              'priority': priority,
              'circuit': circuit,
              'result': played,
              if (played) ...{
                'puesto': puesto.toInt(),
                'participantes': partic.toInt(),
                'puntos': points,
                'tops': tops.toInt(),
                'zonas': zonas.toInt(),
                'intentosTop': attTop.toInt(),
                'intentosZona': attZone.toInt(),
                'energia': energyB,
                'nervios': nervesB,
                'bien': good.text.trim(),
                'mal': bad.text.trim(),
                'aprendizajes': learn.text.trim(),
              },
              'notes': notes.text.trim(),
            });
            await Notifs.instance.rescheduleAll(st);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('GUARDAR'),
        ),
        if (widget.comp != null && !played) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompChecklistScreen(comp: widget.comp!))),
            icon: const Icon(Icons.checklist),
            label: const Text('CHECKLIST DE COMPETICIÓN'),
          ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- Expediciones

class ExpedicionesScreen extends StatelessWidget {
  const ExpedicionesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final all = st.list(Col.expeditions)..sort((a, b) => '${b['start']}'.compareTo('${a['start']}'));
    return Scaffold(
      appBar: AppBar(title: const Text('Expediciones')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Expedición', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Al registrar el fin de una expedición, el semáforo descuenta puntos durante las horas siguientes (regla PROVISIONAL de 48 h, editable en Ajustes) hasta que importes el estudio.',
              style: TextStyle(color: AppColors.amber),
            ),
          ),
        ),
        for (final e in all)
          Card(
            child: ListTile(
              title: Text('${e['name'] ?? 'Expedición'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_fmt(e['start'])} → ${_fmt(e['end'])}\nComida: ${e['food'] ?? '-'} · Agua: ${e['water'] ?? '-'}'),
              isThreeLine: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpEditor(exp: e))),
            ),
          ),
      ]),
    );
  }

  static String _fmt(dynamic s) {
    final d = DateTime.tryParse('$s');
    return d == null ? 'sin fin' : DateFormat('d MMM HH:mm', 'es').format(d);
  }
}

class ExpEditor extends StatefulWidget {
  final Map<String, dynamic>? exp;
  const ExpEditor({super.key, this.exp});
  @override
  State<ExpEditor> createState() => _ExpEditorState();
}

class _ExpEditorState extends State<ExpEditor> {
  final name = TextEditingController();
  final notes = TextEditingController();
  DateTime start = DateTime.now();
  DateTime? end;
  String food = 'Ninguna';
  String water = 'Ninguna';
  double sleepH = 0, rpe = 8, wBefore = 0, wAfter = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.exp;
    if (e != null) {
      name.text = '${e['name'] ?? ''}';
      notes.text = '${e['notes'] ?? ''}';
      start = DateTime.tryParse('${e['start']}') ?? start;
      end = DateTime.tryParse('${e['end']}');
      food = '${e['food'] ?? 'Ninguna'}';
      water = '${e['water'] ?? 'Ninguna'}';
      sleepH = (e['sleepH'] as num?)?.toDouble() ?? 0;
      rpe = (e['rpe'] as num?)?.toDouble() ?? 8;
      wBefore = (e['weightBefore'] as num?)?.toDouble() ?? 0;
      wAfter = (e['weightAfter'] as num?)?.toDouble() ?? 0;
    } else {
      wBefore = context.read<Store>().weightKg;
    }
  }

  Future<DateTime?> _pick(DateTime init) async {
    final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    final fmt = DateFormat('EEE d MMM HH:mm', 'es');
    final opts = ['Ninguna', 'Algo', 'Con normalidad'];
    return Scaffold(
      appBar: AppBar(title: const Text('Expedición'), actions: [
        if (widget.exp != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await st.remove(Col.expeditions, widget.exp!['id'] as String);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre / lugar')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await _pick(start);
            if (d != null) setState(() => start = d);
          },
          icon: const Icon(Icons.play_arrow),
          label: Text('Inicio: ${fmt.format(start)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await _pick(end ?? DateTime.now());
            if (d != null) setState(() => end = d);
          },
          icon: const Icon(Icons.flag),
          label: Text(end == null ? 'Fin: sin registrar' : 'Fin: ${fmt.format(end!)}'),
        ),
        if (end != null) Text('Duración: ${(end!.difference(start).inMinutes / 60).toStringAsFixed(1)} h', style: const TextStyle(color: AppColors.muted)),
        sectionTitle('Comida y agua'),
        Wrap(spacing: 8, children: [for (final o in opts) ChoiceChip(label: Text('Comida: $o'), selected: food == o, onSelected: (_) => setState(() => food = o))]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [for (final o in opts) ChoiceChip(label: Text('Agua: $o'), selected: water == o, onSelected: (_) => setState(() => water = o))]),
        const SizedBox(height: 12),
        Stepper2(label: 'Horas de sueño', value: sleepH, step: 0.5, max: 100, onChanged: (x) => setState(() => sleepH = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Esfuerzo (1-10)', value: rpe, min: 1, max: 10, onChanged: (x) => setState(() => rpe = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Peso antes (kg)', value: wBefore, step: 0.1, max: 200, onChanged: (x) => setState(() => wBefore = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Peso después (kg)', value: wAfter, step: 0.1, max: 200, onChanged: (x) => setState(() => wAfter = x)),
        if (wBefore > 0 && wAfter > 0)
          Text('Diferencia: ${(wAfter - wBefore).toStringAsFixed(1)} kg', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Ambiente, carga transportada, notas')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await st.put(Col.expeditions, {
              'id': widget.exp?['id'],
              'name': name.text.trim(),
              'start': start.toIso8601String(),
              'end': end?.toIso8601String(),
              'food': food,
              'water': water,
              'sleepH': sleepH,
              'rpe': rpe,
              'weightBefore': wBefore,
              'weightAfter': wAfter,
              'notes': notes.text.trim(),
            });
            if (context.mounted) {
              Navigator.pop(context);
              if (end != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => RecoveryScreen(expedition: {'start': start.toIso8601String(), 'end': end!.toIso8601String(), 'weightBefore': wBefore, 'weightAfter': wAfter, 'food': food, 'water': water})));
              }
            }
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Vuelta de expedición

class RecoveryScreen extends StatelessWidget {
  final Map<String, dynamic> expedition;
  const RecoveryScreen({super.key, required this.expedition});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final start = DateTime.tryParse('${expedition['start']}');
    final end = DateTime.tryParse('${expedition['end']}');
    final hours = (start != null && end != null) ? end.difference(start).inMinutes / 60 : 0.0;
    final wb = (expedition['weightBefore'] as num?)?.toDouble() ?? 0;
    final wa = (expedition['weightAfter'] as num?)?.toDouble() ?? 0;
    final lost = (wb > 0 && wa > 0 && wb > wa) ? wb - wa : null;
    final steps = returnProtocol(hours: hours, weightKg: wa > 0 ? wa : st.weightKg, weightLostKg: lost);
    final studies = st.list(Col.studies);
    final rules = <String>[
      for (final sd in studies)
        for (final r in ((sd['recovery_rules'] as List?) ?? [])) '${(r as Map)['text']}${r['page'] != null ? ' (${sd['title']}, p. ${(r['page'] as num).toInt()})' : ' (${sd['title']})'}'
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Vuelta de expedición')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Duración ${hours.toStringAsFixed(0)} h${lost != null ? ' · peso perdido ${lost.toStringAsFixed(1)} kg' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (rules.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('PROVISIONAL: pauta general sin respaldo del estudio. Importa tu estudio en Importar con IA y aquí aparecerán sus criterios con su página.', style: TextStyle(color: AppColors.amber)),
            ),
          ),
        for (final r in rules) Card(child: ListTile(leading: const Icon(Icons.menu_book, color: AppColors.accent), title: Text(r, style: const TextStyle(fontSize: 14)))),
        sectionTitle('Pauta escalonada (provisional)'),
        for (final x in steps)
          Card(
            child: ListTile(
              title: Text(x.when, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent)),
              subtitle: Text(x.text, style: const TextStyle(fontSize: 15)),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Estudios

class EstudiosScreen extends StatelessWidget {
  const EstudiosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final studies = st.list(Col.studies);
    return Scaffold(
      appBar: AppBar(title: const Text('Estudios y referencias')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (studies.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Aún no has importado ningún estudio. Hazlo en Importar con IA > Estudio biomecánico. Sus criterios alimentan la recuperación tras expediciones y las referencias por nivel.', style: TextStyle(color: AppColors.muted, fontSize: 16))),
        for (final s in studies)
          Card(
            child: ExpansionTile(
              title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${((s['values'] as List?) ?? []).length} valores · ${((s['references'] as List?) ?? []).length} referencias · ${((s['recovery_rules'] as List?) ?? []).length} criterios'),
              children: [
                Padding(padding: const EdgeInsets.all(12), child: Text('${s['summary'] ?? ''}')),
                for (final r in ((s['recovery_rules'] as List?) ?? [])) ListTile(dense: true, title: Text('${(r as Map)['text']}'), subtitle: r['page'] == null ? null : Text('p. ${r['page']}')),
                TextButton.icon(onPressed: () => st.remove(Col.studies, s['id'] as String), icon: const Icon(Icons.delete_outline), label: const Text('BORRAR ESTUDIO')),
              ],
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Checklist de competición

class CompChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> comp;
  const CompChecklistScreen({super.key, required this.comp});
  @override
  State<CompChecklistScreen> createState() => _CompChecklistScreenState();
}

class _CompChecklistScreenState extends State<CompChecklistScreen> {
  static const defaults = {
    'Equipaje': ['Pies de gato', 'Magnesio y bolsa', 'Cepillo', 'Cinta', 'Ropa de competición', 'Ropa de abrigo', 'Documentación / licencia', 'Agua y electrolitos', 'Comida del día'],
    'Calentamiento': ['Movilidad general 5 min', 'Activación hombro y escápula', 'Dedos: suspensiones suaves 50-70 %', 'Bloques fáciles progresivos', 'Bloques cercanos a tu límite (2-3)'],
    'D-7 / D-3 / D-1': ['D-7: semana de pico, mantén intensidad, baja volumen', 'D-3: descarga y sueño', 'D-1: viaje, comida conocida, equipaje listo'],
  };
  late Map<String, dynamic> state;

  @override
  void initState() {
    super.initState();
    state = Map<String, dynamic>.from((widget.comp['checklist'] as Map?) ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.comp['name']}', style: const TextStyle(fontSize: 18))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in defaults.entries) ...[
          sectionTitle(e.key),
          for (final item in e.value)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state[item] == true,
              onChanged: (v) async {
                setState(() => state[item] = v ?? false);
                await st.put(Col.competitions, {...widget.comp, 'checklist': state});
              },
              title: Text(item),
            ),
        ],
        sectionTitle('Nutrición del día'),
        const Text('Usa la pestaña Nutrición y Suplementos para tus comidas y tomas. Hora de aislamiento y rondas: anótalas en las notas de la competición.', style: TextStyle(color: AppColors.muted)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Ajustes (se redefine abajo)

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final rules = st.rules;
    double s(String k, double d) => (st.settings[k] as num?)?.toDouble() ?? d;

    Future<void> setRule(TrafficRule r) async {
      await st.saveSettings({
        'rules': [for (final x in rules) (x.id == r.id ? r : x).toJson()],
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        sectionTitle('Datos corporales'),
        Stepper2(label: 'Peso (kg)', value: st.weightKg, step: 0.1, min: 30, max: 200, onChanged: (x) => st.saveSettings({'weightKg': double.parse(x.toStringAsFixed(1))})),
        const SizedBox(height: 8),
        Stepper2(label: 'Altura (cm)', value: s('heightCm', 173), min: 100, max: 230, onChanged: (x) => st.saveSettings({'heightCm': x})),
        const SizedBox(height: 8),
        Stepper2(label: 'Edad', value: s('age', 19), min: 10, max: 90, onChanged: (x) => st.saveSettings({'age': x.toInt()})),
        sectionTitle('Semáforo (reglas PROVISIONALES, editables)'),
        Stepper2(label: 'Verde desde', value: s('greenFrom', 75), step: 5, min: 10, max: 100, onChanged: (x) => st.saveSettings({'greenFrom': x})),
        const SizedBox(height: 8),
        Stepper2(label: 'Ámbar desde', value: s('amberFrom', 50), step: 5, min: 0, max: 95, onChanged: (x) => st.saveSettings({'amberFrom': x})),
        const SizedBox(height: 8),
        for (final r in rules)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: r.enabled,
                  onChanged: (x) => setRule(r.copyWith(enabled: x)),
                  title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Stepper2(label: 'Umbral', value: r.threshold, step: r.field == 'expH' ? 6 : (r.field == 'sleepH' ? 0.5 : 1), max: 200, onChanged: (x) => setRule(r.copyWith(threshold: x))),
                const SizedBox(height: 8),
                Stepper2(label: 'Resta (puntos)', value: r.penalty, step: 5, max: 100, onChanged: (x) => setRule(r.copyWith(penalty: x))),
              ]),
            ),
          ),
        OutlinedButton(
          onPressed: () => st.saveSettings({'rules': [for (final r in defaultRules) r.toJson()]}),
          child: const Text('RESTAURAR REGLAS POR DEFECTO'),
        ),
        sectionTitle('Tindeq'),
        Stepper2(label: 'Umbral de detección (kg)', value: s('tindeqThresholdKg', 1), step: 0.5, min: 0.5, max: 20, onChanged: (x) => st.saveSettings({'tindeqThresholdKg': x})),
        sectionTitle('Pantalla'),
        Stepper2(label: 'Tamaño de texto', value: s('textScale', 1.0), step: 0.1, min: 0.8, max: 1.5, onChanged: (x) => st.saveSettings({'textScale': double.parse(x.toStringAsFixed(1))})),
        sectionTitle('Recordatorios'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: st.settings['remMorningOn'] != false,
          onChanged: (v) async {
            await st.saveSettings({'remMorningOn': v});
            await Notifs.instance.rescheduleAll(st);
          },
          title: const Text('Bienestar por la mañana'),
          subtitle: Text('A las ${st.settings['remMorning'] ?? '08:30'}'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 30));
            if (t != null) {
              await st.saveSettings({'remMorning': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'});
              await Notifs.instance.rescheduleAll(st);
            }
          },
          icon: const Icon(Icons.alarm),
          label: const Text('CAMBIAR HORA'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.tryParse('${st.settings['testDate'] ?? ''}') ?? DateTime.now().add(const Duration(days: 14)), firstDate: DateTime(2024), lastDate: DateTime(2031));
            if (d != null) {
              await st.saveSettings({'testDate': dayKey(d)});
              await Notifs.instance.rescheduleAll(st);
            }
          },
          icon: const Icon(Icons.event),
          label: Text(st.settings['testDate'] == null ? 'FECHA DE LA PRÓXIMA BATERÍA DE TESTS' : 'Batería de tests: ${st.settings['testDate']}'),
        ),
        sectionTitle('Cuenta y nube'),
        if (context.read<AuthController>().cloud && context.read<AuthController>().sync != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: AppColors.accent),
              title: Text(context.watch<AuthController>().sync!.status),
              subtitle: Text(context.read<AuthController>().api.session?.email ?? ''),
              trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: context.read<AuthController>().sync!.sync),
            ),
          ),
          OutlinedButton.icon(onPressed: () => context.read<AuthController>().logout(), icon: const Icon(Icons.logout), label: const Text('CERRAR SESIÓN')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('¿Borrar todos mis datos?'),
                  content: const Text('Se borran de la nube y de este dispositivo. No se puede deshacer.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('BORRAR')),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await context.read<AuthController>().eraseMyData();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
                }
              }
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('BORRAR MIS DATOS'),
          ),
        ] else
          const Text('Sin nube en esta compilación: los datos viven solo en este dispositivo.', style: TextStyle(color: AppColors.muted)),
        sectionTitle('Copia de seguridad'),
        FilledButton.icon(onPressed: st.exportJson, icon: const Icon(Icons.upload), label: const Text('EXPORTAR TODO (JSON)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => st.exportCsv(Col.tests), icon: const Icon(Icons.table_chart), label: const Text('EXPORTAR TESTS (CSV)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => st.exportCsv(Col.logs), icon: const Icon(Icons.table_chart), label: const Text('EXPORTAR SESIONES (CSV)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final data = await Clipboard.getData('text/plain');
            final txt = data?.text ?? '';
            try {
              final n = await st.importJson(txt);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importados $n registros')));
            } catch (_) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El portapapeles no tiene una copia válida')));
            }
          },
          icon: const Icon(Icons.download),
          label: const Text('IMPORTAR COPIA (DEL PORTAPAPELES)'),
        ),
        const SizedBox(height: 24),
        const Text('Versión 0.2', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}
