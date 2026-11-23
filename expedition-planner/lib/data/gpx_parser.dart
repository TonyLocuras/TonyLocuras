import 'package:xml/xml.dart';
import '../domain/geo.dart';

List<LatLngEle> parseGpx(String source) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(source);
  } on XmlException catch (e) {
    throw FormatException('GPX inválido: ${e.message}');
  }
  var nodes = doc.findAllElements('trkpt').toList();
  if (nodes.isEmpty) nodes = doc.findAllElements('rtept').toList();
  if (nodes.isEmpty) throw const FormatException('GPX sin puntos');
  return nodes.map((n) {
    final lat = double.tryParse(n.getAttribute('lat') ?? '');
    final lon = double.tryParse(n.getAttribute('lon') ?? '');
    if (lat == null || lon == null) {
      throw const FormatException('GPX con coordenadas inválidas');
    }
    final ele = double.tryParse(n.getElement('ele')?.innerText ?? '') ?? 0;
    return LatLngEle(lat, lon, ele);
  }).toList();
}
