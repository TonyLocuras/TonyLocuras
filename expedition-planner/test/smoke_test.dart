import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expedition_planner/app.dart';

void main() {
  testWidgets('shows Prepara tu ruta', (t) async {
    await t.pumpWidget(const ProviderScope(child: ExpeditionApp()));
    expect(find.text('Prepara tu ruta'), findsOneWidget);
  });
}
