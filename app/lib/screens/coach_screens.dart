import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../auth.dart';
import '../calc.dart';
import '../coach.dart';
import '../store.dart';
import '../theme.dart';
import 'ai_screens.dart';
import 'chat.dart';
import 'plan.dart';

DateTime? _dt(dynamic s) => DateTime.tryParse('$s')?.toLocal();

int? _ageOf(dynamic birth) {
  final b = DateTime.tryParse('$birth');
  if (b == null) return null;
  final n = DateTime.now();
  var a = n.year - b.year;
  if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
  return a;
}

// ====================================================================== Clientes

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final coach = context.watch<CoachService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes'), actions: [
        IconButton(onPressed: coach.refresh, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: coach.refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          if (coach.error != null) Padding(padding: const EdgeInsets.all(8), child: Text(coach.error!, style: const TextStyle(color: AppColors.amber))),
          if (coach.loading && coach.clients.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!coach.loading && coach.clients.isEmpty && coach.error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no tienes clientes. Pulsa «Invitar» para generar un código y dáselo a tu cliente: lo introduce al crear su cuenta en la app de clientes.',
                  style: TextStyle(color: AppColors.muted, fontSize: 16)),
            ),
          for (final c in coach.clients)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(backgroundColor: AppColors.accent, child: Text('${c['name']}'.isEmpty ? '?' : '${c['name']}'[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text([
                  if (_ageOf(c['birth']) != null) '${_ageOf(c['birth'])} años',
                  if (_ageOf(c['birth']) != null && _ageOf(c['birth'])! < 18) (c['guardian_consent'] == true ? 'consentimiento del tutor ✓' : 'SIN consentimiento del tutor'),
                  if ('${c['class_id'] ?? ''}'.isNotEmpty) 'en una clase',
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
              ),
            ),
        ]),
      ),
    );
  }
}

class InviteScreen extends StatefulWidget {
  final String classId;
  const InviteScreen({super.key, this.classId = ''});
  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  List<Map<String, dynamic>> invites = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await context.read<CoachService>().invites();
      if (mounted) setState(() => invites = l);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Códigos de invitación')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Genera un código por cliente. Lo introduce al crear su cuenta en la app de clientes y queda vinculado a ti. Cada código se usa una sola vez.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final code = await coach.createInvite(classId: widget.classId);
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código $code copiado')));
                    await _load();
                  } on ApiException catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          icon: const Icon(Icons.add),
          label: const Text('NUEVO CÓDIGO'),
        ),
        sectionTitle('Códigos'),
        for (final i in invites)
          Card(
            child: ListTile(
              title: Text('${i['code']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6)),
              subtitle: Text(i['used_by'] != null ? 'USADO' : ('${i['class_id'] ?? ''}'.isEmpty ? 'Disponible' : 'Disponible · clase')),
              trailing: i['used_by'] != null
                  ? const Icon(Icons.check_circle, color: AppColors.green)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => Share.share('Tu código para la app de TonyLocuras Entreno: ${i['code']}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await coach.deleteInvite('${i['code']}');
                          await _load();
                        },
                      ),
                    ]),
            ),
          ),
      ]),
    );
  }
}

// ====================================================================== Detalle de cliente

