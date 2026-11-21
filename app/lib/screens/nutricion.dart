import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calc.dart';
import '../store.dart';
import '../theme.dart';

class NutricionScreen extends StatefulWidget {
  const NutricionScreen({super.key});
  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen> {
  String dayType = 'entreno';
  double delta = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final w = st.weightKg;
    final h = (st.settings['heightCm'] as num?)?.toDouble() ?? 173;
    final age = (st.settings['age'] as num?)?.toInt() ?? 19;
    final bmr = bmrMifflin(weightKg: w, heightCm: h, age: age);
    final m = dailyMacros(weightKg: w, bmr: bmr, dayType: dayType, kcalDelta: delta);

    Widget macro(String label, String value, Color c) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c)),
                Text(label, style: const TextStyle(color: AppColors.muted)),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'PROVISIONAL: base 1,6 g/kg de proteína y 4-7 g/kg de hidratos según el día. Los criterios definitivos saldrán del estudio cuando lo importes.',
              style: TextStyle(color: AppColors.amber),
            ),
          ),
        ),
        sectionTitle('Tipo de día'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in const {'descanso': 'Descanso', 'entreno': 'Entreno', 'doble': 'Doble sesión', 'expedicion': 'Expedición'}.entries)
            ChoiceChip(
              label: Text(e.value, style: const TextStyle(fontSize: 16)),
              selected: dayType == e.key,
              onSelected: (_) => setState(() => dayType = e.key),
            ),
        ]),
        const SizedBox(height: 12),
        Stepper2(label: 'Ajuste de energía (kcal)', value: delta, step: 100, min: -800, max: 800, onChanged: (x) => setState(() => delta = x)),
        sectionTitle('Objetivo del día · ${w.toStringAsFixed(1)} kg'),
        Row(children: [
          macro('kcal', m.kcal.round().toString(), AppColors.accent),
          macro('proteína g', m.protein.round().toString(), AppColors.left),
        ]),
        Row(children: [
          macro('hidratos g', m.carbs.round().toString(), AppColors.amber),
          macro('grasa g', m.fat.round().toString(), AppColors.green),
        ]),
        Text('TMB (Mifflin-St Jeor): ${bmr.round()} kcal. Se actualiza al cambiar el peso en Más > Ajustes.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        sectionTitle('Siguiente fase'),
        const Text(
          'Comidas con tus alimentos y etiquetas, registro rápido y suplementos con horario llegarán en la siguiente versión. Necesito tu lista de suplementos con dosis.',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
      ]),
    );
  }
}
