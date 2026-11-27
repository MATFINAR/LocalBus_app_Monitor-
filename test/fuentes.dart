import 'dart:io';

import 'package:flutter/services.dart';

/// Carga las tipografías reales de la app. La de relleno de las pruebas es mucho más ancha y daría desbordes
/// que en el celular no existen.
Future<void> cargarFuentes() async {
  for (final (familia, archivos) in [
    ('Barlow Condensed', ['BarlowCondensed-Medium', 'BarlowCondensed-SemiBold', 'BarlowCondensed-Bold']),
    ('Atkinson Hyperlegible', ['AtkinsonHyperlegible-Regular', 'AtkinsonHyperlegible-Bold']),
  ]) {
    final cargador = FontLoader(familia);
    for (final a in archivos) {
      cargador.addFont(Future.value(ByteData.view(File('assets/fonts/$a.ttf').readAsBytesSync().buffer)));
    }
    await cargador.load();
  }
}
