import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../store.dart';
import '../theme.dart';
import 'ai_screens.dart' show clientUploadDoc;
import 'auth_screens.dart';
import 'chat.dart';
import 'hoy.dart';
import 'plan.dart';
import 'progreso.dart';
import 'tests_tindeq.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int i = 0;
  static const items = [
    (Icons.local_fire_department, 'Hoy'),
    (Icons.calendar_month, 'Plan'),
    (Icons.show_chart, 'Progreso'),
    (Icons.chat_bubble_outline, 'Mensajes'),
    (Icons.more_horiz, 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[const HoyScreen(client: true), const PlanScreen(readOnly: true), const ProgresoScreen(), const _MessagesTab(), const ClientMoreScreen()];
    final wide = MediaQuery.of(context).size.width >= 700;
    final body = IndexedStack(index: i, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: i,
            onDestinationSelected: (x) => setState(() => i = x),
            labelType: NavigationRailLabelType.all,
            indicatorColor: AppColors.accent.withValues(alpha: 0.25),
            destinations: [for (final e in items) NavigationRailDestination(icon: Icon(e.$1), label: Text(e.$2))],
          ),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (x) => setState(() => i = x),
        destinations: [for (final e in items) NavigationDestination(icon: Icon(e.$1), label: e.$2)],
      ),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: ChatView(
        me: 'client',
        load: () async => st.list(Col.messages),
        send: (t) async {
          await st.put(Col.messages, {'from': 'client', 'text': t, 'at': DateTime.now().toUtc().toIso8601String()});
        },
      ),
    );
  }
}

class ClientMoreScreen extends StatefulWidget {
  const ClientMoreScreen({super.key});
  @override
  State<ClientMoreScreen> createState() => _ClientMoreScreenState();
}

class _ClientMoreScreenState extends State<ClientMoreScreen> {
  Map<String, dynamic>? coach;
  bool loaded = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await context.read<AuthController>().api.rpc('my_coach') as List;
      if (mounted) {
        setState(() {
          coach = l.isEmpty ? null : Map<String, dynamic>.from(l.first as Map);
          loaded = true;
          err = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => err = 'Sin conexión');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final st = context.watch<Store>();
    final sync = auth.sync;
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: const Icon(Icons.person), title: Text(auth.name), subtitle: Text(auth.api.session?.email ?? ''))),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sports, color: AppColors.accent),
            title: Text(coach != null ? 'Mi entrenador: ${coach!['name']}' : (loaded ? 'Sin entrenador vinculado' : (err ?? 'Cargando...'))),
            subtitle: Text(coach != null ? 'Ve tus entrenos, tests, bienestar y documentos.' : 'Introduce el código que te dio tu entrenador.'),
            trailing: coach != null
                ? TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('¿Desvincularte?'),
                          content: const Text('Tu entrenador dejará de ver tus datos. Conservas los tuyos.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DESVINCULAR')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await auth.api.delete('coach_links?client=eq.${auth.uid}');
                          await _load();
                        } on ApiException catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                    child: const Text('DESVINCULAR'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemScreen()));
                      await _load();
                    },
                    child: const Text('CÓDIGO'),
                  ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(sync?.syncing == true ? Icons.sync : Icons.cloud_done, color: AppColors.accent),
            title: Text(sync?.status ?? 'Sin nube'),
            trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: sync?.sync),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center, color: AppColors.accent),
            title: const Text('Mis tests', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Registra tus resultados'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsScreen())),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.upload_file, color: AppColors.accent),
            title: const Text('Enviar documento a mi entrenador', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Analítica, bioimpedancia, informes (PDF o foto)'),
            onTap: () => clientUploadDoc(context, label: 'documento'),
          ),
        ),
        sectionTitle('Mis datos'),
        OutlinedButton.icon(onPressed: st.exportJson, icon: const Icon(Icons.save_alt), label: const Text('EXPORTAR (JSON)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => st.exportCsv(Col.logs), icon: const Icon(Icons.table_chart), label: const Text('EXPORTAR SESIONES (CSV)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('¿Borrar todos mis datos?'),
                content: const Text('Se borran de la nube y de este dispositivo y te desvinculas de tu entrenador. No se puede deshacer.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('BORRAR')),
                ],
              ),
            );
            if (ok == true) {
              try {
                await auth.eraseMyData();
                await _load();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
              }
            }
          },
          icon: const Icon(Icons.delete_forever),
          label: const Text('BORRAR MIS DATOS'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: auth.logout, icon: const Icon(Icons.logout), label: const Text('CERRAR SESIÓN')),
      ]),
    );
  }
}
