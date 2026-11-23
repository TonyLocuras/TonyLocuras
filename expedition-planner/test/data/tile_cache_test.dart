import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expedition_planner/data/tile_cache.dart';

void main() {
  const box = GeoBounds(south: 0, west: 0, north: 0.1, east: 0.1);

  test('estimateTiles matches hand-computed counts', () {
    expect(estimateTiles(box, 12, 12), 6);
    expect(estimateTiles(box, 13, 13), 12);
    expect(estimateTiles(box, 12, 13), 18);
  });

  test('download refuses more than 2000 tiles', () async {
    final dir = Directory.systemTemp.createTempSync('tiles');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = TileCache(dir, client: MockClient((_) async => http.Response('x', 200)));
    const big = GeoBounds(south: 36, west: -3, north: 38, east: -1);
    expect(() => cache.downloadArea(big, 10, 14), throwsArgumentError);
  });

  test('download writes tiles and cache hit returns file', () async {
    final dir = Directory.systemTemp.createTempSync('tiles');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = TileCache(dir,
        client: MockClient((r) async {
          expect(r.headers['User-Agent'], isNotEmpty);
          return http.Response('png', 200);
        }));
    const tiny = GeoBounds(south: 0.01, west: 0.01, north: 0.011, east: 0.011);
    final n = await cache.downloadArea(tiny, 12, 12);
    expect(n, 1);
    expect(cache.fileFor(12, 2048, 2047).existsSync(), isTrue);
  });
}
