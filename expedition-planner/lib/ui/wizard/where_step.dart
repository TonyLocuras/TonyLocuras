import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../state.dart';

class WhereStep extends ConsumerStatefulWidget {
  const WhereStep({super.key});
  @override
  ConsumerState<WhereStep> createState() => _WhereStepState();
}

class _WhereStepState extends ConsumerState<WhereStep> {
  String? _msg;

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _msg = 'Permiso de ubicación denegado.');
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      setState(() => _msg =
          'Ubicación: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}');
    } catch (e) {
      setState(() => _msg = 'No se pudo obtener la ubicación.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _locate,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación'),
          ),
          if (_msg != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_msg!)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(stepProvider.notifier).go(1),
            child: const Text('Continuar'),
          ),
        ],
      );
}
