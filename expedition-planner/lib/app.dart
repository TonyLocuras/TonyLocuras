import 'package:flutter/material.dart';

class ExpeditionApp extends StatelessWidget {
  const ExpeditionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Expedition Planner',
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: Center(child: Text('Prepara tu ruta'))),
      );
}
