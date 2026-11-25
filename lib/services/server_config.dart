import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dirección del servidor de LocalBus.
///
/// Se puede cambiar desde la app (manteniendo presionado el título de
/// cualquier pantalla) y se guarda en el celular.
class ServerConfig {
  ServerConfig._();

  /// Dirección usada mientras nadie haya guardado otra.
  static const String porDefecto = 'http://192.168.1.13:8000';

  static const String _clave = 'servidor_url';

  static String _actual = porDefecto;

  /// Dirección vigente, sin barra final. Ejemplo: http://192.168.1.13:8000
  static String get url => _actual;

  /// Aumenta cada vez que cambia la dirección. Las pantallas lo escuchan
  /// para volver a pedir sus datos.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  /// Lee la dirección guardada. Llamar una vez antes de `runApp`.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = prefs.getString(_clave);
      if (guardada != null && normalizar(guardada) != null) {
        _actual = guardada;
      }
    } catch (e) {
      debugPrint('No se pudo leer el servidor guardado: $e');
    }
  }

  /// Convierte lo que escribió la persona en una dirección completa.
  /// Acepta `192.168.1.13`, `192.168.1.13:8000` o `http://192.168.1.13:8000`.
  /// Si no trae puerto, usa el 8000. Devuelve null si no es una dirección válida.
  static String? normalizar(String entrada) {
    var t = entrada.trim();
    if (t.isEmpty || t.contains(' ')) return null;

    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      t = 'http://$t';
    }
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }

    final uri = Uri.tryParse(t);
    if (uri == null || uri.host.isEmpty || uri.path.isNotEmpty) return null;

    if (!uri.hasPort && uri.scheme == 'http') {
      t = '$t:8000';
    }
    return t;
  }

  /// Guarda una dirección ya normalizada y avisa a las pantallas.
  static Future<void> guardar(String urlNormalizada) async {
    _actual = urlNormalizada;
    cambios.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, urlNormalizada);
    } catch (e) {
      debugPrint('No se pudo guardar el servidor: $e');
    }
  }

  /// Vuelve a la dirección por defecto.
  static Future<void> restablecer() async {
    _actual = porDefecto;
    cambios.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (e) {
      debugPrint('No se pudo restablecer el servidor: $e');
    }
  }
}