class ClientDetailScreen extends StatelessWidget {
  final Map<String, dynamic> client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final uid = client['uid'] as String;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${client['name']}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'unlink') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('¿Desvincular cliente?'),
                      content: const Text('Dejarás de ver sus datos. Él conserva los suyos.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DESVINCULAR')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await context.read<CoachService>().unlink(uid);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'unlink', child: Text('Desvincular'))],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.accent,
            tabs: [Tab(text: 'Resumen'), Tab(text: 'Plan'), Tab(text: 'Mensajes'), Tab(text: 'Documentos'), Tab(text: 'Notas')],
          ),
        ),
        body: TabBarView(children: [
          _SummaryTab(uid: uid),
          _ClientPlanTab(uid: uid, name: '${client['name']}'),
          _ClientChat(uid: uid),
          _DocsTab(uid: uid, name: '${client['name']}'),
          _NotesTab(uid: uid),
        ]),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final String uid;
  const _SummaryTab({required this.uid});

  Future<Map<String, List<Map<String, dynamic>>>> _load(CoachService c) async {
    final r = <String, List<Map<String, dynamic>>>{};
    for (final col in [Col.wellbeing, Col.tests, Col.logs, Col.expeditions]) {
      r[col] = await c.clientRecords(uid, col);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return FutureBuilder(
      future: _load(coach),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar los datos: ${snap.error}', style: const TextStyle(color: AppColors.amber))));
        final d = snap.data!;
        final well = d[Col.wellbeing]!..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
        final logs = d[Col.logs]!..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
        final tests = d[Col.tests]!..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
        final today = well.where((w) => w['id'] == dayKey(DateTime.now())).toList();
        TrafficResult? tl;
        if (today.isNotEmpty) {
          final w = today.first;
          final v = <String, double>{};
          for (final k in ['sleepH', 'sleepQ', 'fatigue', 'stress', 'motivation']) {
            if (w[k] is num) v[k] = (w[k] as num).toDouble();
          }
          final pains = (w['pain'] as Map?)?.values.whereType<num>().map((e) => e.toDouble()).toList();
          if (pains != null && pains.isNotEmpty) v['pain'] = pains.reduce((a, b) => a > b ? a : b);
          tl = trafficLight(v, defaultRules);
        }
        // carga semanal
        final weekly = <DateTime, double>{};
        for (final l in logs) {
          if (l['epg'] is num && l['minutes'] is num) {
            final dd = DateTime.parse(l['date'] as String);
            final mon = DateTime(dd.year, dd.month, dd.day).subtract(Duration(days: dd.weekday - 1));
            weekly[mon] = (weekly[mon] ?? 0) + sessionLoad((l['epg'] as num).toDouble(), (l['minutes'] as num).toDouble());
          }
        }
        final weeks = weekly.keys.toList()..sort();
        final lastTests = <String, Map<String, dynamic>>{};
        for (final t in tests) {
          lastTests.putIfAbsent('${t['testId']}', () => t);
        }
        final style = tl == null ? null : trafficStyle(tl.color);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              leading: Icon(style?.icon ?? Icons.help_outline, color: style?.color ?? AppColors.muted, size: 36),
              title: Text(tl == null ? 'Sin bienestar de hoy' : '${style!.label} · ${tl.score}', style: TextStyle(fontWeight: FontWeight.w900, color: style?.color)),
              subtitle: Text(tl == null ? 'No ha rellenado el cuestionario.' : (tl.reasons.isEmpty ? 'Sin alertas.' : tl.reasons.join('\n'))),
            ),
          ),
          sectionTitle('Carga semanal (EPG × min)'),
          if (weeks.isEmpty) const Text('Sin sesiones valoradas.', style: TextStyle(color: AppColors.muted)),
          for (final w in weeks.reversed.take(6)) ListTile(dense: true, title: Text('Semana del ${DateFormat('d MMM', 'es').format(w)}'), trailing: Text('${weekly[w]!.round()}', style: const TextStyle(fontWeight: FontWeight.w900))),
          sectionTitle('Últimas sesiones'),
          if (logs.isEmpty) const Text('Aún no ha entrenado.', style: TextStyle(color: AppColors.muted)),
          for (final l in logs.take(6))
            ListTile(dense: true, title: Text('${l['title']}'), subtitle: Text('${l['date']} · ${l['minutes']} min'), trailing: Text(l['epg'] == null ? 'sin EPG' : 'EPG ${l['epg']}')),
          sectionTitle('Últimos tests'),
          if (lastTests.isEmpty) const Text('Sin tests registrados.', style: TextStyle(color: AppColors.muted)),
          for (final t in lastTests.values.take(10))
            ListTile(
              dense: true,
              title: Text('${t['testId']}'),
              subtitle: Text('${t['date']}'),
              trailing: Text(t['value'] != null ? '${t['value']}' : 'I ${t['left'] ?? '-'} / D ${t['right'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final rows = [
                ['tipo', 'fecha', 'detalle'],
                for (final l in logs) ['sesion', '${l['date']}', '${l['title']} ${l['minutes']}min EPG ${l['epg'] ?? ''}'],
                for (final t in tests) ['test', '${t['date']}', '${t['testId']} ${t['value'] ?? '${t['left']}/${t['right']}'}'],
              ];
              final dir = await getTemporaryDirectory();
              final f = File('${dir.path}/cliente_$uid.csv');
              await f.writeAsString(rows.map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(',')).join('\n'));
              await Share.shareXFiles([XFile(f.path)]);
            },
            icon: const Icon(Icons.table_chart),
            label: const Text('EXPORTAR CSV DEL CLIENTE'),
          ),
        ]);
      },
    );
  }
}

