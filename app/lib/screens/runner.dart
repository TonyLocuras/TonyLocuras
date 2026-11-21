import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../notifs.dart';
import '../store.dart';
import '../theme.dart';

enum Ph { idle, work, restRep, restSet, log, exEnd }

/// Ejecuta una sesión del plan: temporizadores, pitidos, voz, vibración,
/// registro por serie y por ejercicio. Pantalla siempre encendida.
class RunnerScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const RunnerScreen({super.key, required this.session});
  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen> {
  late final List<Map<String, dynamic>> ex;
  final FlutterTts tts = FlutterTts();
  Timer? _t;
  final DateTime started = DateTime.now();

  int idx = 0;
  int setIdx = 0;
  int rep = 1;
  Ph ph = Ph.idle;
  int rem = 0;
  bool paused = false;

  // registro
  final List<Map<String, dynamic>> exLogs = [];
  List<Map<String, dynamic>> setLogs = [];
  double loadKg = 0;
  double repsDone = 0;
  double rpe = 7;
  String status = 'Hecho';
  double pain = 0;
  String painZone = 'Dedos';
  final notes = TextEditingController();

  Map<String, dynamic> get cur => ex[idx];
  int get sets => (cur['sets'] as num?)?.toInt() ?? 1;
  int get workS => (cur['workS'] as num?)?.toInt() ?? 10;
  int get restS => (cur['restS'] as num?)?.toInt() ?? 60;
  int get restRepS => (cur['restRepS'] as num?)?.toInt() ?? 3;
  int get reps => (cur['reps'] as num?)?.toInt() ?? 1;
  String get type => cur['type'] as String? ?? 'gym';
  bool get timed => type == 'hang' || type == 'repeater';

  @override
  void initState() {
    super.initState();
    ex = [for (final e in ((widget.session['exercises'] as List?) ?? [])) Map<String, dynamic>.from(e as Map)];
    WakelockPlus.enable();
    tts.setLanguage('es-ES');
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _prepareExercise(announce: true);
  }

  @override
  void dispose() {
    _t?.cancel();
    WakelockPlus.disable();
    tts.stop();
    notes.dispose();
    super.dispose();
  }

  void _say(String s) {
    try {
      tts.speak(s);
    } catch (_) {}
  }

  void _beep({bool strong = false}) {
    SystemSound.play(SystemSoundType.click);
    if (strong) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  double _defaultLoad() {
    final m = RegExp(r'(-?\d+[.,]?\d*)\s*kg').firstMatch('${cur['load'] ?? ''}');
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  void _prepareExercise({bool announce = false}) {
    if (idx >= ex.length) return;
    setIdx = 0;
    rep = 1;
    ph = Ph.idle;
    setLogs = [];
    loadKg = _defaultLoad();
    repsDone = reps.toDouble();
    rpe = 7;
    status = 'Hecho';
    pain = 0;
    notes.clear();
    if (announce) _say('${cur['name']}. $sets series.');
  }

  void _startSet() {
    setState(() {
      rep = 1;
      if (timed) {
        ph = Ph.work;
        rem = workS;
        _say('Ya');
        _beep(strong: true);
      } else {
        ph = Ph.work; // serie manual en curso
        rem = 0;
      }
    });
  }

  void _tick() {
    if (!mounted || paused) return;
    if (ph == Ph.work && !timed) {
      setState(() => rem++); // cronómetro de la serie manual
      return;
    }
    if (ph != Ph.work && ph != Ph.restRep && ph != Ph.restSet) return;
    setState(() {
      rem--;
      if (rem > 0 && rem <= 3) _beep();
      if (rem <= 0) _phaseEnd();
    });
  }

  void _phaseEnd() {
    _beep(strong: true);
    switch (ph) {
      case Ph.work:
        if (type == 'repeater' && rep < reps) {
          ph = Ph.restRep;
          rem = restRepS;
        } else {
          _setDone();
        }
      case Ph.restRep:
        rep++;
        ph = Ph.work;
        rem = workS;
      case Ph.restSet:
        if (timed) {
          _startSet();
        } else {
          ph = Ph.idle;
        }
      default:
        break;
    }
  }

  void _setDone() {
    ph = Ph.log;
    rem = 0;
    HapticFeedback.heavyImpact();
  }

  void _saveSetLog() {
    setLogs.add({'set': setIdx + 1, 'loadKg': loadKg, 'reps': repsDone, 'plannedReps': reps, 'workS': workS});
    if (setIdx + 1 >= sets) {
      setState(() => ph = Ph.exEnd);
      return;
    }
    setState(() {
      setIdx++;
      if (restS > 0) {
        ph = Ph.restSet;
        rem = restS;
        _say('Descanso');
      } else {
        ph = Ph.idle;
      }
    });
  }

  void _finishExercise({bool skipped = false}) {
    exLogs.add({
      'name': cur['name'],
      'type': type,
      'status': skipped ? 'Saltado' : status,
      'rpe': skipped ? null : rpe,
      'pain': skipped || pain == 0 ? null : {'zone': painZone, 'value': pain},
      'notes': notes.text.trim(),
      'sets': setLogs,
      'prescribed': {
        'sets': cur['sets'],
        'reps': cur['reps'],
        'workS': cur['workS'],
        'restS': cur['restS'],
        'load': cur['load'],
        'grip': cur['grip'],
      },
    });
    if (idx + 1 >= ex.length) {
      _finishSession();
      return;
    }
    setState(() {
      idx++;
      _prepareExercise();
    });
    _say('Siguiente: ${cur['name']}');
  }

  Future<void> _finishSession() async {
    final st = context.read<Store>();
    final minutes = DateTime.now().difference(started).inMinutes;
    final saved = await st.put(Col.logs, {
      'date': dayKey(started),
      'planId': widget.session['id'],
      'title': widget.session['title'],
      'startedAt': started.toIso8601String(),
      'endedAt': DateTime.now().toIso8601String(),
      'minutes': minutes < 1 ? 1 : minutes,
      'exercises': exLogs,
      'epg': null,
      'epl': null,
    });
    Notifs.instance.scheduleEpg('${saved['id']}', '${widget.session['title']}');
    _say('Sesión terminada');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmExit() async {
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir de la sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'seguir'), child: const Text('SEGUIR')),
          TextButton(onPressed: () => Navigator.pop(c, 'guardar'), child: const Text('GUARDAR LO HECHO')),
          TextButton(onPressed: () => Navigator.pop(c, 'descartar'), child: const Text('DESCARTAR')),
        ],
      ),
    );
    if (r == 'guardar') {
      await _finishSession();
      return false;
    }
    return r == 'descartar';
  }

  @override
  Widget build(BuildContext context) {
    if (ex.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esta sesión no tiene ejercicios.')));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${idx + 1}/${ex.length} · ${widget.session['title']}', style: const TextStyle(fontSize: 18)),
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 700;
            final info = _info();
            final main = _main();
            if (wide) {
              return Row(children: [
                Expanded(flex: 4, child: info),
                Expanded(flex: 6, child: main),
              ]);
            }
            return Column(children: [info, Expanded(child: main)]);
          }),
        ),
      ),
    );
  }

  Widget _info() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${cur['name']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Serie ${setIdx + 1} de $sets', style: const TextStyle(fontSize: 20, color: AppColors.accent, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (timed) Text(type == 'hang' ? '$workS s colgado · descanso $restS s' : '$reps × $workS:$restRepS s · descanso $restS s',
              style: const TextStyle(fontSize: 16, color: AppColors.muted)),
          if (!timed) Text('$reps repeticiones · descanso $restS s', style: const TextStyle(fontSize: 16, color: AppColors.muted)),
          if ('${cur['grip'] ?? ''}'.isNotEmpty) Text('Agarre: ${cur['grip']}', style: const TextStyle(fontSize: 16)),
          if ('${cur['load'] ?? ''}'.isNotEmpty) Text('Carga: ${cur['load']}', style: const TextStyle(fontSize: 16)),
          if ('${cur['notes'] ?? ''}'.isNotEmpty) Text('${cur['notes']}', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (idx + 1 < ex.length)
            Text('Siguiente: ${ex[idx + 1]['name']}', style: const TextStyle(color: AppColors.muted)),
        ]),
      ),
    );
  }

  String _label() => switch (ph) {
        Ph.work => timed ? (type == 'repeater' ? 'TRABAJO · rep $rep/$reps' : 'COLGAR') : 'SERIE EN CURSO',
        Ph.restRep => 'DESCANSO',
        Ph.restSet => 'DESCANSO ENTRE SERIES',
        Ph.log => 'REGISTRA LA SERIE',
        Ph.exEnd => 'FIN DEL EJERCICIO',
        Ph.idle => 'LISTO',
      };

  Widget _main() {
    final working = ph == Ph.work;
    final color = working ? AppColors.accent : (ph == Ph.idle ? AppColors.text : AppColors.muted);
    switch (ph) {
      case Ph.log:
        return _logPanel();
      case Ph.exEnd:
        return _exEndPanel();
      default:
    }
    final mm = (rem ~/ 60).toString().padLeft(2, '0');
    final ss = (rem % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_label(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        if (ph != Ph.idle)
          Text('$mm:$ss', style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: color, height: 1)),
        const SizedBox(height: 24),
        if (ph == Ph.idle)
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 96)),
            onPressed: _startSet,
            child: Text(timed ? 'INICIAR SERIE ${setIdx + 1}' : 'EMPEZAR SERIE ${setIdx + 1}'),
          ),
        if (ph == Ph.work && !timed)
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 96)),
            onPressed: () => setState(_setDone),
            child: const Text('SERIE HECHA'),
          ),
        if (ph == Ph.work && timed)
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 72)),
            onPressed: () => setState(_setDone),
            child: const Text('TERMINAR SERIE YA'),
          ),
        if (ph == Ph.restSet || ph == Ph.restRep)
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 72)),
            onPressed: () => setState(() { rem = 0; _phaseEnd(); }),
            child: const Text('SALTAR DESCANSO'),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => paused = !paused),
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(paused ? 'REANUDAR' : 'PAUSA'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _finishExercise(skipped: true),
              icon: const Icon(Icons.skip_next),
              label: const Text('SALTAR EJERCICIO'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _logPanel() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('SERIE HECHA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.accent)),
      const SizedBox(height: 16),
      Stepper2(label: 'Carga real (kg)', value: loadKg, step: 0.5, min: -50, max: 200, onChanged: (x) => setState(() => loadKg = x)),
      const SizedBox(height: 12),
      Stepper2(label: type == 'hang' ? 'Segundos aguantados' : 'Repeticiones hechas', value: repsDone, min: 0, max: 999, onChanged: (x) => setState(() => repsDone = x)),
      const SizedBox(height: 24),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 80)),
        onPressed: _saveSetLog,
        child: Text(setIdx + 1 >= sets ? 'GUARDAR Y TERMINAR EJERCICIO' : 'GUARDAR Y DESCANSAR'),
      ),
    ]);
  }

  Widget _exEndPanel() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('RESUMEN DEL EJERCICIO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.accent)),
      const SizedBox(height: 16),
      Stepper2(label: 'RPE (1-10)', value: rpe, min: 1, max: 10, onChanged: (x) => setState(() => rpe = x)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final s in ['Hecho', 'Modificado'])
          ChoiceChip(label: Text(s, style: const TextStyle(fontSize: 16)), selected: status == s, onSelected: (_) => setState(() => status = s)),
      ]),
      const SizedBox(height: 16),
      Stepper2(label: 'Dolor (0-10)', value: pain, min: 0, max: 10, onChanged: (x) => setState(() => pain = x)),
      if (pain > 0)
        Wrap(spacing: 8, children: [
          for (final z in ['Dedos', 'Hombro', 'Codo', 'Muñeca'])
            ChoiceChip(label: Text(z), selected: painZone == z, onSelected: (_) => setState(() => painZone = z)),
        ]),
      const SizedBox(height: 12),
      TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notas')),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 80)),
        onPressed: _finishExercise,
        child: Text(idx + 1 >= ex.length ? 'TERMINAR SESIÓN' : 'SIGUIENTE EJERCICIO'),
      ),
    ]);
  }
}
