import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/hoy.dart';
import 'screens/mas.dart';
import 'screens/nutricion.dart';
import 'screens/plan.dart';
import 'screens/progreso.dart';
import 'store.dart';
import 'theme.dart';
import 'tindeq.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final store = Store();
  await store.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => TindeqService()),
    ],
    child: const TonyApp(),
  ));
}

class TonyApp extends StatelessWidget {
  const TonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = (context.watch<Store>().settings['textScale'] as num?)?.toDouble() ?? 1.0;
    return MaterialApp(
      title: 'TonyLocuras Entreno',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scale),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  static const pages = <Widget>[HoyScreen(), PlanScreen(), ProgresoScreen(), NutricionScreen(), MasScreen()];
  static const items = [
    (Icons.local_fire_department, 'Hoy'),
    (Icons.calendar_month, 'Plan'),
    (Icons.show_chart, 'Progreso'),
    (Icons.restaurant, 'Nutrición'),
    (Icons.more_horiz, 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    final body = IndexedStack(index: i, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: i,
            onDestinationSelected: (x) => setState(() => i = x),
            labelType: NavigationRailLabelType.all,
            indicatorColor: AppColors.accent.withValues(alpha: 0.25),
            destinations: [for (final e in items) NavigationRailDestination(icon: Icon(e.$1), label: Text(e.$2))],
          ),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (x) => setState(() => i = x),
        destinations: [for (final e in items) NavigationDestination(icon: Icon(e.$1), label: e.$2)],
      ),
    );
  }
}
