import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../calc.dart';
import '../notifs.dart';
import '../store.dart';
import '../theme.dart';
import 'ai_screens.dart' show AiImportScreen;

double? _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '.'));

/// Un alimento es utilizable si tiene los cuatro valores básicos.
bool foodComplete(Map<String, dynamic> f) =>
    _n(f['kcal']) != null && _n(f['protein']) != null && _n(f['carbs']) != null && _n(f['fat']) != null;

Per100 per100Of(Map<String, dynamic> f) => Per100(_n(f['kcal'])!, _n(f['protein'])!, _n(f['carbs'])!, _n(f['fat'])!);

class NutricionScreen extends StatelessWidget {
  const NutricionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nutrición'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.accent,
            tabs: [Tab(text: 'Hoy'), Tab(text: 'Comidas'), Tab(text: 'Alimentos'), Tab(text: 'Suplementos')],
          ),
        ),
        body: const TabBarView(children: [_DayTab(), _MealsTab(), _FoodsTab(), _SupsTab()]),
      ),
    );
  }
}

// ====================================================================== Hoy

class _DayTab extends StatefulWidget {
  const _DayTab();
  @override
  State<_DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<_DayTab> {
  String dayType = 'entreno';
  double delta = 0;
  final Map<String, String?> chosen = {};

  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final w = st.weightKg;
    final h = _n(st.settings['heightCm']) ?? 173;
    final age = _n(st.settings['age'])?.toInt() ?? 19;
    final bmr = _n(st.settings['bmrKcal']) ?? bmrMifflin(weightKg: w, heightCm: h, age: age);
    final m = dailyMacros(weightKg: w, bmr: bmr, dayType: dayType, kcalDelta: delta);
    final today = dayKey(DateTime.now());
    final logged = st.list(Col.mealLog).where((l) => l['date'] == today).toList();
    final eaten = logged.fold<Macros>(const Macros(0, 0, 0, 0),
        (a, l) => Macros(a.kcal + (_n(l['kcal']) ?? 0), a.protein + (_n(l['protein']) ?? 0), a.carbs + (_n(l['carbs']) ?? 0), a.fat + (_n(l['fat']) ?? 0)));
    final hasStudy = st.list(Col.studies).isNotEmpty;

    Widget macro(String label, double v, double target, Color c) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                Text('${v.round()}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c)),
                Text('/ ${target.round()} $label', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            ),
          ),
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            hasStudy
                ? 'Base provisional (1,6 g/kg de proteína y 4-7 g/kg de hidratos). Tienes un estudio guardado: revisa sus criterios de nutrición y ajusta el delta de energía.'
                : 'PROVISIONAL: base 1,6 g/kg de proteína y 4-7 g/kg de hidratos según el día. Los criterios definitivos saldrán del estudio cuando lo importes.',
            style: const TextStyle(color: AppColors.amber),
          ),
        ),
      ),
      sectionTitle('Tipo de día'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in const {'descanso': 'Descanso', 'entreno': 'Entreno', 'doble': 'Doble sesión', 'expedicion': 'Expedición'}.entries)
          ChoiceChip(label: Text(e.value, style: const TextStyle(fontSize: 16)), selected: dayType == e.key, onSelected: (_) => setState(() => dayType = e.key)),
      ]),
      const SizedBox(height: 12),
      Stepper2(label: 'Ajuste de energía (kcal)', value: delta, step: 100, min: -800, max: 800, onChanged: (x) => setState(() => delta = x)),
      sectionTitle('Objetivo del día · ${w.toStringAsFixed(1)} kg'),
      Row(children: [macro('kcal', eaten.kcal, m.kcal, AppColors.accent), macro('g prot', eaten.protein, m.protein, AppColors.left)]),
      Row(children: [macro('g hidr', eaten.carbs, m.carbs, AppColors.amber), macro('g grasa', eaten.fat, m.fat, AppColors.green)]),
      Text('TMB ${bmr.round()} kcal${_n(st.settings['bmrKcal']) != null ? ' (de tu bioimpedancia)' : ' (Mifflin-St Jeor)'}. Lo comido hoy / objetivo.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      sectionTitle('Comidas de hoy'),
      for (final slot in mealSplit.keys) _slot(context, st, slot, m),
      if (logged.isNotEmpty) ...[
        sectionTitle('Registrado'),
        for (final l in logged)
          ListTile(
            dense: true,
            title: Text('${l['name']}'),
            subtitle: Text('${l['slot']} · ${(_n(l['kcal']) ?? 0).round()} kcal'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => st.remove(Col.mealLog, l['id'] as String)),
          ),
      ],
    ]);
  }

  Widget _slot(BuildContext context, Store st, String slot, Macros day) {
    final share = mealSplit[slot]!;
    final target = Macros(day.kcal * share, day.protein * share, day.carbs * share, day.fat * share);
    final foods = {for (final f in st.list(Col.foods)) f['id'] as String: f};
    final meals = st.list(Col.meals).where((m) => m['slot'] == slot && _mealUsable(m, foods)).toList();
    final sel = meals.where((m) => m['id'] == chosen[slot]).toList();
    final meal = sel.isEmpty ? null : sel.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(slot.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent))),
            Text('${target.kcal.round()} kcal · P${target.protein.round()} H${target.carbs.round()} G${target.fat.round()}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            const Text('Sin comidas utilizables. Crea una en la pestaña Comidas (con alimentos completos y no vetados).', style: TextStyle(color: AppColors.muted))
          else
            DropdownButtonFormField<String>(
              initialValue: meal?['id'] as String?,
              decoration: const InputDecoration(labelText: 'Elige comida'),
              items: [for (final m in meals) DropdownMenuItem(value: m['id'] as String, child: Text('${m['name']}'))],
              onChanged: (v) => setState(() => chosen[slot] = v),
            ),
          if (meal != null) ..._quantities(context, st, meal, foods, target, slot),
        ]),
      ),
    );
  }

  List<Widget> _quantities(BuildContext context, Store st, Map<String, dynamic> meal, Map<String, Map<String, dynamic>> foods, Macros target, String slot) {
    final ing = [for (final i in ((meal['ingredients'] as List?) ?? [])) Map<String, dynamic>.from(i as Map)];
    final fs = [for (final i in ing) foods[i['foodId']]!];
    final p = [for (final f in fs) per100Of(f)];
    final maxG = [for (final i in ing) _n(i['maxG']) ?? 400.0];
    final g = solveQuantities(foods: p, maxGrams: maxG, protein: target.protein, carbs: target.carbs, fat: target.fat);
    final got = macrosOf(p, g);
    return [
      const SizedBox(height: 8),
      for (var i = 0; i < ing.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text('${fs[i]['name']}')),
            Text('${g[i].round()} g', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
      Text('Resultado: ${got.kcal.round()} kcal · P${got.protein.round()} H${got.carbs.round()} G${got.fat.round()}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      if (_prep(fs, g).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Preparación: ${_prep(fs, g)}', style: const TextStyle(fontSize: 13))),
      if ('${meal['notes'] ?? ''}'.isNotEmpty) Text('${meal['notes']}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 8),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
        onPressed: () => st.put(Col.mealLog, {
          'date': dayKey(DateTime.now()),
          'slot': slot,
          'name': meal['name'],
          'mealId': meal['id'],
          'grams': {for (var i = 0; i < ing.length; i++) '${fs[i]['name']}': g[i]},
          'kcal': got.kcal,
          'protein': got.protein,
          'carbs': got.carbs,
          'fat': got.fat,
        }),
        child: const Text('REGISTRAR'),
      ),
    ];
  }
}

