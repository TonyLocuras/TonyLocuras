/// Módulo de cálculos. Sin dependencias de Flutter, para poder testearlo.
/// Cada función indica su fuente o su carácter provisional.
library;

import 'dart:math' as math;

const double kgToN = 9.80665;

double kgFromN(double n) => n / kgToN;
double nFromKg(double kg) => kg * kgToN;

/// Carga objetivo = porcentaje del máximo del test.
double loadFromPercent(double maxValue, double percent) => maxValue * percent / 100.0;

/// Fuerza relativa = valor / peso corporal.
double relativeStrength(double value, double bodyWeightKg) =>
    bodyWeightKg <= 0 ? 0 : value / bodyWeightKg;

/// Asimetría en % respecto al lado más fuerte: (fuerte - débil) / fuerte * 100.
double asymmetryPct(double left, double right) {
  final strong = math.max(left, right);
  final weak = math.min(left, right);
  if (strong <= 0) return 0;
  return (strong - weak) / strong * 100.0;
}

/// Carga de sesión (sRPE de Foster) = EPG × minutos reales.
double sessionLoad(double epg, double minutes) => epg * minutes;

/// Subida de carga semanal en % frente a la media de las semanas previas.
/// Devuelve null si no hay historial.
double? weeklyLoadJumpPct(double current, List<double> previousWeeks) {
  final prev = previousWeeks.where((v) => v > 0).toList();
  if (prev.isEmpty) return null;
  final avg = prev.reduce((a, b) => a + b) / prev.length;
  if (avg <= 0) return null;
  return (current - avg) / avg * 100.0;
}

/// Una muestra de fuerza: tiempo en segundos y fuerza en kg.
class ForceSample {
  final double t;
  final double kg;
  const ForceSample(this.t, this.kg);
}

double peakForce(List<ForceSample> s) =>
    s.isEmpty ? 0 : s.map((e) => e.kg).reduce(math.max);

double meanForce(List<ForceSample> s) =>
    s.isEmpty ? 0 : s.map((e) => e.kg).reduce((a, b) => a + b) / s.length;

/// Tiempo (s) desde el inicio hasta alcanzar el pico.
double timeToPeak(List<ForceSample> s) {
  if (s.isEmpty) return 0;
  var best = s.first;
  for (final e in s) {
    if (e.kg > best.kg) best = e;
  }
  return best.t - s.first.t;
}

/// RFD (kg/s) entre el inicio y [windowS] segundos.
double rfd(List<ForceSample> s, {double windowS = 0.2}) {
  if (s.length < 2) return 0;
  final t0 = s.first.t;
  ForceSample? end;
  for (final e in s) {
    if (e.t - t0 <= windowS) end = e;
  }
  if (end == null || end.t - t0 <= 0) return 0;
  return (end.kg - s.first.kg) / (end.t - t0);
}

/// Fuerza crítica a partir de las fuerzas medias de cada repetición de un
/// all-out 7:3. PROVISIONAL: CF = media de las últimas [lastN] repeticiones;
/// W' = impulso (kg·s) por encima de CF en todas las repeticiones.
/// La definición exacta se fijará contra la literatura y el estudio.
({double cf, double wPrime}) criticalForce(List<double> repMeans,
    {int lastN = 6, double workSeconds = 7}) {
  if (repMeans.isEmpty) return (cf: 0, wPrime: 0);
  final n = math.min(lastN, repMeans.length);
  final tail = repMeans.sublist(repMeans.length - n);
  final cf = tail.reduce((a, b) => a + b) / n;
  var w = 0.0;
  for (final m in repMeans) {
    if (m > cf) w += (m - cf) * workSeconds;
  }
  return (cf: cf, wPrime: w);
}

/// TMB de Mifflin-St Jeor (hombre). PROVISIONAL, sustituible por bioimpedancia.
double bmrMifflin({
  required double weightKg,
  required double heightCm,
  required int age,
  bool male = true,
}) =>
    10 * weightKg + 6.25 * heightCm - 5 * age + (male ? 5 : -161);

/// Factores de actividad provisionales por tipo de día.
const Map<String, double> activityFactor = {
  'descanso': 1.35,
  'entreno': 1.65,
  'doble': 1.85,
  'expedicion': 1.9,
};

class Macros {
  final double kcal, protein, carbs, fat;
  const Macros(this.kcal, this.protein, this.carbs, this.fat);
}

