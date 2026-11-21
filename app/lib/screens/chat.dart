import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Hilo de mensajes entre entrenador y cliente. [load] devuelve los mensajes
/// (cada uno con 'from' = coach|client, 'text', 'at'); [send] envía uno nuevo.
class ChatView extends StatefulWidget {
  final String me; // 'coach' o 'client'
  final Future<List<Map<String, dynamic>>> Function() load;
  final Future<void> Function(String text) send;
  const ChatView({super.key, required this.me, required this.load, required this.send});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  List<Map<String, dynamic>> msgs = [];
  final ctl = TextEditingController();
  Timer? _t;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _t?.cancel();
    ctl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final l = await widget.load();
      l.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
      if (mounted) {
        setState(() {
          msgs = l;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Sin conexión: los mensajes nuevos llegarán al volver.';
        });
      }
    }
  }

  Future<void> _send() async {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    ctl.clear();
    try {
      await widget.send(t);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ctl.text = t;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: AppColors.amber, fontSize: 12))),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : msgs.isEmpty
                ? const Center(child: Text('Sin mensajes todavía', style: TextStyle(color: AppColors.muted)))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[msgs.length - 1 - i];
                      final mine = m['from'] == widget.me;
                      final at = DateTime.tryParse('${m['at']}')?.toLocal();
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.accent.withValues(alpha: 0.9) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${m['text']}', style: const TextStyle(fontSize: 16)),
                            if (at != null) Text(DateFormat('d MMM HH:mm', 'es').format(at), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            Expanded(child: TextField(controller: ctl, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Escribe un mensaje'))),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(56, 56)),
              onPressed: _send,
              icon: const Icon(Icons.send),
            ),
          ]),
        ),
      ),
    ]);
  }
}
