import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Max tiles per download request (OpenTopoMap usage policy: no bulk scraping).
const maxTilesPerRequest = 2000;
const tileUrlTemplate = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
const userAgent = 'TonyLocurasExpeditionPlanner/0.1 (personal route planning)';

class GeoBounds {
  final double south, west, north, east;
  const GeoBounds(
      {required this.south,
      required this.west,
      required this.north,
      required this.east});
}

int lonToTileX(double lon, int z) => ((lon + 180) / 360 * (1 << z)).floor();

int latToTileY(double lat, int z) {
  final r = lat * pi / 180;
  final merc = log(tan(r) + 1 / cos(r)); // asinh(tan(lat))
  return ((1 - merc / pi) / 2 * (1 << z)).floor();
}

int estimateTiles(GeoBounds b, int minZoom, int maxZoom) {
  var total = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    final cols = lonToTileX(b.east, z) - lonToTileX(b.west, z) + 1;
    final rows = latToTileY(b.south, z) - latToTileY(b.north, z) + 1;
    total += cols * rows;
  }
  return total;
}

class TileCache {
  final Directory root;
  final http.Client _c;
  TileCache(this.root, {http.Client? client}) : _c = client ?? http.Client();

  File fileFor(int z, int x, int y) => File('${root.path}/$z/$x/$y.png');

  /// Downloads missing tiles; returns how many were written.
  Future<int> downloadArea(GeoBounds b, int minZoom, int maxZoom) async {
    final n = estimateTiles(b, minZoom, maxZoom);
    if (n > maxTilesPerRequest) {
      throw ArgumentError(
          'Demasiadas teselas ($n). Máximo $maxTilesPerRequest por descarga.');
    }
    var written = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      for (var x = lonToTileX(b.west, z); x <= lonToTileX(b.east, z); x++) {
        for (var y = latToTileY(b.north, z); y <= latToTileY(b.south, z); y++) {
          final f = fileFor(z, x, y);
          if (f.existsSync()) continue;
          final url = tileUrlTemplate
              .replaceAll('{z}', '$z')
              .replaceAll('{x}', '$x')
              .replaceAll('{y}', '$y');
          final res = await _c.get(Uri.parse(url), headers: {'User-Agent': userAgent});
          if (res.statusCode != 200) continue;
          f.parent.createSync(recursive: true);
          f.writeAsBytesSync(res.bodyBytes);
          written++;
        }
      }
    }
    return written;
  }
}
