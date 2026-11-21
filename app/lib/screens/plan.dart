import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';

/// Tipos de ejercicio con temporizador propio.
const exerciseTypes = {
  'hang': 'Suspensión',
  'repeater': 'Repeaters',
  'gym': 'Fuerza / gimnasio',
  'bloc': 'Bloque / proyecto',
  'cardio': 'Resistencia / ARC / movilidad',
};

const capabilities = ['prioritaria', 'complementaria', 'suplementaria', 'otra'];

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final all = st.list(Col.plan)..sort((a, b) => ('${a['date']}${a['time'] ?? ''}').compareTo('${b['date']}${b['time'] ?? ''}'));
    final today = dayKey(DateTime.now());
    final upcoming = all.where((s) => (s['date'] as String).compareTo(today) >= 0).toList();
    final past = all.where((s) => (s['date'] as String).compareTo(today) < 0).toList().reversed.toList();

    Widget tile(Map<String, dynamic> s) {
      final d = DateTime.parse(s['date'] as String);
      final n = ((s['exercises'] as List?) ?? []).length;
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(s['title'] as String? ?? 'Sesión', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${DateFormat('EEE d MMM', 'es').format(d)}${(s['time'] ?? '') == '' ? '' : ' · ${s['time']}'} · $n ejercicios${s['phase'] != null && s['phase'] != '' ? ' · ${s['phase']}' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionEditor(session: s))),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Sesión', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aún no hay sesiones. Añade las de esta semana (las del plan de tu entrenador) con el botón «Sesión». En enero se podrá importar el plan desde PDF.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
          ),
        if (upcoming.isNotEmpty) sectionTitle('Próximas'),
        ...upcoming.map(tile),
        if (past.isNotEmpty) sectionTitle('Pasadas'),
        ...past.take(30).map(tile),
      ]),
    );
  }
}