String _prep(List<Map<String, dynamic>> fs, List<double> g) {
  final parts = <String>[];
  for (var i = 0; i < fs.length; i++) {
    final m = '${fs[i]['method'] ?? ''}';
    if (m.isNotEmpty && g[i] > 0) parts.add('${fs[i]['name']} (${g[i].round()} g): $m');
  }
  return parts.join('; ');
}

bool _mealUsable(Map<String, dynamic> m, Map<String, Map<String, dynamic>> foods) {
  final ing = (m['ingredients'] as List?) ?? [];
  if (ing.isEmpty) return false;
  for (final i in ing) {
    final f = foods[(i as Map)['foodId']];
    if (f == null || !foodComplete(f) || f['state'] == 'vetado') return false;
  }
  return true;
}

// ====================================================================== Comidas

class _MealsTab extends StatelessWidget {
  const _MealsTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final foods = {for (final f in st.list(Col.foods)) f['id'] as String: f};
    final meals = st.list(Col.meals)..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Comida', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        const Text('Indica el nombre y los ingredientes: la app calcula las cantidades para cuadrar tus macros del día.', style: TextStyle(color: AppColors.muted)),
        for (final m in meals)
          Card(
            child: ListTile(
              title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${m['slot']} · ${((m['ingredients'] as List?) ?? []).length} ingredientes${_mealUsable(m, foods) ? '' : ' · NO UTILIZABLE (alimento incompleto, vetado o borrado)'}'),
              trailing: _mealUsable(m, foods) ? const Icon(Icons.chevron_right) : const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealEditor(meal: m))),
            ),
          ),
      ]),
    );
  }
}