class _ClientPlanTab extends StatefulWidget {
  final String uid;
  final String name;
  const _ClientPlanTab({required this.uid, required this.name});
  @override
  State<_ClientPlanTab> createState() => _ClientPlanTabState();
}

class _ClientPlanTabState extends State<_ClientPlanTab> {
  Future<List<Map<String, dynamic>>>? f;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => f = context.read<CoachService>().clientRecords(widget.uid, Col.plan));
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SessionEditor(heading: 'Sesión para ${widget.name}', onSave: (s) => coach.assignSession(widget.uid, s))),
          );
          _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Sesión', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder(
        future: f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.amber)));
          final l = snap.data!..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            if (l.isEmpty) const Text('Sin sesiones. Añade una o genera un borrador con IA en la pestaña IA.', style: TextStyle(color: AppColors.muted)),
            for (final s in l)
              Card(
                child: ListTile(
                  title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s['date']} · ${((s['exercises'] as List?) ?? []).length} ejercicios'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await coach.writeToClient(widget.uid, Col.plan, s, deleted: true);
                      _reload();
                    },
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SessionEditor(heading: 'Editar sesión', session: s, onSave: (n) => coach.assignSession(widget.uid, n))),
                    );
                    _reload();
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _ClientChat extends StatelessWidget {
  final String uid;
  const _ClientChat({required this.uid});
  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return ChatView(
      me: 'coach',
      load: () => coach.clientRecords(uid, Col.messages),
      send: (t) => coach.writeToClient(uid, Col.messages, {'from': 'coach', 'text': t, 'at': DateTime.now().toUtc().toIso8601String()}),
    );
  }
}

class _DocsTab extends StatelessWidget {
  final String uid;
  final String name;
  const _DocsTab({required this.uid, required this.name});

  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return FutureBuilder(
      future: coach.clientRecords(uid, Col.docs),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.amber)));
        final l = snap.data!..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (l.isEmpty) const Text('El cliente no ha enviado documentos.', style: TextStyle(color: AppColors.muted)),
          for (final d in l)
            Card(
              child: ListTile(
                title: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_dt(d['at']) == null ? '' : DateFormat('d MMM y HH:mm', 'es').format(_dt(d['at'])!)} · ${d['label'] ?? ''}'),
                trailing: const Icon(Icons.auto_awesome, color: AppColors.accent),
                onTap: () => _actions(context, d),
              ),
            ),
        ]);
      },
    );
  }

  void _actions(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.download), title: const Text('Descargar / compartir'), onTap: () { Navigator.pop(c); _download(context, d); }),
          const Divider(),
          for (final e in aiKinds.entries)
            ListTile(
              leading: Icon(e.value.icon),
              title: Text('Analizar con IA: ${e.value.label}'),
              onTap: () { Navigator.pop(c); _analyze(context, d, e.key); },
            ),
        ]),
      ),
    );
  }

  Future<void> _download(BuildContext context, Map<String, dynamic> d) async {
    final coach = context.read<CoachService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await coach.api.downloadDoc('${d['path']}');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${d['name']}');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)]);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo descargar: $e')));
    }
  }

  Future<void> _analyze(BuildContext context, Map<String, dynamic> d, String kind) async {
    final coach = context.read<CoachService>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Analizando con IA (puede tardar un minuto)...'), duration: Duration(seconds: 30)));
    try {
      final data = await analyzePath(coach.api, '${d['path']}', kind);
      messenger.hideCurrentSnackBar();
      if (kind == 'plan') {
        await nav.push(MaterialPageRoute(builder: (_) => PlanReviewScreen(data: data, targetLabel: 'plan de $name', saveSession: (s) => coach.assignSession(uid, s))));
      } else {
        await nav.push(MaterialPageRoute(
          builder: (_) => RawResultScreen(
            title: aiKinds[kind]!.label,
            data: data,
            saveLabel: 'GUARDAR COMO NOTA DEL CLIENTE',
            onSave: () => coach.writeToClient(uid, Col.coachNotes, {'kind': kind, 'doc': '${d['name']}', 'data': data, 'at': DateTime.now().toUtc().toIso8601String(), 'text': 'Análisis IA de ${d['name']}'}),
          ),
        ));
      }
    } on ApiException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(e.message), duration: const Duration(seconds: 6)));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('No se pudo analizar: $e')));
    }
  }
}

