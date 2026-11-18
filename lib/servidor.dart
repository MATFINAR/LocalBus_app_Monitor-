import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// Arregla lo que escribe la persona: "192.168.1.13:8000" pasa a "http://192.168.1.13:8000".
/// Devuelve null si no es una dirección de servidor válida (solo esquema, host y puerto).
String? normalizarUrl(String texto) {
  var url = texto.trim();
  if (url.isEmpty) return null;
  if (!url.contains('://')) url = 'http://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;
  return url;
}

/// Dirección del servidor de LocalBus que usa la app. Se cambia desde Ajustes y se guarda en el
/// dispositivo, así un cambio de IP no obliga a generar la app otra vez.
/// La primera vez se usa la de compilación (Config.apiUrl, --dart-define=API_URL=...).
class Servidor extends ChangeNotifier {
  Servidor._();

  static final Servidor instancia = Servidor._();
  static const _clave = 'servidor_url';

  String _url = Config.apiUrl;

  String get url => _url;
  bool get esLaInicial => _url == Config.apiUrl;

  /// Lee la dirección guardada. Se llama una vez, antes de abrir la app.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = prefs.getString(_clave);
      final valida = guardada == null ? null : normalizarUrl(guardada);
      if (valida != null) _url = valida;
    } catch (e) {
      // Sin almacenamiento se sigue con la dirección inicial
      debugPrint('No se pudo leer la dirección guardada: $e');
    }
  }

  /// Guarda [url] (ya normalizada) y avisa a las pantallas para que vuelvan a cargar.
  Future<void> cambiar(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, url);
    if (url == _url) return;
    _url = url;
    notifyListeners();
  }

  /// Vuelve a la dirección con que se generó la app.
  Future<void> restablecer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
    if (_url == Config.apiUrl) return;
    _url = Config.apiUrl;
    notifyListeners();
  }
}
