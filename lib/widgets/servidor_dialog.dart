import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/server_config.dart';
import '../theme/app_theme.dart';

/// Ventana para cambiar la dirección del servidor. Se abre manteniendo presionada la dirección 15 s al final de
/// «Acerca de».
Future<void> mostrarDialogoServidor(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ServidorDialog(),
  );
}

class _ServidorDialog extends StatefulWidget {
  const _ServidorDialog();

  @override
  State<_ServidorDialog> createState() => _ServidorDialogState();
}

class _ServidorDialogState extends State<_ServidorDialog> {
  late final TextEditingController _controller;
  final FocusNode _foco = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Se muestra sin "http://" para que sea corto de leer y de escribir.
    _controller = TextEditingController(
      text: ServerConfig.url.replaceFirst('http://', ''),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final url = ServerConfig.normalizar(_controller.text);
    if (url == null) {
      setState(() {
        _error =
            'Escribe la dirección del servidor, por ejemplo 192.168.1.13:8000.';
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ServerConfig.guardar(url);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Servidor actualizado: $url')),
    );
  }

  Future<void> _restablecer() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ServerConfig.restablecer();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Se restableció la dirección original.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: lb.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radioVentana),
        side: BorderSide(color: lb.linea),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Text('Servidor', style: theme.textTheme.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dirección del servidor',
              style: TextStyle(
                color: lb.tinta,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              focusNode: _foco,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _guardar(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              // Mínimo 16 px para que el celular no amplíe la pantalla al escribir.
              style: TextStyle(color: lb.tinta, fontSize: 17),
              cursorColor: lb.azul,
              decoration: InputDecoration(
                isDense: true,
                hintText: '192.168.1.13:8000',
                hintStyle: TextStyle(color: lb.grisTexto),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                // Campo de texto con solo una línea inferior de 2 px.
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: lb.tinta, width: 2),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _error != null ? lb.rojoInterfaz : lb.tinta,
                    width: 2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _error != null ? lb.rojoInterfaz : lb.azul,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: lb.rojoInterfaz, fontSize: 13.5),
              )
            else
              Text(
                'Un dominio de internet o la IP de tu computador en la red Wi‑Fi (puerto 8000 si no escribes otro).',
                style: TextStyle(color: lb.grisTexto, fontSize: 13.5),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _restablecer,
          style: TextButton.styleFrom(foregroundColor: lb.grisTexto),
          child: const Text('Restablecer'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