class _NotesTab extends StatefulWidget {
  final String uid;
  const _NotesTab({required this.uid});
  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final ctl = TextEditingController();
  Future<List<Map<String, dynamic>>>? f;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => f = context.read<CoachService>().clientRecords(widget.uid, Col.coachNotes));

  @override
  Widget build(BuildContext context) {
    final coach = context.read<CoachService>();
    return Column(children: [
      Expanded(
        child: FutureBuilder(
          future: f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final l = (snap.data ?? [])..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Notas privadas tuyas. El cliente puede verlas en sus datos (es su información).', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              for (final n in l)
                Card(
                  child: ListTile(
                    title: Text('${n['text']}'),
                    subtitle: Text('${_dt(n['at']) == null ? '' : DateFormat('d MMM y HH:mm', 'es').format(_dt(n['at'])!)}${n['kind'] != null ? ' · ${n['kind']}' : ''}'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await coach.writeToClient(widget.uid, Col.coachNotes, n, deleted: true); _reload(); }),
                  ),
                ),
            ]);
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            Expanded(child: TextField(controller: ctl, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Nueva nota'))),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(56, 56)),
              onPressed: () async {
                final t = ctl.text.trim();
                if (t.isEmpty) return;
                ctl.clear();
                await coach.writeToClient(widget.uid, Col.coachNotes, {'text': t, 'at': DateTime.now().toUtc().toIso8601String()});
                _reload();
              },
              icon: const Icon(Icons.add),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ====================================================================== Clases

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final cls = st.list(Col.classes)..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return Scaffold(
      appBar: AppBar(title: const Text('Clases')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          final c = TextEditingController();
          final name = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Nueva clase'),
              content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre (ej. Lunes 18:00 · Iniciación)')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('CANCELAR')),
                TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('CREAR')),
              ],
            ),
          );
          if (name != null && name.isNotEmpty) {
            await st.put(Col.classes, {'name': name, 'members': <String>[], 'levels': <String, String>{}, 'attendance': <String, List<String>>{}});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Clase', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        if (cls.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Crea una clase, añade alumnos y envíales la misma sesión con ajustes por nivel.', style: TextStyle(color: AppColors.muted, fontSize: 16))),
        for (final c in cls)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.groups, color: AppColors.accent, size: 32),
              title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              subtitle: Text('${((c['members'] as List?) ?? []).length} alumnos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: c['id'] as String))),
            ),
          ),
      ]),
    );
  }
}

class ClassDetailScreen extends StatefulWidget {
  final String classId;
  const ClassDetailScreen({super.key, required this.classId});
  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  DateTime day = DateTime.now();
  String levelFilter = '*';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final coach = context.watch<CoachService>();
    final cls = st.get(Col.classes, widget.classId);
    if (cls == null) return const Scaffold(body: Center(child: Text('Clase eliminada')));
    final members = [for (final m in ((cls['members'] as List?) ?? [])) '$m'];
    // alumnos que entraron con un código de esta clase
    final viaCode = [for (final c in coach.clients) if (c['class_id'] == widget.classId) c['uid'] as String];
    final all = {...members, ...viaCode}.toList();
    final levels = Map<String, dynamic>.from((cls['levels'] as Map?) ?? {});
    final att = Map<String, dynamic>.from((cls['attendance'] as Map?) ?? {});
    final dk = dayKey(day);
    final present = <String>{for (final u in ((att[dk] as List?) ?? [])) '$u'};

    String nm(String uid) => '${coach.clientByUid(uid)?['name'] ?? uid}';
    Future<void> save(Map<String, dynamic> patch) => st.put(Col.classes, {...cls, ...patch});

