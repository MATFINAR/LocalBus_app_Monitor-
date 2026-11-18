/// Configuración de la app. Se cambia al compilar, sin tocar el código:
///
///   flutter run --dart-define=API_URL=http://192.168.1.50:8000
///
/// La IP debe estar también en DJANGO_ALLOWED_HOSTS del servidor; si no, Django responde 400.
class Config {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.20.59:8000',
  );

  /// Cada cuánto se piden las posiciones de los buses (el backend las da por vencidas a los 5 min).
  static const Duration intervaloBuses = Duration(seconds: 5);

  /// Cada cuánto se vuelve a pedir el estado de las rutas (cambia cuando empieza o termina un turno).
  static const Duration intervaloRutas = Duration(minutes: 1);

  /// Tiempo máximo de espera de cada petición.
  static const Duration tiempoEspera = Duration(seconds: 10);
}
