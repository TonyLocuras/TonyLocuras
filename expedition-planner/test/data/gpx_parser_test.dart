import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/data/gpx_parser.dart';

const gpx = '''<gpx><trk><trkseg>
<trkpt lat="36.9" lon="-2.0"><ele>120</ele></trkpt>
<trkpt lat="36.91" lon="-2.01"></trkpt></trkseg></trk></gpx>''';

void main() {
  test('parses track points', () {
    final p = parseGpx(gpx);
    expect(p.length, 2);
    expect(p[0].ele, 120);
    expect(p[1].ele, 0);
  });
  test('falls back to rtept', () {
    final p = parseGpx('<gpx><rte><rtept lat="1" lon="2"><ele>5</ele></rtept></rte></gpx>');
    expect(p.single.ele, 5);
  });
  test('invalid xml throws', () {
    expect(() => parseGpx('nope'), throwsFormatException);
  });
  test('no points throws', () {
    expect(() => parseGpx('<gpx></gpx>'), throwsFormatException);
  });
}
