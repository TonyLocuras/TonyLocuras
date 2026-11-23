import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/domain/geo.dart';

void main() {
  test('haversine ~111.19 km per degree latitude', () {
    final d = haversineKm(const LatLngEle(0, 0, 0), const LatLngEle(1, 0, 0));
    expect(d, closeTo(111.19, 0.6));
  });
  test('stats: gain, loss, max', () {
    final s = computeStats(const [
      LatLngEle(0, 0, 100), LatLngEle(0.01, 0, 200), LatLngEle(0.02, 0, 150)]);
    expect(s.gainM, 100);
    expect(s.lossM, 50);
    expect(s.maxEle, 200);
  });
  test('noise under 3 m ignored', () {
    final s = computeStats(const [
      LatLngEle(0, 0, 100), LatLngEle(0.001, 0, 102), LatLngEle(0.002, 0, 100)]);
    expect(s.gainM, 0);
  });
  test('empty route is zeros', () {
    final s = computeStats(const []);
    expect(s.km, 0);
    expect(s.gainM, 0);
  });
}
