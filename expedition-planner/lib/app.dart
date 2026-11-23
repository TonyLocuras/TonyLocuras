import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/state.dart';
import 'ui/theme.dart';
import 'ui/wizard/analysis_step.dart';
import 'ui/wizard/route_step.dart';
import 'ui/wizard/where_step.dart';

class ExpeditionApp extends StatelessWidget {
  const ExpeditionApp({super.key});
  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) => MaterialApp(
          title: 'Expedition Planner',
          theme: tacticalTheme(night: ref.watch(nightProvider)),
          home: const WizardPage(),
        ),
      );
}

class WizardPage extends ConsumerWidget {
  const WizardPage({super.key});
  static const _titles = ['DÓNDE', 'RUTA', 'ANÁLISIS'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(stepProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepara tu ruta',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Modo nocturno rojo',
            onPressed: () => ref.read(nightProvider.notifier).toggle(),
            icon: const Icon(Icons.nightlight_round),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (var i = 0; i < 3; i++)
              TextButton(
                onPressed: () => ref.read(stepProvider.notifier).go(i),
                child: Text('${i + 1} ${_titles[i]}',
                    style: TextStyle(
                        fontWeight: i == step ? FontWeight.w900 : FontWeight.w400)),
              ),
          ]),
        ),
        Expanded(
          child: switch (step) {
            0 => const WhereStep(),
            1 => const RouteStep(),
            _ => const AnalysisStep(),
          },
        ),
      ]),
    );
  }
}