class MealEditor extends StatefulWidget {
  final Map<String, dynamic>? meal;
  const MealEditor({super.key, this.meal});
  @override
  State<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<MealEditor> {
  final name = TextEditingController();
  final notes = TextEditingController();
  String slot = 'comida';
  late List<Map<String, dynamic>> ing;

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    name.text = '${m?['name'] ?? ''}';
    notes.text = '${m?['notes'] ?? ''}';
    slot = '${m?['slot'] ?? 'comida'}';
    ing = [for (final i in ((m?['ingredients'] as List?) ?? [])) Map<String, dynamic>.from(i as Map)];
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    final foods = st.list(Col.foods).where((f) => f['state'] != 'vetado').toList()..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    final byId = {for (final f in st.list(Col.foods)) f['id'] as String: f};
    return Scaffold(
      appBar: AppBar(title: const Text('Comida'), actions: [
        if (widget.meal != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await st.remove(Col.meals, widget.meal!['id'] as String);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre (ej. Pasta con pollo)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: slot,
          decoration: const InputDecoration(labelText: 'Momento'),
          items: [for (final s in mealSplit.keys) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (v) => setState(() => slot = v ?? slot),
        ),
        sectionTitle('Ingredientes'),
        for (var i = 0; i < ing.length; i++)
          Card(
            child: ListTile(
              title: Text('${byId[ing[i]['foodId']]?['name'] ?? '(borrado)'}'),
              subtitle: Text('Máximo ${_n(ing[i]['maxG'])?.round() ?? 400} g'),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => ing.removeAt(i))),
              onTap: () async {
                final c = TextEditingController(text: '${_n(ing[i]['maxG'])?.round() ?? 400}');
                await showDialog<void>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Máximo de gramos'),
                    content: TextField(controller: c, keyboardType: TextInputType.number),
                    actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                  ),
                );
                setState(() => ing[i]['maxG'] = double.tryParse(c.text) ?? 400);
              },
            ),
          ),
        if (foods.isEmpty)
          const Text('Primero crea alimentos en la pestaña Alimentos.', style: TextStyle(color: AppColors.amber))
        else
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: const InputDecoration(labelText: 'Añadir ingrediente'),
            items: [for (final f in foods) DropdownMenuItem(value: f['id'] as String, child: Text('${f['name']}${foodComplete(f) ? '' : ' (incompleto)'}'))],
            onChanged: (v) {
              if (v != null) setState(() => ing.add({'foodId': v, 'maxG': 400.0}));
            },
          ),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas de preparación (opcional)')),
        const SizedBox(height: 8),
        const Text('La preparación sale del método que indiques en cada alimento (hervir, plancha...).', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty || ing.isEmpty) return;
            await st.put(Col.meals, {'id': widget.meal?['id'], 'name': name.text.trim(), 'slot': slot, 'ingredients': ing, 'notes': notes.text.trim()});
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}