/// Energía y macros. PROVISIONAL hasta importar el estudio:
/// proteína 1,6 g/kg; carbohidratos 5-7 g/kg en entreno (6 por defecto),
/// 4 en descanso, 7 en doble/expedición; grasa por diferencia con mínimo 0,8 g/kg.
Macros dailyMacros({
  required double weightKg,
  required double bmr,
  required String dayType,
  double kcalDelta = 0,
}) {
  final factor = activityFactor[dayType] ?? 1.5;
  final kcal = bmr * factor + kcalDelta;
  final protein = 1.6 * weightKg;
  final carbPerKg = switch (dayType) {
    'descanso' => 4.0,
    'doble' || 'expedicion' => 7.0,
    _ => 6.0,
  };
  final carbs = carbPerKg * weightKg;
  var fat = (kcal - protein * 4 - carbs * 4) / 9;
  final minFat = 0.8 * weightKg;
  if (fat < minFat) fat = minFat;
  return Macros(kcal, protein, carbs, fat);
}

/// Una regla del semáforo: editable por el usuario.
class TrafficRule {
  final String id;
  final String label;
  final String field; // sleepH, sleepQ, fatigue, pain, stress, motivation, expH
  final String op; // lt, gt
  final double threshold;
  final double penalty;
  final bool enabled;
  const TrafficRule({
    required this.id,
    required this.label,
    required this.field,
    required this.op,
    required this.threshold,
    required this.penalty,
    this.enabled = true,
  });

  TrafficRule copyWith({double? threshold, double? penalty, bool? enabled}) =>
      TrafficRule(
        id: id,
        label: label,
        field: field,
        op: op,
        threshold: threshold ?? this.threshold,
        penalty: penalty ?? this.penalty,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'field': field,
        'op': op,
        'threshold': threshold,
        'penalty': penalty,
        'enabled': enabled,
      };

  factory TrafficRule.fromJson(Map<String, dynamic> j) => TrafficRule(
        id: j['id'] as String,
        label: j['label'] as String,
        field: j['field'] as String,
        op: j['op'] as String,
        threshold: (j['threshold'] as num).toDouble(),
        penalty: (j['penalty'] as num).toDouble(),
        enabled: j['enabled'] as bool? ?? true,
      );
}

/// Reglas por defecto. TODAS provisionales hasta importar el estudio.
const List<TrafficRule> defaultRules = [
  TrafficRule(id: 'sleepH', label: 'Sueño menos de (h)', field: 'sleepH', op: 'lt', threshold: 6, penalty: 15),
  TrafficRule(id: 'sleepQ', label: 'Calidad de sueño menor o igual a', field: 'sleepQ', op: 'le', threshold: 5, penalty: 10),
  TrafficRule(id: 'fatigue', label: 'Cansancio mayor o igual a', field: 'fatigue', op: 'ge', threshold: 7, penalty: 15),
  TrafficRule(id: 'pain', label: 'Dolor máximo mayor o igual a', field: 'pain', op: 'ge', threshold: 5, penalty: 25),
  TrafficRule(id: 'stress', label: 'Estrés mayor o igual a', field: 'stress', op: 'ge', threshold: 8, penalty: 10),
  TrafficRule(id: 'motivation', label: 'Motivación menor o igual a', field: 'motivation', op: 'le', threshold: 4, penalty: 10),
  TrafficRule(id: 'expH', label: 'Horas desde el fin de expedición menos de', field: 'expH', op: 'lt', threshold: 48, penalty: 30),
];

bool _match(String op, double value, double t) => switch (op) {
      'lt' => value < t,
      'le' => value <= t,
      'gt' => value > t,
      'ge' => value >= t,
      _ => false,
    };

class TrafficResult {
  final int score;
  final String color; // green, amber, red
  final List<String> reasons;
  const TrafficResult(this.score, this.color, this.reasons);
}

