import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'auth.dart';
import 'coach.dart';
import 'config.dart';
import 'notifs.dart';
import 'screens/ai_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/client_screens.dart';
import 'screens/coach_screens.dart';
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
  final auth = AuthController();
  await auth.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => TindeqService()),
    ],
    child: const TonyApp(),
  ));
}

class TonyApp extends StatelessWidget {
  const TonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final scale = (auth.store?.settings['textScale'] as num?)?.toDouble() ?? 1.0;
    return MaterialApp(
      title: Config.isClientApp ? 'TonyLocuras Clientes' : 'TonyLocuras Entreno',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scale),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Root(),
    );
  }
}

/// Decide qué ver según la sesión: login, o la app de atleta, entrenador o cliente.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final store = auth.store;
    if (store == null) return const AuthGate();
    return MultiProvider(
      key: ValueKey('${auth.uid}-${auth.role}'),
      providers: [
        ChangeNotifierProvider<Store>.value(value: store),
        if (auth.isCoach && auth.sync != null) ChangeNotifierProvider<CoachService>(create: (_) => CoachService(auth.api, store)..refresh()),
      ],
      child: _Boot(
        child: auth.isCoach
            ? const CoachShell()
            : auth.isClient
                ? const ClientShell()
                : const AthleteShell(),
      ),
    );
  }
}

/// Programa los recordatorios al entrar.
class _Boot extends StatefulWidget {
  final Widget child;
  const _Boot({required this.child});
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthController>();
      final st = context.read<Store>();
      await Notifs.instance.rescheduleAll(st, isClient: auth.isClient || auth.isCoach);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ====================================================================== Atleta

class AthleteShell extends StatefulWidget {
  const AthleteShell({super.key});
  @override
  State<AthleteShell> createState() => _AthleteShellState();
}

class _AthleteShellState extends State<AthleteShell> {
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

// ====================================================================== Entrenador

class CoachShell extends StatefulWidget {
  const CoachShell({super.key});
  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int i = 0;
  static const items = [
    (Icons.groups, 'Clientes'),
    (Icons.class_, 'Clases'),
    (Icons.auto_awesome, 'IA'),
    (Icons.more_horiz, 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final hasCloud = auth.sync != null;
    final pages = <Widget>[
      hasCloud ? const ClientsScreen() : const _NeedsCloud(),
      const ClassesScreen(),
      hasCloud ? const AiPlanScreen() : const _NeedsCloud(),
      const CoachMoreScreen(),
    ];
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

class _NeedsCloud extends StatelessWidget {
  const _NeedsCloud();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Esta sección necesita la nube (Supabase). Esta compilación no la tiene configurada.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 16)),
          ),
        ),
      );
}
