import 'package:flutter_test/flutter_test.dart';
import 'package:tonylocuras_entreno/calc.dart';

void main() {
  test('carga por porcentaje', () {
    expect(loadFromPercent(100, 85), 85);
    expect(loadFromPercent(60.8, 50), closeTo(30.4, 1e-9));
  });

  test('fuerza relativa y asimetria', () {
    expect(relativeStrength(60.8, 60.8), 1);
    expect(asymmetryPct(50, 40), closeTo(20, 1e-9));
    expect(asymmetryPct(40, 50), closeTo(20, 1e-9));
    expect(asymmetryPct(0, 0), 0);
  });

  test('sRPE y subida semanal', () {
    expect(sessionLoad(7, 120), 840);
    expect(weeklyLoadJumpPct(1200, [1000, 1000]), closeTo(20, 1e-9));
    expect(weeklyLoadJumpPct(1200, []), isNull);
  });

  test('curva de fuerza', () {
    final s = [
      const ForceSample(0, 0),
      const ForceSample(0.1, 20),
      const ForceSample(0.2, 40),
      const ForceSample(0.5, 60),
      const ForceSample(1.0, 50),
    ];
    expect(peakForce(s), 60);
    expect(timeToPeak(s), closeTo(0.5, 1e-9));
    expect(rfd(s, windowS: 0.2), closeTo(200, 1e-9));
    expect(meanForce(s), closeTo(34, 1e-9));
  });

  test('fuerza critica provisional', () {
    final reps = <double>[60, 55, 50, 45, 42, 40, 40, 40, 40, 40];
    final r = criticalForce(reps, lastN: 4);
    expect(r.cf, closeTo(40, 1e-9));
    expect(r.wPrime, greaterThan(0));
  });

  test('nutricion provisional', () {
    final bmr = bmrMifflin(weightKg: 60.8, heightCm: 173, age: 19);
    expect(bmr, closeTo(1000 * 0 + 10 * 60.8 + 6.25 * 173 - 95 + 5, 1e-9));
    final m = dailyMacros(weightKg: 60.8, bmr: bmr, dayType: 'entreno');
    expect(m.protein, closeTo(97.28, 1e-6));
    expect(m.carbs, closeTo(364.8, 1e-6));
    expect(m.fat, greaterThanOrEqualTo(0.8 * 60.8));
  });

  test('semaforo', () {
    final ok = trafficLight({'sleepH': 8, 'fatigue': 3, 'pain': 0}, defaultRules);
    expect(ok.color, 'green');
    expect(ok.score, 100);
    final bad = trafficLight({'sleepH': 4, 'fatigue': 8, 'pain': 6}, defaultRules);
    expect(bad.color, 'red');
    expect(bad.reasons.length, 3);
    // campo ausente => regla no aplicada
    final missing = trafficLight({}, defaultRules);
    expect(missing.score, 100);
    // regla desactivada
    final off = trafficLight({'pain': 9},
        [for (final r in defaultRules) r.id == 'pain' ? r.copyWith(enabled: false) : r]);
    expect(off.score, 100);
  });
}
