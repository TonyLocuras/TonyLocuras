import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/packing.dart';
import 'package:expedition_planner/domain/time_model.dart';

PackContext ctx({Activity a = Activity.hiking, int h = 5, double t = 10,
        double uv = 2, double w = 10, double p = 0}) =>
    PackContext(a, Duration(hours: h), t, uv, w, p);

void main() {
  test('water scales with duration', () {
    expect(buildPackList(ctx(h: 8)), contains('Agua: 5.0 L'));
  });
  test('sun protection at UV 3+', () {
    expect(buildPackList(ctx(uv: 5)), contains('Protector solar SPF50+'));
    expect(buildPackList(ctx(uv: 1)), isNot(contains('Protector solar SPF50+')));
  });
  test('cold gear below 5C', () {
    expect(buildPackList(ctx(t: 2)), contains('Guantes y capa de abrigo'));
  });
  test('caving kit', () {
    final l = buildPackList(ctx(a: Activity.caving));
    expect(l, containsAll(['Casco', 'Segunda luz frontal', 'Kit de cuerdas']));
  });
  test('crampons only alpine below 0C', () {
    expect(buildPackList(ctx(a: Activity.alpine, t: -3)), contains('Crampones'));
    expect(buildPackList(ctx(a: Activity.hiking, t: -3)), isNot(contains('Crampones')));
  });
  test('no duplicates', () {
    final l = buildPackList(ctx(a: Activity.caving, h: 9));
    expect(l.toSet().length, l.length);
  });
}
