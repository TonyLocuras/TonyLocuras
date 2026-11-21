/// Definiciones de la batería de tests. Protocolos resumidos; el protocolo
/// definitivo saldrá del plan importado y del estudio (PROVISIONAL).
class TestDef {
  final String id;
  final String name;
  final String unit;
  final bool hands; // un valor por mano
  final bool tindeq; // se puede medir con el Tindeq
  final bool higherBetter;
  final String protocol;
  const TestDef(this.id, this.name, this.unit, this.hands, this.tindeq, this.protocol, {this.higherBetter = true});
}

const kTests = <TestDef>[
  TestDef('peak_half', 'Pico semiarqueo 20 mm', 'kg', true, true,
      'Calienta con series submáximas (~50-70-85 %). Alterna manos con 2-3 min de descanso. Mejor de 2-3 intentos.'),
  TestDef('peak_open', 'Pico extendido 20 mm', 'kg', true, true,
      'Mano abierta. Mismo protocolo que el pico en semiarqueo.'),
  TestDef('peak_full', 'Pico arqueo 20 mm', 'kg', true, true,
      'Arqueo completo. Cuidado con las poleas: progresa en el calentamiento. Mejor de 2-3 intentos.'),
  TestDef('pinza', 'Pico pinza', 'kg', true, true, 'Con el bloque de agarres. Anota el grosor usado en las notas.'),
  TestDef('romo', 'Pico romo', 'kg', true, true, 'Con el bloque de agarres. Anota el canto usado en las notas.'),
  TestDef('rfd', 'RFD (200 ms)', 'kg/s', true, true,
      'Contracción lo más rápida posible desde relajado. La app lo calcula de la curva.'),
  TestDef('hang10', 'Suspensión 10 s con lastre en 18 mm', 'kg', false, false,
      'Lastre máximo que aguantas 10 s en regleta de 18 mm. Anota peso total o lastre.'),
  TestDef('edge_min', 'Regleta mínima', 'mm', false, false, 'Canto más pequeño que aguantas 10 s.', higherBetter: false),
  TestDef('campus', 'Campus alcance máximo', 'cm', false, false, 'Alcance máximo desde suspensión en el campus board.'),
  TestDef('pullup', 'Dominada 1RM (lastre)', 'kg', false, false, 'Directa con lastre real. Anota el lastre; el peso corporal lo suma la app.'),
  TestDef('lock1', 'Bloqueo a una mano', 'kg', true, false, 'Directo con lastre real. Anota ángulo en las notas.'),
  TestDef('cf', 'Fuerza crítica (CF)', 'kg', true, true,
      'All-out 24 repeticiones 7:3 en 20 mm. Definición exacta de CF por fijar (provisional).'),
  TestDef('circuit', 'Circuito de bloques', 'tops', false, false, 'Anota tops, tiempo y caída de fuerza (pico antes/después) en las notas.'),
  TestDef('core', 'Core', 'pts 1-5', false, false, 'Puntuación de calidad de movimiento 1-5.'),
  TestDef('push', 'Empuje', 'pts 1-5', false, false, 'Puntuación de calidad de movimiento 1-5.'),
  TestDef('heel', 'Talonaje', 'pts 1-5', false, false, 'Puntuación de calidad de movimiento 1-5.'),
  TestDef('mobility', 'Movilidad', 'cm', false, false, 'Valor en cm o grados; indica la prueba en las notas.'),
  TestDef('peso', 'Peso corporal', 'kg', false, false, 'En ayunas, misma báscula.', higherBetter: false),
];

TestDef? testById(String id) {
  for (final t in kTests) {
    if (t.id == id) return t;
  }
  return null;
}
