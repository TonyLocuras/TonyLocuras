import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../config.dart';
import '../theme.dart';

const consentText = '''
Qué datos se guardan
Tus datos de entrenamiento (sesiones, tests, cargas), de bienestar y dolor, y los que tú añadas (peso, composición corporal, analíticas, documentos). Son datos de salud: se tratan con especial cuidado.

Quién los ve
• Tú, siempre.
• Tu entrenador, solo si te vinculas a él con un código de invitación. Puede ver tus entrenos, tests, bienestar y documentos, y te envía planes y mensajes.
• Nadie más.

Tus derechos
• Puedes desvincularte de tu entrenador cuando quieras.
• Puedes exportar tus datos.
• Puedes borrar todos tus datos de la nube y del dispositivo desde Ajustes.

La IA
Si tu entrenador analiza un documento tuyo con IA, el documento se envía a un proveedor de IA solo para ese análisis.

Menores de edad
Si eres menor de 18 años, un tutor legal debe dar su consentimiento.
''';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AuthController>().login(email.text, pass.text);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'No se pudo conectar. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('TONYLOCURAS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.accent)),
                Text(Config.isClientApp ? 'Entreno · Clientes' : 'Entreno · Atleta y entrenador',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 36),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Correo')),
                const SizedBox(height: 12),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña'), onSubmitted: (_) => _login()),
                if (error != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700))),
                const SizedBox(height: 20),
                FilledButton(onPressed: busy ? null : _login, child: Text(busy ? 'ENTRANDO...' : 'ENTRAR')),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('CREAR CUENTA'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final guardian = TextEditingController();
  String role = Config.isClientApp ? 'client' : 'athlete';
  DateTime? birth;
  bool consent = false;
  bool guardianOk = false;
  bool busy = false;
  String? error;

  int? get age {
    if (birth == null) return null;
    final n = DateTime.now();
    var a = n.year - birth!.year;
    if (n.month < birth!.month || (n.month == birth!.month && n.day < birth!.day)) a--;
    return a;
  }

  bool get minor => (age ?? 99) < Config.guardianUnderAge;

  Future<void> _go() async {
    String? err;
    if (name.text.trim().isEmpty) err = 'Escribe tu nombre';
    else if (!email.text.contains('@')) err = 'Correo no válido';
    else if (pass.text.length < 6) err = 'La contraseña debe tener al menos 6 caracteres';
    else if (role == 'client' && birth == null) err = 'Indica tu fecha de nacimiento';
    else if (age != null && age! < Config.minimumAge) err = 'Edad mínima: ${Config.minimumAge} años';
    else if (role == 'client' && minor && (guardian.text.trim().isEmpty || !guardianOk)) err = 'Un tutor legal debe dar su consentimiento (nombre y casilla)';
    else if (!consent) err = 'Debes aceptar el tratamiento de datos';
    if (err != null) {
      setState(() => error = err);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AuthController>().register(
            email: email.text,
            password: pass.text,
            role: role,
            name: name.text,
            birth: birth,
            guardianName: guardian.text,
            guardianConsent: guardianOk,
          );
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'No se pudo conectar. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!Config.isClientApp) ...[
          const Text('Tipo de cuenta', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'athlete', label: Text('Atleta'), icon: Icon(Icons.fitness_center)),
              ButtonSegment(value: 'coach', label: Text('Entrenador'), icon: Icon(Icons.groups)),
            ],
            selected: {role},
            onSelectionChanged: (s) => setState(() => role = s.first),
          ),
          const SizedBox(height: 4),
          Text(role == 'athlete' ? 'Tus datos de entrenamiento personales.' : 'Gestión de clientes y clases. Cuenta separada de la de atleta.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
        ],
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Correo')),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña (mín. 6 caracteres)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: birth ?? DateTime(2005, 1, 1),
              firstDate: DateTime(1930),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => birth = d);
          },
          icon: const Icon(Icons.cake),
          label: Text(birth == null ? 'Fecha de nacimiento${role == 'client' ? '' : ' (opcional)'}' : DateFormat('d MMM y', 'es').format(birth!)),
        ),
        if (role == 'client' && birth != null && minor) ...[
          const SizedBox(height: 12),
          Card(
            color: AppColors.surface2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Eres menor de edad: necesitamos el consentimiento de tu tutor legal.', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: guardian, decoration: const InputDecoration(labelText: 'Nombre del tutor legal')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: guardianOk,
                  onChanged: (v) => setState(() => guardianOk = v ?? false),
                  title: const Text('Mi tutor legal ha leído y acepta el tratamiento de datos de abajo'),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('Tratamiento de datos (léelo)', style: TextStyle(fontWeight: FontWeight.w800)),
          children: const [Padding(padding: EdgeInsets.all(12), child: Text(consentText, style: TextStyle(color: AppColors.muted)))],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: (v) => setState(() => consent = v ?? false),
          title: const Text('Acepto el tratamiento de mis datos'),
        ),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(error!, style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'CREANDO...' : 'CREAR CUENTA')),
      ]),
    );
  }
}

/// Pantalla para que un cliente canjee un código de invitación.
class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});
  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final code = TextEditingController();
  bool busy = false;
  String? msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular con mi entrenador')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Escribe el código de 6 caracteres que te dio tu entrenador.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: const InputDecoration(counterText: ''),
        ),
        if (msg != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(msg!, style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    msg = null;
                  });
                  try {
                    final r = await context.read<AuthController>().redeemInvite(code.text);
                    if (!mounted) return;
                    Navigator.pop(context, r);
                  } on ApiException catch (e) {
                    setState(() => msg = e.message);
                  } catch (_) {
                    setState(() => msg = 'No se pudo conectar. Necesitas internet para vincularte.');
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('VINCULAR'),
        ),
      ]),
    );
  }
}
