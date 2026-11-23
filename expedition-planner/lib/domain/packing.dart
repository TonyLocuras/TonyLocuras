import 'time_model.dart';

class PackContext {
  final Activity activity;
  final Duration duration;
  final double minTempC, maxUv, maxWindKmh, precipMm;
  const PackContext(this.activity, this.duration, this.minTempC, this.maxUv,
      this.maxWindKmh, this.precipMm);
}

List<String> buildPackList(PackContext c) {
  final hours = c.duration.inMinutes / 60;
  final water = 3.0 + (hours > 4 ? (hours - 4) * 0.5 : 0);
  final l = <String>{'Agua: ${water.toStringAsFixed(1)} L', 'Botiquín básico'};
  if (hours > 3) l.add('Linterna frontal');
  if (c.maxUv >= 3) {
    l
      ..add('Protector solar SPF50+')
      ..add('Gafas de sol categoría 4');
  }
  if (c.minTempC < 5) l.add('Guantes y capa de abrigo');
  if (c.maxWindKmh > 40) l.add('Cortavientos');
  if (c.precipMm > 0.5) l.add('Impermeable');
  if (c.activity == Activity.caving) {
    l
      ..add('Casco')
      ..add('Segunda luz frontal')
      ..add('Kit de cuerdas');
  }
  if (c.activity == Activity.alpine && c.minTempC < 0) l.add('Crampones');
  return l.toList();
}