// ====================================================================== Alimentos

class _FoodsTab extends StatelessWidget {
  const _FoodsTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final foods = st.list(Col.foods)..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    Color sc(String? s) => s == 'vetado' ? AppColors.crimson : (s == 'tolerado' ? AppColors.amber : AppColors.green);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          builder: (c) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(leading: const Icon(Icons.edit), title: const Text('Formulario manual'), onTap: () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodEditor())); }),
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Foto de la etiqueta (IA)'), onTap: () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (_) => const AiImportScreen())); }),
              ListTile(leading: const Icon(Icons.qr_code), title: const Text('Código de barras (escribir número)'), onTap: () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodEditor(askBarcode: true))); }),
              ListTile(leading: const Icon(Icons.table_chart), title: const Text('Importar lista CSV'), onTap: () { Navigator.pop(c); _importCsv(context); }),
            ]),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Alimento', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        const Text('Verde = permitido · Ámbar = tolerado · Rojo = vetado (no se usa en comidas). Los incompletos no cuentan hasta que añadas los datos.', style: TextStyle(color: AppColors.muted)),
        for (final f in foods)
          Card(
            child: ListTile(
              leading: Icon(Icons.circle, color: sc(f['state'] as String?), size: 16),
              title: Text('${f['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(foodComplete(f)
                  ? '${_n(f['kcal'])!.round()} kcal · P${_n(f['protein'])!.toStringAsFixed(1)} H${_n(f['carbs'])!.toStringAsFixed(1)} G${_n(f['fat'])!.toStringAsFixed(1)} /100 g'
                  : 'INCOMPLETO: falta kcal, proteína, hidratos o grasa'),
              trailing: foodComplete(f) ? null : const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodEditor(food: f))),
            ),
          ),
      ]),
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final st = context.read<Store>();
    final messenger = ScaffoldMessenger.of(context);
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (f == null || f.path == null) return;
    try {
      final lines = const LineSplitter().convert(await File(f.path!).readAsString());
      if (lines.length < 2) throw 'archivo vacío';
      final sep = lines.first.contains(';') ? ';' : ',';
      final head = lines.first.split(sep).map((e) => e.trim().toLowerCase()).toList();
      int idx(List<String> names) => head.indexWhere((h) => names.any((n) => h.contains(n)));
      final iN = idx(['nombre', 'name', 'alimento']);
      final iK = idx(['kcal', 'energ']);
      final iP = idx(['prot']);
      final iC = idx(['hidr', 'carb']);
      final iF = idx(['grasa', 'fat']);
      if (iN < 0) throw 'no encuentro la columna "nombre"';
      var n = 0;
      for (final l in lines.skip(1)) {
        final c = l.split(sep);
        if (c.length <= iN || c[iN].trim().isEmpty) continue;
        double? g(int i) => i < 0 || i >= c.length ? null : double.tryParse(c[i].trim().replaceAll(',', '.'));
        await st.put(Col.foods, {'id': '${newId()}$n', 'name': c[iN].trim(), 'kcal': g(iK), 'protein': g(iP), 'carbs': g(iC), 'fat': g(iF), 'state': 'permitido'}, notify: false);
        n++;
      }
      st.refresh();
      messenger.showSnackBar(SnackBar(content: Text('$n alimentos importados (revisa los incompletos)')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
    }
  }
}

