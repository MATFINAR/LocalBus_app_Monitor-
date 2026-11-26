import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/caja_con_franja.dart';

/// Nivel de un mensaje: el color de la franja izquierda, como .base-message-* de la web.
enum Nivel { success, error, warning, info }

Nivel nivelDesdeTexto(String? texto) => switch (texto) {
      'error' => Nivel.error,
      'warning' => Nivel.warning,
      'info' => Nivel.info,
      _ => Nivel.success,
    };

class Mensaje {
  Mensaje(this.texto, this.nivel, {this.titulo, this.alTocar}) : id = _siguiente++;
  static int _siguiente = 0;

  final int id;
  final String texto;
  final String? titulo;
  final Nivel nivel;
  final VoidCallback? alTocar;
}

/// Mensajes que aparecen arriba (resultado de una acción, como los mensajes de Django en la web) y avisos de
/// alertas nuevas abajo (como notificaciones.js).
class Mensajes {
  Mensajes._();

  static final ValueNotifier<List<Mensaje>> arriba = ValueNotifier([]);
  static final ValueNotifier<List<Mensaje>> abajo = ValueNotifier([]);

  static void mostrar(String texto, {Nivel nivel = Nivel.success}) {
    final m = Mensaje(texto, nivel);
    arriba.value = [...arriba.value, m].reversed.take(3).toList().reversed.toList();
    Timer(Duration(seconds: nivel == Nivel.error ? 9 : 6), () => cerrar(m));
  }

  static void alerta(String titulo, String texto, VoidCallback alTocar) {
    final m = Mensaje(texto, Nivel.warning, titulo: titulo, alTocar: alTocar);
    abajo.value = [...abajo.value, m].reversed.take(3).toList().reversed.toList();
    Timer(const Duration(seconds: 10), () => cerrar(m));
  }

  static void cerrar(Mensaje m) {
    arriba.value = arriba.value.where((x) => x.id != m.id).toList();
    abajo.value = abajo.value.where((x) => x.id != m.id).toList();
  }
}

/// Pone los mensajes sobre toda la app. Va en MaterialApp.builder.
class MensajesHost extends StatelessWidget {
  const MensajesHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final relleno = MediaQuery.of(context).padding;
    return Stack(
      children: [
        child,
        Positioned(
          top: relleno.top + 12,
          left: 12,
          right: 12,
          child: _Lista(Mensajes.arriba),
        ),
        Positioned(
          bottom: relleno.bottom + 84,
          left: 16,
          right: 16,
          child: _Lista(Mensajes.abajo),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista(this.fuente);

  final ValueNotifier<List<Mensaje>> fuente;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Mensaje>>(
      valueListenable: fuente,
      builder: (context, lista, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in lista)
            Padding(
              key: ValueKey(m.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: _MensajeCaja(m),
            ),
        ],
      ),
    );
  }
}

class _MensajeCaja extends StatefulWidget {
  const _MensajeCaja(this.mensaje);

  final Mensaje mensaje;

  @override
  State<_MensajeCaja> createState() => _MensajeCajaState();
}

class _MensajeCajaState extends State<_MensajeCaja> with SingleTickerProviderStateMixin {
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final m = widget.mensaje;
    final franja = switch (m.nivel) {
      Nivel.success => lb.verde,
      Nivel.error => lb.rojoInterfaz,
      Nivel.warning => lb.amarillo,
      Nivel.info => lb.azul,
    };
    final curva = CurvedAnimation(parent: _entrada, curve: const Cubic(0.22, 0.61, 0.36, 1));

    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(curva),
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: lb.blanco,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio)),
            child: InkWell(
              onTap: m.alTocar == null
                  ? null
                  : () {
                      Mensajes.cerrar(m);
                      m.alTocar!();
                    },
              child: CajaConFranja(
                radio: AppTheme.radio,
                sombra: const [BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, 2))],
                borde: Border(
                    left: BorderSide(color: franja, width: 5),
                    top: BorderSide(color: lb.linea),
                    right: BorderSide(color: lb.linea),
                    bottom: BorderSide(color: lb.linea),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.titulo != null)
                            Text(m.titulo!, style: AppTheme.titulo(size: 17, color: lb.tinta, height: 1.2)),
                          Text(
                            m.texto,
                            style: TextStyle(
                              fontSize: m.titulo != null ? 14.5 : 15,
                              height: 1.4,
                              color: m.titulo != null ? lb.grisTexto : lb.tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Mensajes.cerrar(m),
                      // Sin tooltip: los mensajes van por encima del navegador y allí no hay Overlay que lo muestre
                      style: IconButton.styleFrom(foregroundColor: lb.grisTexto, minimumSize: const Size(36, 36)),
                      icon: const Text('×', semanticsLabel: 'Cerrar', style: TextStyle(fontSize: 22, height: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