    final subgroups = {'*', ...levels.values.map((e) => '$e').where((e) => e.isNotEmpty)};
    return Scaffold(
      appBar: AppBar(title: Text('${cls['name']}'), actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await st.remove(Col.classes, widget.classId);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InviteScreen(classId: widget.classId))),
              icon: const Icon(Icons.qr_code),
              label: const Text('CÓDIGO PARA ESTA CLASE'),
            ),
          ),
        ]),
        sectionTitle('Alumnos (${all.length})'),
        for (final u in all)
          Card(
            child: ListTile(
              title: Text(nm(u)),
              subtitle: DropdownButton<String>(
                value: '${levels[u] ?? ''}',
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [for (final l in ['', 'A', 'B', 'C']) DropdownMenuItem(value: l, child: Text(l.isEmpty ? 'sin nivel' : 'nivel $l'))],
                onChanged: (v) => save({'levels': {...levels, u: v ?? ''}}),
              ),
              trailing: members.contains(u) ? IconButton(icon: const Icon(Icons.close), onPressed: () => save({'members': members.where((m) => m != u).toList()})) : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: coach.clientByUid(u) ?? {'uid': u, 'name': nm(u)}))),
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: null,
          decoration: const InputDecoration(labelText: 'Añadir alumno (de tus clientes)'),
          items: [for (final c in coach.clients) if (!all.contains(c['uid'])) DropdownMenuItem(value: c['uid'] as String, child: Text('${c['name']}'))],
          onChanged: (v) {
            if (v != null) save({'members': [...members, v]});
          },
        ),
        sectionTitle('Asistencia'),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2024), lastDate: DateTime(2031));
            if (d != null) setState(() => day = d);
          },
          icon: const Icon(Icons.event),
          label: Text(DateFormat('EEE d MMM y', 'es').format(day)),
        ),
        for (final u in all)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: present.contains(u),
            onChanged: (v) {
              final s = {...present};
              v == true ? s.add(u) : s.remove(u);
              save({'attendance': {...att, dk: s.toList()}});
            },
            title: Text(nm(u)),
          ),
        Text('Asistencia ${present.length}/${all.length}', style: const TextStyle(color: AppColors.muted)),
        sectionTitle('Enviar sesión a la clase'),
        Wrap(spacing: 8, children: [
          for (final s in subgroups) ChoiceChip(label: Text(s == '*' ? 'Toda la clase' : 'Nivel $s'), selected: levelFilter == s, onSelected: (_) => setState(() => levelFilter = s)),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: all.isEmpty
              ? null
              : () {
                  final targets = [for (final u in all) if (levelFilter == '*' || levels[u] == levelFilter) u];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionEditor(
                        heading: 'Sesión para ${levelFilter == '*' ? 'toda la clase' : 'nivel $levelFilter'} (${targets.length})',
                        onSave: (s) async {
                          var i = 0;
                          for (final u in targets) {
                            await coach.assignSession(u, {...s, 'id': '${newId()}$i', 'classId': widget.classId});
                            i++;
                          }
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviada a ${targets.length} alumnos')));
                        },
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.send),
          label: const Text('CREAR Y ENVIAR SESIÓN'),
        ),
        const SizedBox(height: 8),
        const Text('Cada alumno recibe su copia: puedes ajustar después la de uno concreto en su ficha.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}

// ====================================================================== Más (entrenador)

class CoachMoreScreen extends StatelessWidget {
  const CoachMoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final sync = auth.sync;
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: const Icon(Icons.person), title: Text(auth.name), subtitle: Text('${auth.api.session?.email ?? ''} · entrenador'))),
        Card(
          child: ListTile(
            leading: Icon(sync?.syncing == true ? Icons.sync : Icons.cloud_done, color: AppColors.accent),
            title: Text(sync?.status ?? 'Sin nube'),
            trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: sync?.sync),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.upload_file, color: AppColors.accent),
            title: const Text('Importar con IA (estudios, documentos)'),
            subtitle: const Text('Los estudios que guardes sirven de fuente al borrador de planes'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiImportScreen())),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => context.read<Store>().exportJson(), icon: const Icon(Icons.save_alt), label: const Text('EXPORTAR MIS DATOS (JSON)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await auth.logout();
          },
          icon: const Icon(Icons.logout),
          label: const Text('CERRAR SESIÓN'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('¿Borrar todos mis datos?'),
                content: const Text('Se borran de la nube y de este dispositivo. No se puede deshacer. Los datos de tus clientes son de ellos y no se tocan.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('BORRAR')),
                ],
              ),
            );
            if (ok == true) {
              try {
                await auth.eraseMyData();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
              }
            }
          },
          icon: const Icon(Icons.delete_forever),
          label: const Text('BORRAR MIS DATOS'),
        ),
      ]),
    );
  }
}