class FoodEditor extends StatefulWidget {
  final Map<String, dynamic>? food;
  final Map<String, dynamic>? prefill; // de la lectura de etiqueta (IA)
  final bool askBarcode;
  const FoodEditor({super.key, this.food, this.prefill, this.askBarcode = false});
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<FoodEditor> {
  static const nums = {'kcal': 'kcal', 'protein': 'Proteína (g)', 'carbs': 'Hidratos (g)', 'sugars': 'Azúcares (g)', 'fat': 'Grasa (g)', 'saturated': 'Saturadas (g)', 'fiber': 'Fibra (g)', 'salt': 'Sal (g)'};
  final ctl = <String, TextEditingController>{};
  final name = TextEditingController();
  final barcode = TextEditingController();
  String state = 'permitido';
  String method = '';
  bool looking = false;

  @override
  void initState() {
    super.initState();
    final src = widget.food ?? widget.prefill ?? {};
    name.text = '${src['name'] ?? ''}'.replaceAll('null', '');
    state = '${src['state'] ?? 'permitido'}';
    method = '${src['method'] ?? ''}';
    for (final k in nums.keys) {
      ctl[k] = TextEditingController(text: src[k] == null ? '' : '${src[k]}');
    }
  }

  Future<void> _lookup() async {
    final code = barcode.text.trim();
    if (code.length < 8) return;
    setState(() => looking = true);
    try {
      final r = await http.get(Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,nutriments')).timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['status'] != 1) throw 'Producto no encontrado';
      final p = j['product'] as Map<String, dynamic>;
      final n = (p['nutriments'] as Map?) ?? {};
      setState(() {
        name.text = '${p['product_name'] ?? name.text}';
        void s(String k, String off) {
          final v = n[off];
          if (v is num) ctl[k]!.text = '$v';
        }
        s('kcal', 'energy-kcal_100g');
        s('protein', 'proteins_100g');
        s('carbs', 'carbohydrates_100g');
        s('sugars', 'sugars_100g');
        s('fat', 'fat_100g');
        s('saturated', 'saturated-fat_100g');
        s('fiber', 'fiber_100g');
        s('salt', 'salt_100g');
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos de Open Food Facts: compruébalos con la etiqueta')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e. Rellénalo a mano.')));
    } finally {
      if (mounted) setState(() => looking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    final unc = ((widget.prefill?['uncertain'] as List?) ?? []).map((e) => '$e').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Alimento'), actions: [
        if (widget.food != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await st.remove(Col.foods, widget.food!['id'] as String);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final u in unc) Text('• $u', style: const TextStyle(color: AppColors.amber)),
        if (widget.askBarcode || widget.food == null) ...[
          Row(children: [
            Expanded(child: TextField(controller: barcode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Código de barras (opcional)'))),
            const SizedBox(width: 8),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 56)), onPressed: looking ? null : _lookup, child: Text(looking ? '...' : 'BUSCAR')),
          ]),
          const SizedBox(height: 12),
        ],
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 4),
        const Text('Valores por 100 g. Si no los sabes, déjalos vacíos: el alimento queda como INCOMPLETO.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        for (final e in nums.entries) ...[
          const SizedBox(height: 10),
          TextField(
            controller: ctl[e.key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: e.value,
              suffixIcon: ctl[e.key]!.text.isEmpty && {'kcal', 'protein', 'carbs', 'fat'}.contains(e.key) ? const Icon(Icons.warning_amber_rounded, color: AppColors.amber) : null,
            ),
          ),
        ],
        sectionTitle('Estado'),
        Wrap(spacing: 8, children: [
          for (final s in ['permitido', 'tolerado', 'vetado'])
            ChoiceChip(label: Text(s), selected: state == s, onSelected: (_) => setState(() => state = s)),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'Método de preparación'),
          items: [for (final m in ['', 'hervir', 'plancha', 'horno', 'sartén', 'microondas', 'crudo / sin cocinar', 'revuelto']) DropdownMenuItem(value: m, child: Text(m.isEmpty ? '(ninguno)' : m))],
          onChanged: (v) => setState(() => method = v ?? ''),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final doc = <String, dynamic>{'id': widget.food?['id'], 'name': name.text.trim(), 'state': state, 'method': method};
            for (final k in nums.keys) {
              doc[k] = double.tryParse(ctl[k]!.text.trim().replaceAll(',', '.'));
            }
            await st.put(Col.foods, doc);
            if (context.mounted) {
              if (widget.prefill != null) {
                Navigator.popUntil(context, (r) => r.isFirst);
              } else {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}

// ====================================================================== Suplementos

class _SupsTab extends StatelessWidget {
  const _SupsTab();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<Store>();
    final sups = st.list(Col.supplements)..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    final today = dayKey(DateTime.now());
    final taken = st.list(Col.supLog).where((l) => l['date'] == today).map((l) => '${l['supId']}|${l['time']}').toSet();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Suplemento', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        const Text('Añade los que tomes con dosis y horas: la app te avisa y registras cada toma.', style: TextStyle(color: AppColors.muted)),
        sectionTitle('Hoy'),
        if (sups.isEmpty) const Text('Aún no hay suplementos. Dime la lista con dosis o créalos aquí.', style: TextStyle(color: AppColors.muted)),
        for (final s in sups)
          for (final t in (((s['times'] as List?) ?? []).isEmpty ? [''] : (s['times'] as List)))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: taken.contains('${s['id']}|$t'),
              onChanged: (v) async {
                if (v == true) {
                  await st.put(Col.supLog, {'date': today, 'supId': s['id'], 'time': '$t', 'name': s['name']});
                } else {
                  for (final l in st.list(Col.supLog).where((l) => l['date'] == today && l['supId'] == s['id'] && '${l['time']}' == '$t')) {
                    await st.remove(Col.supLog, l['id'] as String);
                  }
                }
              },
              title: Text('${s['name']} · ${s['dose'] ?? ''} ${s['unit'] ?? ''}'),
              subtitle: Text('${t == '' ? 'sin hora' : t} ${s['note'] ?? ''}'),
            ),
        sectionTitle('Configurados'),
        for (final s in sups)
          Card(
            child: ListTile(
              title: Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${s['dose'] ?? ''} ${s['unit'] ?? ''} · ${((s['times'] as List?) ?? []).join(', ')}${s['enabled'] == false ? ' · pausado' : ''}'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupEditor(sup: s))),
            ),
          ),
      ]),
    );
  }
}

