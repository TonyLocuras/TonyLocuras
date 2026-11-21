import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../coach.dart';
import '../config.dart';
import '../store.dart';
import '../theme.dart';
import 'nutricion.dart' show FoodEditor;
import 'plan.dart';

const aiKinds = <String, ({String label, String sub, IconData icon})>{
  'plan': (label: 'Plan de entrenamiento', sub: 'Macrociclo, mesociclos y sesiones', icon: Icons.calendar_month),
  'study': (label: 'Estudio biomecánico / prueba de esfuerzo', sub: 'Valores, referencias y criterios de recuperación', icon: Icons.biotech),
  'label': (label: 'Etiqueta nutricional (foto o PDF)', sub: 'Alimento con valores por 100 g', icon: Icons.local_dining),
  'competitions': (label: 'Calendario de competiciones', sub: 'PDF o foto del calendario federativo', icon: Icons.emoji_events),
  'bodycomp': (label: 'Bioimpedancia', sub: 'Peso, grasa, músculo, agua, TMB', icon: Icons.monitor_weight),
  'labs': (label: 'Analítica de sangre', sub: 'Parámetros con valor y rango', icon: Icons.bloodtype),
};

String _contentType(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Sube un archivo al almacenamiento privado y devuelve su ruta.
Future<String> uploadFile(Api api, String uid, String folder, String localPath, String name) async {
  final bytes = await File(localPath).readAsBytes();
  if (bytes.length > 24 * 1024 * 1024) throw ApiException('El archivo supera los 24 MB');
  final path = '$uid/$folder/${DateTime.now().millisecondsSinceEpoch}_${_safe(name)}';
  await api.uploadDoc(path, bytes, _contentType(name));
  return path;
}

/// Llama a la función de IA y devuelve los datos estructurados.
Future<Map<String, dynamic>> analyzePath(Api api, String path, String kind) async {
  final r = await api.fn('ai-import', {'path': path, 'kind': kind});
  if (r['error'] != null) throw ApiException('${r['error']}');
  return Map<String, dynamic>.from(r['data'] as Map);
}

// ====================================================================== Importar

class AiImportScreen extends StatefulWidget {
  const AiImportScreen({super.key});
  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> {
  bool busy = false;
  String? busyMsg;

  Future<void> _run(String kind, {bool camera = false}) async {
    final auth = context.read<AuthController>();
    final store = context.read<Store>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.cloud || auth.api.session == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Necesitas iniciar sesión y tener conexión para usar la IA')));
      return;
    }
    String? path, name;
    if (camera) {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
      if (x == null) return;
      path = x.path;
      name = 'foto.jpg';
    } else {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp']);
      if (f == null || f.path == null) return;
      path = f.path;
      name = f.name;
    }
    setState(() {
      busy = true;
      busyMsg = 'Subiendo documento...';
    });
    try {
      final remote = await uploadFile(auth.api, auth.uid!, 'imports', path!, name);
      await store.put(Col.docs, {'name': name, 'path': remote, 'kind': kind, 'at': DateTime.now().toIso8601String()});
      if (mounted) setState(() => busyMsg = 'Leyendo con IA (puede tardar un minuto)...');
      final data = await analyzePath(auth.api, remote, kind);
      if (!mounted) return;
      setState(() => busy = false);
      await nav.push(MaterialPageRoute(builder: (_) => ReviewRouter(kind: kind, data: data, docName: name!)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), duration: const Duration(seconds: 6)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo completar: $e'), duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar con IA')),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'La IA lee el documento y propone los datos. NADA se guarda hasta que lo revises y lo confirmes. Lo que no aparezca en el documento queda vacío y marcado.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          for (final e in aiKinds.entries)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Icon(e.value.icon, color: AppColors.accent, size: 30),
                title: Text(e.value.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(e.value.sub),
                trailing: e.key == 'label'
                    ? IconButton(icon: const Icon(Icons.photo_camera), onPressed: busy ? null : () => _run(e.key, camera: true))
                    : const Icon(Icons.upload_file),
                onTap: busy ? null : () => _run(e.key),
              ),
            ),
        ]),
        if (busy)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(busyMsg ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

// ====================================================================== Revisión

class ReviewRouter extends StatelessWidget {
  final String kind;
  final Map<String, dynamic> data;
  final String docName;
  const ReviewRouter({super.key, required this.kind, required this.data, required this.docName});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    switch (kind) {
      case 'plan':
        return PlanReviewScreen(
          data: data,
          targetLabel: 'Mi plan',
          saveSession: (s) => store.put(Col.plan, s),
        );
      case 'study':
        return StudyReviewScreen(data: data, docName: docName);
      case 'label':
        return FoodEditor(prefill: data);
      case 'competitions':
        return CompetitionsReviewScreen(data: data);
      case 'bodycomp':
        return BodycompReviewScreen(data: data);
      case 'labs':
        return LabsReviewScreen(data: data);
      default:
        return RawResultScreen(title: 'Resultado', data: data);
    }
  }
}

DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

int? _weekdayNum(dynamic w) {
  if (w is num) return w.toInt();
  if (w is! String) return null;
  final s = w.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
  const names = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  for (var i = 0; i < names.length; i++) {
    if (s.startsWith(names[i].substring(0, 3))) return i + 1;
  }
  return null;
}

/// Revisión editable de un plan (importado de PDF o borrador de IA).
class PlanReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String targetLabel;
  final Future<void> Function(Map<String, dynamic> session) saveSession;
  const PlanReviewScreen({super.key, required this.data, required this.targetLabel, required this.saveSession});
  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  late List<Map<String, dynamic>> drafts;
  DateTime start = _mondayOf(DateTime.now().add(const Duration(days: 7)));
  bool saving = false;

  @override
  void initState() {
    super.initState();
    drafts = [
      for (final s in ((widget.data['sessions'] as List?) ?? []))
        {
          ...Map<String, dynamic>.from(s as Map),
          'exercises': [for (final e in ((s as Map)['exercises'] as List? ?? [])) Map<String, dynamic>.from(e as Map)],
          '_include': true,
        }
    ];
    _resolveDates();
  }

  void _resolveDates() {
    for (final s in drafts) {
      final explicit = DateTime.tryParse('${s['date'] ?? ''}');
      if (explicit != null && s['_dateFromWeek'] != true) {
        s['date'] = dayKey(explicit);
        continue;
      }
      final w = (s['week'] as num?)?.toInt();
      final wd = _weekdayNum(s['weekday']);
      if (w != null && wd != null) {
        s['date'] = dayKey(start.add(Duration(days: (w - 1) * 7 + (wd - 1))));
        s['_dateFromWeek'] = true;
      } else if (explicit == null) {
        s['date'] = null;
      }
    }
  }

  bool _incomplete(Map<String, dynamic> e) => e['sets'] == null || (e['type'] == null);

  Future<void> _save() async {
    final inc = drafts.where((d) => d['_include'] == true).toList();
    if (inc.any((d) => d['date'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hay sesiones sin fecha: asígnala o desmárcalas')));
      return;
    }
    setState(() => saving = true);
    try {
      var i = 0;
      for (final d in inc) {
        final doc = Map<String, dynamic>.from(d)
          ..remove('_include')
          ..remove('_dateFromWeek')
          ..remove('week')
          ..remove('weekday');
        doc['id'] = '${newId()}$i';
        i++;
        doc['exercises'] = [
          for (final e in (doc['exercises'] as List))
            {
              ...Map<String, dynamic>.from(e as Map),
              'type': (e as Map)['type'] ?? 'gym',
              'sets': e['sets'] ?? 1,
            }
        ];
        await widget.saveSession(doc);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${inc.length} sesiones guardadas en ${widget.targetLabel}')));
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uncertain = ((widget.data['uncertain'] ?? widget.data['cautions']) as List?)?.map((e) => '$e').toList() ?? [];
    final summary = widget.data['summary'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar plan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Destino: ${widget.targetLabel}', style: const TextStyle(color: AppColors.muted)),
        if (summary != null && summary.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(summary))),
        if (uncertain.isNotEmpty)
          Card(
            color: AppColors.surface2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('A REVISAR', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w900)),
                for (final u in uncertain) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $u')),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2024), lastDate: DateTime(2031));
            if (d != null) {
              setState(() {
                start = _mondayOf(d);
                _resolveDates();
              });
            }
          },
          icon: const Icon(Icons.event),
          label: Text('Semana 1 empieza el ${DateFormat('d MMM y', 'es').format(start)}'),
        ),
        sectionTitle('Sesiones (${drafts.where((d) => d['_include'] == true).length}/${drafts.length})'),
        for (var i = 0; i < drafts.length; i++) _tile(i),
        const SizedBox(height: 16),
        FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'GUARDANDO...' : 'GUARDAR LO SELECCIONADO')),
      ]),
    );
  }

  Widget _tile(int i) {
    final s = drafts[i];
    final ex = (s['exercises'] as List).cast<Map<String, dynamic>>();
    final missing = ex.where(_incomplete).length;
    final origins = <String, int>{};
    for (final e in ex) {
      final o = e['origin'];
      if (o is String) origins[o.startsWith('documento') ? 'documento' : 'general'] = (origins[o.startsWith('documento') ? 'documento' : 'general'] ?? 0) + 1;
    }
    final date = DateTime.tryParse('${s['date'] ?? ''}');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        leading: Checkbox(value: s['_include'] == true, onChanged: (v) => setState(() => s['_include'] = v ?? false)),
        title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          date == null ? 'SIN FECHA' : DateFormat('EEE d MMM', 'es').format(date),
          '${ex.length} ejercicios',
          if (missing > 0) '$missing con datos por completar',
          if (origins.isNotEmpty) origins.entries.map((e) => '${e.value} ${e.key}').join(' / '),
        ].join(' · ')),
        trailing: date == null || missing > 0 ? const Icon(Icons.warning_amber_rounded, color: AppColors.amber) : const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionEditor(
              heading: 'Revisar sesión',
              session: {...s, 'date': s['date'] ?? dayKey(start)},
              onSave: (doc) async {
                setState(() {
                  drafts[i] = {...s, ...doc, '_include': s['_include'], '_dateFromWeek': false};
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class StudyReviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docName;
  const StudyReviewScreen({super.key, required this.data, required this.docName});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> l(String k) => [for (final e in ((data[k] as List?) ?? [])) Map<String, dynamic>.from(e as Map)];
    final values = l('values'), refs = l('references'), rules = l('recovery_rules'), nutr = l('nutrition');
    String pg(Map<String, dynamic> m) => m['page'] == null ? '' : ' (p. ${(m['page'] as num).toInt()})';
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar estudio')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('${data['summary'] ?? ''}'))),
        sectionTitle('Valores medidos (${values.length})'),
        for (final v in values)
          ListTile(
            dense: true,
            title: Text('${v['label']}'),
            subtitle: v['quote'] == null ? null : Text('«${v['quote']}»${pg(v)}', style: const TextStyle(fontSize: 12)),
            trailing: Text('${v['value'] ?? v['text'] ?? '-'} ${v['unit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        sectionTitle('Referencias por nivel (${refs.length})'),
        for (final r in refs) ListTile(dense: true, title: Text('${r['test']} · ${r['level']}${pg(r)}'), trailing: Text('${r['value'] ?? '-'} ${r['unit'] ?? ''}')),
        sectionTitle('Criterios de recuperación (${rules.length})'),
        for (final r in rules) ListTile(dense: true, title: Text('${r['text']}${pg(r)}'), subtitle: r['quote'] == null ? null : Text('«${r['quote']}»', style: const TextStyle(fontSize: 12))),
        sectionTitle('Nutrición (${nutr.length})'),
        for (final r in nutr) ListTile(dense: true, title: Text('${r['text']}${pg(r)}')),
        const SizedBox(height: 16),
        const Text('Lo guardado aquí alimenta la recuperación tras expediciones y las referencias. Cada criterio conserva su página de origen.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            await context.read<Store>().put(Col.studies, {'title': docName, 'at': DateTime.now().toIso8601String(), ...data});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estudio guardado')));
              Navigator.popUntil(context, (r) => r.isFirst);
            }
          },
          child: const Text('GUARDAR ESTUDIO'),
        ),
      ]),
    );
  }
}

class CompetitionsReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const CompetitionsReviewScreen({super.key, required this.data});
  @override
  State<CompetitionsReviewScreen> createState() => _CompetitionsReviewScreenState();
}

class _CompetitionsReviewScreenState extends State<CompetitionsReviewScreen> {
  late List<Map<String, dynamic>> items;
  @override
  void initState() {
    super.initState();
    items = [for (final e in ((widget.data['items'] as List?) ?? [])) {...Map<String, dynamic>.from(e as Map), '_inc': true}];
  }

  @override
  Widget build(BuildContext context) {
    final unc = ((widget.data['uncertain'] as List?) ?? []).map((e) => '$e').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar competiciones')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final u in unc) Text('• $u', style: const TextStyle(color: AppColors.amber)),
        for (final it in items)
          Card(
            child: CheckboxListTile(
              value: it['_inc'] == true,
              onChanged: (v) => setState(() => it['_inc'] = v ?? false),
              title: Text('${it['name']}'),
              subtitle: Text('${it['date'] ?? 'SIN FECHA'} · ${it['place'] ?? ''}'),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final st = context.read<Store>();
            var n = 0;
            for (final it in items.where((e) => e['_inc'] == true)) {
              await st.put(Col.competitions, {
                'id': '${newId()}$n',
                'name': it['name'],
                'date': it['date'] ?? dayKey(DateTime.now()),
                'place': it['place'] ?? '',
                'circuit': it['circuit'] ?? 'Otro',
                'priority': 'B',
                'result': false,
              });
              n++;
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n competiciones guardadas (revisa fechas y prioridad)')));
              Navigator.popUntil(context, (r) => r.isFirst);
            }
          },
          child: const Text('GUARDAR LO SELECCIONADO'),
        ),
      ]),
    );
  }
}

class BodycompReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const BodycompReviewScreen({super.key, required this.data});
  @override
  State<BodycompReviewScreen> createState() => _BodycompReviewScreenState();
}

class _BodycompReviewScreenState extends State<BodycompReviewScreen> {
  static const fields = {
    'date': 'Fecha (AAAA-MM-DD)',
    'weightKg': 'Peso (kg)',
    'fatPct': 'Grasa (%)',
    'muscleKg': 'Masa muscular (kg)',
    'waterPct': 'Agua (%)',
    'bmrKcal': 'TMB (kcal)',
    'boneKg': 'Masa ósea (kg)',
    'visceral': 'Grasa visceral',
  };
  final ctl = <String, TextEditingController>{};
  bool updateWeight = true;

  @override
  void initState() {
    super.initState();
    for (final k in fields.keys) {
      ctl[k] = TextEditingController(text: widget.data[k] == null ? '' : '${widget.data[k]}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unc = ((widget.data['uncertain'] as List?) ?? []).map((e) => '$e').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar bioimpedancia')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final u in unc) Text('• $u', style: const TextStyle(color: AppColors.amber)),
        for (final e in fields.entries) ...[
          const SizedBox(height: 10),
          TextField(
            controller: ctl[e.key],
            keyboardType: e.key == 'date' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: e.value,
              suffixIcon: ctl[e.key]!.text.isEmpty ? const Icon(Icons.warning_amber_rounded, color: AppColors.amber) : null,
            ),
          ),
        ],
        SwitchListTile(value: updateWeight, onChanged: (v) => setState(() => updateWeight = v), title: const Text('Actualizar mi peso y TMB en Ajustes')),
        FilledButton(
          onPressed: () async {
            final st = context.read<Store>();
            final doc = <String, dynamic>{};
            for (final k in fields.keys) {
              final t = ctl[k]!.text.trim().replaceAll(',', '.');
              if (t.isEmpty) continue;
              doc[k] = k == 'date' ? t : (double.tryParse(t) ?? t);
            }
            doc['date'] ??= dayKey(DateTime.now());
            await st.put(Col.bodycomp, doc);
            if (updateWeight) {
              await st.saveSettings({
                if (doc['weightKg'] is num) 'weightKg': doc['weightKg'],
                if (doc['bmrKcal'] is num) 'bmrKcal': doc['bmrKcal'],
              });
            }
            if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}

class LabsReviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const LabsReviewScreen({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final items = [for (final e in ((data['items'] as List?) ?? [])) Map<String, dynamic>.from(e as Map)];
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar analítica')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Fecha: ${data['date'] ?? 'sin fecha'}', style: const TextStyle(color: AppColors.muted)),
        for (final i in items)
          ListTile(
            dense: true,
            title: Text('${i['name']}'),
            subtitle: Text('Ref: ${i['refMin'] ?? '-'} – ${i['refMax'] ?? '-'} ${i['unit'] ?? ''}'),
            trailing: Text('${i['value'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        const SizedBox(height: 8),
        const Text('Solo transcripción del documento: no es una interpretación médica.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await context.read<Store>().put(Col.labs, {'date': data['date'] ?? dayKey(DateTime.now()), 'items': items});
            if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}

class RawResultScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final Future<void> Function()? onSave;
  final String saveLabel;
  const RawResultScreen({super.key, required this.title, required this.data, this.onSave, this.saveLabel = 'GUARDAR'});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SelectableText(const JsonEncoder.withIndent('  ').convert(data), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        if (onSave != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await onSave!();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(saveLabel),
          ),
        ],
      ]),
    );
  }
}