/// Calcula el semáforo. [values] lleva los campos disponibles; si falta un
/// campo, su regla no se aplica (no se inventan datos).
TrafficResult trafficLight(
  Map<String, double> values,
  List<TrafficRule> rules, {
  double greenFrom = 75,
  double amberFrom = 50,
}) {
  var score = 100.0;
  final reasons = <String>[];
  for (final r in rules) {
    if (!r.enabled) continue;
    final v = values[r.field];
    if (v == null) continue;
    if (_match(r.op, v, r.threshold)) {
      score -= r.penalty;
      reasons.add('${r.label} ${_fmt(r.threshold)} (valor ${_fmt(v)}): -${_fmt(r.penalty)}');
    }
  }
  if (score < 0) score = 0;
  final color = score >= greenFrom ? 'green' : (score >= amberFrom ? 'amber' : 'red');
  return TrafficResult(score.round(), color, reasons);
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ============================================================ Comidas y recuperación

/// Macros por 100 g de un alimento.
class Per100 {
  final double kcal, protein, carbs, fat;
  const Per100(this.kcal, this.protein, this.carbs, this.fat);
}

/// Ajusta los gramos de cada ingrediente para acercarse a los macros objetivo
/// (proteína, hidratos, grasa) respetando un máximo de gramos por ingrediente.
/// Descenso por coordenadas con límites: simple, estable y determinista.
/// Devuelve gramos redondeados a 5 g.
List<double> solveQuantities({
  required List<Per100> foods,
  required List<double> maxGrams,
  required double protein,
  required double carbs,
  required double fat,
  int passes = 400,
}) {
  final n = foods.length;
  final g = List<double>.filled(n, 0);
  if (n == 0) return g;
  // vectores por gramo
  final m = [for (final f in foods) [f.protein / 100, f.carbs / 100, f.fat / 100]];
  final target = [protein, carbs, fat];
  for (var it = 0; it < passes; it++) {
    for (var i = 0; i < n; i++) {
      final cur = [0.0, 0.0, 0.0];
      for (var j = 0; j < n; j++) {
        for (var k = 0; k < 3; k++) {
          cur[k] += g[j] * m[j][k];
        }
      }
      var dot = 0.0, norm = 0.0;
      for (var k = 0; k < 3; k++) {
        dot += (target[k] - cur[k]) * m[i][k];
        norm += m[i][k] * m[i][k];
      }
      if (norm <= 0) continue;
      g[i] = (g[i] + dot / norm).clamp(0.0, maxGrams[i]).toDouble();
    }
  }
  return [for (final x in g) (x / 5).round() * 5.0];
}

/// Macros totales de unas cantidades.
Macros macrosOf(List<Per100> foods, List<double> grams) {
  var kcal = 0.0, p = 0.0, c = 0.0, f = 0.0;
  for (var i = 0; i < foods.length; i++) {
    final q = grams[i] / 100;
    kcal += foods[i].kcal * q;
    p += foods[i].protein * q;
    c += foods[i].carbs * q;
    f += foods[i].fat * q;
  }
  return Macros(kcal, p, c, f);
}

/// Reparto de la energía del día entre comidas (PROVISIONAL, editable).
const Map<String, double> mealSplit = {'desayuno': 0.25, 'comida': 0.35, 'cena': 0.25, 'snack': 0.15};

class RecoveryStep {
  final String when;
  final String text;
  const RecoveryStep(this.when, this.text);
}

/// Pauta de vuelta de expedición. PROVISIONAL: valores generales de rehidratación
/// y recarga, NO salen del estudio. Se sustituyen cuando se importe el estudio.
List<RecoveryStep> returnProtocol({
  required double hours,
  required double weightKg,
  double? weightLostKg,
}) {
  final lost = weightLostKg ?? 0;
  final fluidL = lost > 0 ? lost * 1.5 : null; // 150 % del peso perdido
  final carbsG = (weightKg * (hours >= 48 ? 1.0 : 1.2));
  return [
    RecoveryStep('0-1 h',
        'Sorbos de agua con electrolitos (unos 500-700 mg de sodio por litro), 150-250 ml cada 10-15 min. No beber de golpe.'),
    RecoveryStep(
        '1-6 h',
        fluidL == null
            ? 'Sigue hidratándote de forma pautada. Registra el peso para calcular el volumen total (150 % del peso perdido).'
            : 'Volumen objetivo ~${fluidL.toStringAsFixed(1)} L (150 % del peso perdido), repartido, con sodio. Máximo orientativo 1 L/h.'),
    RecoveryStep('Primera comida (1-2 h)',
        'Porción pequeña y fácil de digerir: ~${carbsG.round()} g de hidratos (pasta blanca, arroz, yogur o leche) y 20-25 g de proteína. Sin grasas pesadas.'),
    RecoveryStep(
        hours >= 48 ? '24-72 h' : '24 h',
        hours >= 48
            ? 'Reintroducción progresiva: sube las comidas poco a poco, 5-6 tomas pequeñas al día, y vuelve a tus macros normales a lo largo de 2-3 días.'
            : 'Vuelve a tus macros de día de entreno; prioriza hidratos y proteína en las primeras 24 h.'),
    const RecoveryStep('Señales de alerta',
        'Mareo intenso, confusión, vómitos persistentes, orina muy escasa u oscura o latidos irregulares: atención médica.'),
  ];
}