class SupEditor extends StatefulWidget {
  final Map<String, dynamic>? sup;
  const SupEditor({super.key, this.sup});
  @override
  State<SupEditor> createState() => _SupEditorState();
}

class _SupEditorState extends State<SupEditor> {
  final name = TextEditingController();
  final dose = TextEditingController();
  final unit = TextEditingController(text: 'g');
  final note = TextEditingController();
  List<String> times = [];
  bool enabled = true;

  @override
  void initState() {
    super.initState();
    final s = widget.sup;
    if (s != null) {
      name.text = '${s['name']}';
      dose.text = '${s['dose'] ?? ''}';
      unit.text = '${s['unit'] ?? 'g'}';
      note.text = '${s['note'] ?? ''}';
      times = [for (final t in ((s['times'] as List?) ?? [])) '$t'];
      enabled = s['enabled'] != false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Suplemento'), actions: [
        if (widget.sup != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await st.remove(Col.supplements, widget.sup!['id'] as String);
              await Notifs.instance.rescheduleAll(st);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre (ej. Creatina, Whey, Beta-alanina)')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: dose, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Dosis'))),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unidad'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota (ej. con comida, antes de sesión de tendón)')),
        sectionTitle('Horas de toma (recordatorio)'),
        Wrap(spacing: 8, children: [
          for (final t in times) InputChip(label: Text(t), onDeleted: () => setState(() => times.remove(t))),
          ActionChip(
            avatar: const Icon(Icons.add),
            label: const Text('Añadir hora'),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
              if (t != null) setState(() => times.add('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
            },
          ),
        ]),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: enabled, onChanged: (v) => setState(() => enabled = v), title: const Text('Activo (con recordatorios)')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await st.put(Col.supplements, {
              'id': widget.sup?['id'],
              'name': name.text.trim(),
              'dose': dose.text.trim(),
              'unit': unit.text.trim(),
              'note': note.text.trim(),
              'times': times,
              'enabled': enabled,
            });
            await Notifs.instance.rescheduleAll(st);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('GUARDAR'),
        ),
      ]),
    );
  }
}