// ====================================================================== Borrador de plan con IA (entrenador)

class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key});
  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  String? clientUid;
  final goal = TextEditingController();
  final level = TextEditingController();
  final limits = TextEditingController();
  final equip = TextEditingController();
  double days = 3, weeks = 4;
  final Set<String> sources = {};
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final coach = context.watch<CoachService>();
    final store = context.read<Store>();
    final studies = store.list(Col.studies);
    return Scaffold(
      appBar: AppBar(title: const Text('Borrador de plan con IA')),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'La IA genera un BORRADOR. Cada ejercicio indica si sale de uno de tus documentos o de conocimiento general. Tú lo revisas y lo editas antes de enviarlo al cliente. No sustituye evidencia revisada ni tu criterio.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: clientUid,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: [for (final c in coach.clients) DropdownMenuItem(value: c['uid'] as String, child: Text('${c['name']}'))],
            onChanged: (v) => setState(() => clientUid = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: goal, decoration: const InputDecoration(labelText: 'Objetivo (ej. mejorar fuerza de dedos, pasar de 6b a 7a)')),
          const SizedBox(height: 12),
          TextField(controller: level, decoration: const InputDecoration(labelText: 'Nivel (ej. intermedio, 6c bloque)')),
          const SizedBox(height: 12),
          Stepper2(label: 'Días por semana', value: days, min: 1, max: 7, onChanged: (x) => setState(() => days = x)),
          const SizedBox(height: 8),
          Stepper2(label: 'Semanas', value: weeks, min: 1, max: 16, onChanged: (x) => setState(() => weeks = x)),
          const SizedBox(height: 12),
          TextField(controller: limits, maxLines: 2, decoration: const InputDecoration(labelText: 'Lesiones o limitaciones')),
          const SizedBox(height: 12),
          TextField(controller: equip, maxLines: 2, decoration: const InputDecoration(labelText: 'Material disponible (campus, tablero, lastre...)')),
          sectionTitle('Fuentes tuyas (opcional)'),
          if (studies.isEmpty) const Text('Sin estudios guardados. Impórtalos en Importar con IA > Estudio.', style: TextStyle(color: AppColors.muted)),
          for (final s in studies)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: sources.contains(s['id']),
              onChanged: (v) => setState(() => v == true ? sources.add(s['id'] as String) : sources.remove(s['id'])),
              title: Text('${s['title']}'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy || clientUid == null ? null : () => _go(context, coach, studies),
            child: Text(clientUid == null ? 'ELIGE UN CLIENTE' : 'GENERAR BORRADOR'),
          ),
        ]),
        if (busy)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando borrador (puede tardar un minuto)...', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }

  String _sourceText(Map<String, dynamic> s) {
    final b = StringBuffer('${s['summary'] ?? ''}\n');
    for (final r in ((s['recovery_rules'] as List?) ?? [])) {
      b.writeln('- Recuperación: ${(r as Map)['text']} (p. ${r['page'] ?? '?'})');
    }
    for (final r in ((s['references'] as List?) ?? [])) {
      b.writeln('- Referencia ${(r as Map)['test']} ${r['level']}: ${r['value']} ${r['unit'] ?? ''}');
    }
    for (final r in ((s['nutrition'] as List?) ?? [])) {
      b.writeln('- Nutrición: ${(r as Map)['text']}');
    }
    return b.toString();
  }

  Future<void> _go(BuildContext context, CoachService coach, List<Map<String, dynamic>> studies) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    setState(() => busy = true);
    try {
      final r = await auth.api.fn('ai-plan', {
        'goal': goal.text.trim(),
        'level': level.text.trim(),
        'daysPerWeek': days.toInt(),
        'weeks': weeks.toInt(),
        'limitations': limits.text.trim(),
        'equipment': equip.text.trim(),
        'sources': [
          for (final s in studies.where((s) => sources.contains(s['id']))) {'label': '${s['title']}', 'text': _sourceText(s)}
        ],
      });
      if (r['error'] != null) throw ApiException('${r['error']}');
      final data = Map<String, dynamic>.from(r['data'] as Map);
      final cName = coach.clientByUid(clientUid!)?['name'] ?? 'cliente';
      if (!mounted) return;
      setState(() => busy = false);
      await nav.push(MaterialPageRoute(
        builder: (_) => PlanReviewScreen(
          data: data,
          targetLabel: 'plan de $cName',
          saveSession: (s) => coach.assignSession(clientUid!, s),
        ),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), duration: const Duration(seconds: 6)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo generar: $e'), duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// Sube un archivo propio (cliente) a su bandeja de documentos para el entrenador.
Future<void> clientUploadDoc(BuildContext context, {required String label}) async {
  final auth = context.read<AuthController>();
  final store = context.read<Store>();
  final messenger = ScaffoldMessenger.of(context);
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp']);
  if (f == null || f.path == null) return;
  try {
    messenger.showSnackBar(const SnackBar(content: Text('Subiendo...')));
    final path = await uploadFile(auth.api, auth.uid!, 'inbox', f.path!, f.name);
    await store.put(Col.docs, {'name': f.name, 'path': path, 'label': label, 'at': DateTime.now().toIso8601String(), 'inbox': true});
    messenger.showSnackBar(const SnackBar(content: Text('Enviado a tu entrenador')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo subir (¿hay conexión?): $e')));
  }
}

String appKindLabel() => Config.isClientApp ? 'Clientes' : 'Atleta y entrenador';
