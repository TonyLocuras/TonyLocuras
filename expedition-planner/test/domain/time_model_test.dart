import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/geo.dart';
import 'package:expedition_planner/domain/time_model.dart';

void main() {
  const s = RouteStats(10, 600, 600, 1500, 900);
  test('hiking 10km +600 -600: 2h + 1h + 0.5h', () {
    expect(estimateTime(s).inMinutes, 210);
  });
  test('alpine is slower', () {
    expect(estimateTime(s, activity: Activity.alpine).inMinutes, 294);
  });
  test('heavy pack adds 3 percent per kg over 10', () {
    expect(estimateTime(s, packKg: 12).inMinutes, 223);
  });
}