class SessionEditor extends StatefulWidget {
  final Map<String, dynamic>? session;
  const SessionEditor({super.key, this.session});
  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  late String id;
  final title = TextEditingController();
  final phase = TextEditingController();
  final time = TextEditingController();
  late DateTime date;
  late List<Map<String, dynamic>> ex;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    id = (s?['id'] as String?) ?? newId();
    title.text = (s?['title'] as String?) ?? '';
    phase.text = (s?['phase'] as String?) ?? '';
    time.text = (s?['time'] as String?) ?? '';
    date = s != null ? DateTime.parse(s['date'] as String) : DateTime.now();
    ex = [for (final e in ((s?['exercises'] as List?) ?? [])) Map<String, dynamic>.from(e as Map)];
  }

  Future<void> _save() async {
    await context.read<Store>().put(Col.plan, {
      'id': id,
      'date': dayKey(date),
      'time': time.text.trim(),
      'title': title.text.trim().isEmpty ? 'Sesión' : title.text.trim(),
      'phase': phase.text.trim(),
      'exercises': ex,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editEx(int? i) async {
    final r = await Navigator.push<Map<String, dynamic>>(
        context, MaterialPageRoute(builder: (_) => ExerciseEditor(exercise: i == null ? null : ex[i])));
    if (r != null) {
      setState(() {
        if (i == null) {
          ex.add(r);
        } else {
          ex[i] = r;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session == null ? 'Nueva sesión' : 'Editar sesión'), actions: [
        if (widget.session != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<Store>().remove(Col.plan, id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Título (ej. Fuerza máxima dedos)')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setState(() => date = d);
              },
              icon: const Icon(Icons.event),
              label: Text(DateFormat('EEE d MMM y', 'es').format(date)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: TextField(controller: time, decoration: const InputDecoration(labelText: 'Hora'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: phase, decoration: const InputDecoration(labelText: 'Fase (acumulación, pico, descarga...)')),
        sectionTitle('Ejercicios'),
        for (var i = 0; i < ex.length; i++)
          Card(
            child: ListTile(
              title: Text(ex[i]['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_summary(ex[i])),
              onTap: () => _editEx(i),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () => setState(() { final e = ex.removeAt(i); ex.insert(i - 1, e); })),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => ex.removeAt(i))),
              ]),
            ),
          ),
        OutlinedButton.icon(onPressed: () => _editEx(null), icon: const Icon(Icons.add), label: const Text('AÑADIR EJERCICIO')),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('GUARDAR SESIÓN')),
      ]),
    );
  }

  static String _summary(Map<String, dynamic> e) {
    final t = exerciseTypes[e['type']] ?? '';
    final sets = e['sets'];
    switch (e['type']) {
      case 'hang':
        return '$t · $sets × ${e['workS']} s / ${e['restS']} s · ${e['grip'] ?? ''} ${e['load'] ?? ''}';
      case 'repeater':
        return '$t · $sets × ${e['reps']} × ${e['workS']}:${e['restRepS']} s · desc ${e['restS']} s · ${e['load'] ?? ''}';
      default:
        return '$t · $sets × ${e['reps'] ?? '-'} · ${e['load'] ?? ''}';
    }
  }
}

class ExerciseEditor extends StatefulWidget {
  final Map<String, dynamic>? exercise;
  const ExerciseEditor({super.key, this.exercise});
  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  final name = TextEditingController();
  final load = TextEditingController();
  final grip = TextEditingController();
  final notes = TextEditingController();
  String type = 'hang';
  String cap = 'prioritaria';
  double sets = 3, reps = 1, workS = 10, restS = 180, restRepS = 3;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    if (e != null) {
      name.text = e['name'] as String? ?? '';
      load.text = e['load'] as String? ?? '';
      grip.text = e['grip'] as String? ?? '';
      notes.text = e['notes'] as String? ?? '';
      type = e['type'] as String? ?? 'hang';
      cap = e['cap'] as String? ?? 'prioritaria';
      double g(String k, double d) => (e[k] as num?)?.toDouble() ?? d;
      sets = g('sets', 3);
      reps = g('reps', 1);
      workS = g('workS', 10);
      restS = g('restS', 180);
      restRepS = g('restRepS', 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timed = type == 'hang' || type == 'repeater';
    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicio')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [for (final e in exerciseTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (x) => setState(() => type = x ?? type),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: cap,
          decoration: const InputDecoration(labelText: 'Capacidad'),
          items: [for (final c in capabilities) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (x) => setState(() => cap = x ?? cap),
        ),
        const SizedBox(height: 16),
        Stepper2(label: 'Series', value: sets, min: 1, max: 30, onChanged: (x) => setState(() => sets = x)),
        const SizedBox(height: 8),
        if (type == 'repeater' || !timed)
          Stepper2(label: type == 'repeater' ? 'Repeticiones por serie' : 'Repeticiones', value: reps, min: 1, max: 100, onChanged: (x) => setState(() => reps = x)),
        if (timed) ...[
          const SizedBox(height: 8),
          Stepper2(label: type == 'hang' ? 'Colgado (s)' : 'Trabajo (s)', value: workS, min: 1, max: 600, onChanged: (x) => setState(() => workS = x)),
        ],
        if (type == 'repeater') ...[
          const SizedBox(height: 8),
          Stepper2(label: 'Descanso entre reps (s)', value: restRepS, min: 1, max: 60, onChanged: (x) => setState(() => restRepS = x)),
        ],
        const SizedBox(height: 8),
        Stepper2(label: 'Descanso entre series (s)', value: restS, step: 15, min: 0, max: 900, onChanged: (x) => setState(() => restS = x)),
        const SizedBox(height: 12),
        TextField(controller: grip, decoration: const InputDecoration(labelText: 'Canto / agarre (ej. 20 mm semiarqueo)')),
        const SizedBox(height: 12),
        TextField(controller: load, decoration: const InputDecoration(labelText: 'Carga (ej. +10 kg, 85% pico, RPE 8)')),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': name.text.trim(),
              'type': type,
              'cap': cap,
              'sets': sets.toInt(),
              'reps': reps.toInt(),
              'workS': workS.toInt(),
              'restS': restS.toInt(),
              'restRepS': restRepS.toInt(),
              'grip': grip.text.trim(),
              'load': load.text.trim(),
              'notes': notes.text.trim(),
            });
          },
          child: const Text('LISTO'),
        ),
      ]),
    );
  }
}
