import 'dart:math';

class LatLngEle {
  final double lat, lon, ele;
  const LatLngEle(this.lat, this.lon, this.ele);
}

double haversineKm(LatLngEle a, LatLngEle b) {
  const r = 6371.0088;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon);
  final h = pow(sin(dLat / 2), 2) +
      cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(h));
}

class RouteStats {
  final double km, gainM, lossM, maxEle, minEle;
  const RouteStats(this.km, this.gainM, this.lossM, this.maxEle, this.minEle);
}

RouteStats computeStats(List<LatLngEle> pts, {double noiseM = 3}) {
  if (pts.length < 2) return const RouteStats(0, 0, 0, 0, 0);
  double km = 0, gain = 0, loss = 0;
  double maxE = pts.first.ele, minE = pts.first.ele;
  double ref = pts.first.ele;
  for (var i = 1; i < pts.length; i++) {
    km += haversineKm(pts[i - 1], pts[i]);
    final e = pts[i].ele;
    if (e > maxE) maxE = e;
    if (e < minE) minE = e;
    final diff = e - ref;
    if (diff >= noiseM) {
      gain += diff;
      ref = e;
    } else if (diff <= -noiseM) {
      loss += -diff;
      ref = e;
    }
  }
  return RouteStats(km, gain, loss, maxE, minE);
}
