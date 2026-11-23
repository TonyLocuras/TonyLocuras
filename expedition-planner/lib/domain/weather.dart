import 'dart:math';

double tempAtAltitude(double baseTempC, double baseEleM, double eleM) =>
    baseTempC - 6.5 * (eleM - baseEleM) / 1000;

double windChill(double tempC, double windKmh) {
  if (tempC > 10 || windKmh <= 4.8) return tempC;
  final v = pow(windKmh, 0.16);
  return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v;
}

double uvAtAltitude(double uvBase, double eleM, {double eleBaseM = 0}) =>
    uvBase * (1 + 0.10 * (eleM - eleBaseM) / 1000);

/// Minutes to erythema: MED (J/m2) / (UVI * 0.025 W/m2) / 60, by skin type.
double burnMinutes(double uv, {int skinType = 2}) {
  const med = {1: 200.0, 2: 250.0, 3: 350.0, 4: 450.0};
  if (uv <= 0) return double.infinity;
  return med[skinType]! / (uv * 0.025) / 60;
}

double freezingLevelM(double baseTempC, double baseEleM) =>
    baseEleM + baseTempC / 6.5 * 1000;
