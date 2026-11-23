import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/weather.dart';

void main() {
  test('temperature lapse -6.5C/km', () {
    expect(tempAtAltitude(20, 500, 2500), closeTo(7, 0.01));
  });
  test('UV +10% per 1000 m', () {
    expect(uvAtAltitude(6, 2000), closeTo(7.2, 0.01));
  });
  test('wind chill formula', () {
    expect(windChill(0, 20), closeTo(-5.2, 0.2));
    expect(windChill(15, 20), 15);
  });
  test('freezing level', () {
    expect(freezingLevelM(13, 0), closeTo(2000, 1));
  });
  test('burn minutes decreases with UV', () {
    expect(burnMinutes(10), lessThan(burnMinutes(5)));
  });
}
