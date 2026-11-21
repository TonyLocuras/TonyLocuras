import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});
  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  late Map<String, double> v;
  late Map<String, double> pain;
  final fingerCtl = TextEditingController();

  static const zones = ['Dedos izq', 'Dedos der', 'Hombro', 'Codo', 'Muñeca'];

  @override
  void initState() {
    super.initState();
    final st = context.read<Store>();
    final w = st.wellbeingFor(DateTime.now());
    double g(String k, double d) => (w?[k] as num?)?.toDouble() ?? d;
    v = {
      'sleepH': g('sleepH', 7.5),
      'sleepQ': g('sleepQ', 7),
      'fatigue': g('fatigue', 4),
      'stress': g('stress', 4),
      'motivation': g('motivation', 7),
      'appetite': g('appetite', 7),
      'skin': g('skin', 7),
    };
    final pm = (w?['pain'] as Map?) ?? {};
    pain = {for (final z in zones) z: (pm[z] as num?)?.toDouble() ?? 0};
    fingerCtl.text = (w?['finger'] as String?) ?? '';
  }

  Future<void> _save() async {
    final st = context.read<Store>();
    await st.put(Col.wellbeing, {
      'id': dayKey(DateTime.now()),
      ...v,
      'pain': pain,
      'finger': fingerCtl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienestar de hoy')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        sectionTitle('Sueño y recuperación'),
        Stepper2(label: 'Horas dormidas', value: v['sleepH']!, step: 0.5, max: 14, onChanged: (x) => setState(() => v['sleepH'] = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Calidad de sueño (1-10)', value: v['sleepQ']!, min: 1, max: 10, onChanged: (x) => setState(() => v['sleepQ'] = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Cansancio (1-10)', value: v['fatigue']!, min: 1, max: 10, onChanged: (x) => setState(() => v['fatigue'] = x)),
        sectionTitle('Mente y cuerpo'),
        Stepper2(label: 'Estrés (1-10)', value: v['stress']!, min: 1, max: 10, onChanged: (x) => setState(() => v['stress'] = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Motivación (1-10)', value: v['motivation']!, min: 1, max: 10, onChanged: (x) => setState(() => v['motivation'] = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Apetito (1-10)', value: v['appetite']!, min: 1, max: 10, onChanged: (x) => setState(() => v['appetite'] = x)),
        const SizedBox(height: 8),
        Stepper2(label: 'Piel (1-10)', value: v['skin']!, min: 1, max: 10, onChanged: (x) => setState(() => v['skin'] = x)),
        sectionTitle('Dolor (0-10)'),
        for (final z in zones) ...[
          Stepper2(label: z, value: pain[z]!, min: 0, max: 10, onChanged: (x) => setState(() => pain[z] = x)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: fingerCtl,
          decoration: const InputDecoration(labelText: 'Dedo concreto si hay molestia (opcional)'),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('GUARDAR')),
      ]),
    );
  }
}
