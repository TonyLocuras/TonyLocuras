import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/tile_cache.dart';
import '../state.dart';

/// Serves tiles from the offline cache first, then falls back to the network.
class CachedTileProvider extends NetworkTileProvider {
  final TileCache cache;
  CachedTileProvider(this.cache) : super(headers: {'User-Agent': userAgent});

  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) {
    final f = cache.fileFor(c.z, c.x, c.y);
    return f.existsSync() ? FileImage(f) : super.getImage(c, options);
  }
}

class MapPage extends ConsumerStatefulWidget {
  final Directory cacheDir;
  const MapPage({super.key, required this.cacheDir});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();
  late final TileCache _cache = TileCache(widget.cacheDir);
  String? _status;

  Future<void> _download() async {
    final cam = _map.camera;
    final b = cam.visibleBounds;
    final area = GeoBounds(
        south: b.south, west: b.west, north: b.north, east: b.east);
    final z = cam.zoom.round();
    final n = estimateTiles(area, z, z + 2);
    if (n > maxTilesPerRequest) {
      setState(() => _status = 'Zona demasiado grande ($n teselas). Acerca el mapa.');
      return;
    }
    setState(() => _status = 'Descargando $n teselas…');
    try {
      final w = await _cache.downloadArea(area, z, z + 2);
      setState(() => _status = 'Descargadas $w teselas nuevas.');
    } catch (e) {
      setState(() => _status = 'Error de descarga: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider);
    final pts = [for (final p in route) LatLng(p.lat, p.lon)];
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa experto')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _download,
        icon: const Icon(Icons.download),
        label: const Text('Descargar zona offline'),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: pts.isNotEmpty ? pts.first : const LatLng(36.84, -2.46),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrlTemplate,
              userAgentPackageName: 'com.tonylocuras.expedition_planner',
              tileProvider: CachedTileProvider(_cache),
            ),
            if (pts.length > 1)
              PolylineLayer(polylines: [
                Polyline(points: pts, strokeWidth: 4, color: Colors.redAccent)
              ]),
          ],
        ),
        if (_status != null)
          Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12), child: Text(_status!)))),
      ]),
    );
  }
}
