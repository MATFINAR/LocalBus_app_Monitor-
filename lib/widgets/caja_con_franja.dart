import 'package:flutter/material.dart';

/// Caja de esquinas redondeadas cuyos bordes tienen colores distintos (una franja de color a un lado).
///
/// Flutter no pinta un `BoxDecoration` con `borderRadius` y bordes de varios colores: lanza un error y la
/// pantalla queda en blanco. Por eso aquí las esquinas se recortan por fuera del borde.
class CajaConFranja extends StatelessWidget {
  const CajaConFranja({
    super.key,
    required this.borde,
    required this.radio,
    required this.child,
    this.color,
    this.padding,
    this.sombra,
  });

  final Border borde;
  final double radio;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? sombra;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(radio);
    final caja = ClipRRect(
      borderRadius: esquinas,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: color, border: borde),
        child: child,
      ),
    );
    if (sombra == null) return caja;
    return DecoratedBox(decoration: BoxDecoration(borderRadius: esquinas, boxShadow: sombra), child: caja);
  }
}
