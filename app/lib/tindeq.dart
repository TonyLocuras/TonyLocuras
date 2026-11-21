import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'calc.dart';

/// Servicio Bluetooth del Tindeq Progressor.
///
/// IMPORTANTE (sin verificar contra la documentación oficial en este momento):
/// los UUID, los códigos de comando y el formato de datos de abajo están
/// escritos de memoria del API público del Progressor. Se prueba por primera
/// vez con el dispositivo real; si algo no cuadra, solo hay que ajustar estas
/// constantes. Mientras tanto la entrada manual sigue funcionando.
class TindeqService extends ChangeNotifier {
  static final Guid serviceUuid = Guid('7e4e1701-1ea6-40c9-9dcc-13d34ffead57');
  static final Guid dataUuid = Guid('7e4e1702-1ea6-40c9-9dcc-13d34ffead57');
  static final Guid ctrlUuid = Guid('7e4e1703-1ea6-40c9-9dcc-13d34ffead57');

  static const int cmdTare = 0x64;
  static const int cmdStart = 0x65;
  static const int cmdStop = 0x66;
  static const int respWeight = 0x01;

  BluetoothDevice? _dev;
  BluetoothCharacteristic? _ctrl;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  String status = 'Desconectado';
  bool connected = false;
  bool streaming = false;
  String? deviceName;

  /// Umbral (kg) para detectar inicio y fin de una serie.
  double thresholdKg = 1.0;

  double lastKg = 0;
  double peakKg = 0;
  double meanKg = 0;

  /// Todas las muestras de la medición actual (t en s desde el primer dato).
  final List<ForceSample> all = [];

  /// Última serie detectada por umbral (inicio..fin).
  List<ForceSample> segment = [];
  bool inSegment = false;
  int _below = 0;
  double? _t0;

  Future<bool> _perms() async {
    final r = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
    return (r[Permission.bluetoothScan]?.isGranted ?? false) && (r[Permission.bluetoothConnect]?.isGranted ?? false);
  }

  void _set(String s) {
    status = s;
    notifyListeners();
  }

  Future<void> connect() async {
    try {
      if (!await _perms()) {
        _set('Faltan permisos de Bluetooth');
        return;
      }
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _set('Activa el Bluetooth');
        return;
      }
      _set('Buscando Progressor...');
      BluetoothDevice? found;
      final sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final n = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
          if (n.toLowerCase().startsWith('progressor')) {
            found = r.device;
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), androidUsesFineLocation: false);
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (found == null && DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await FlutterBluePlus.stopScan();
      await sub.cancel();
      if (found == null) {
        _set('No encuentro el Progressor. ¿Está encendido y cerca? (¿la app oficial está cerrada?)');
        return;
      }
      _dev = found;
      deviceName = found!.platformName;
      _set('Conectando a $deviceName...');
      await found!.connect(timeout: const Duration(seconds: 15));
      _connSub = found!.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          connected = false;
          streaming = false;
          _set('Conexión perdida');
        }
      });
      final services = await found!.discoverServices();
      BluetoothCharacteristic? data;
      for (final s in services) {
        if (s.uuid == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == dataUuid) data = c;
            if (c.uuid == ctrlUuid) _ctrl = c;
          }
        }
      }
      if (data == null || _ctrl == null) {
        _set('Conectado, pero no encuentro el servicio del Progressor (UUID por verificar)');
        return;
      }
      await data.setNotifyValue(true);
      _dataSub = data.onValueReceived.listen(_onData);
      connected = true;
      _set('Conectado a $deviceName');
    } catch (e) {
      connected = false;
      _set('Error de conexión: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await stop();
      await _dataSub?.cancel();
      await _connSub?.cancel();
      await _dev?.disconnect();
    } catch (_) {}
    connected = false;
    streaming = false;
    _set('Desconectado');
  }

  Future<void> _cmd(int c) async {
    await _ctrl?.write([c], withoutResponse: false);
  }

  Future<void> tare() async {
    if (!connected) return;
    await _cmd(cmdTare);
    _set('Tara hecha');
  }

  void clear() {
    all.clear();
    segment = [];
    inSegment = false;
    _below = 0;
    _t0 = null;
    lastKg = 0;
    peakKg = 0;
    meanKg = 0;
    notifyListeners();
  }

  Future<void> start() async {
    if (!connected) return;
    clear();
    await _cmd(cmdStart);
    streaming = true;
    _set('Midiendo...');
  }

  Future<void> stop() async {
    if (!connected || !streaming) return;
    try {
      await _cmd(cmdStop);
    } catch (_) {}
    streaming = false;
    if (inSegment) _closeSegment();
    _set('Medición parada');
  }

  void _onData(List<int> v) {
    if (v.length < 2) return;
    final code = v[0];
    if (code != respWeight) return;
    final len = v[1];
    final bytes = Uint8List.fromList(v);
    final bd = ByteData.sublistView(bytes);
    var o = 2;
    final end = (2 + len) <= bytes.length ? 2 + len : bytes.length;
    while (o + 8 <= end) {
      final kg = bd.getFloat32(o, Endian.little);
      final us = bd.getUint32(o + 4, Endian.little);
      o += 8;
      final t = us / 1e6;
      _t0 ??= t;
      _feed(ForceSample(t - _t0!, kg));
    }
    notifyListeners();
  }

  void _feed(ForceSample s) {
    all.add(s);
    lastKg = s.kg;
    if (!inSegment) {
      if (s.kg >= thresholdKg) {
        inSegment = true;
        segment = [s];
        _below = 0;
      }
    } else {
      segment.add(s);
      if (s.kg < thresholdKg) {
        _below++;
        if (_below >= 40) _closeSegment(); // ~0,5 s por debajo del umbral
      } else {
        _below = 0;
      }
    }
    if (inSegment || segment.isNotEmpty) {
      peakKg = peakForce(segment);
      meanKg = meanForce(segment);
    }
  }

  void _closeSegment() {
    inSegment = false;
    _below = 0;
    // recorta la cola por debajo del umbral
    while (segment.isNotEmpty && segment.last.kg < thresholdKg) {
      segment.removeLast();
    }
    peakKg = peakForce(segment);
    meanKg = meanForce(segment);
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
