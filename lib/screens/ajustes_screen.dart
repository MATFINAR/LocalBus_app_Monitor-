import 'package:flutter/material.dart';
import '../config.dart';
import '../servidor.dart';
import '../services/api_service.dart';
import '../tema.dart';
import '../widgets/comunes.dart';

/// Dirección del servidor de LocalBus. Se guarda en el dispositivo: si cambia la IP del computador,
/// se corrige aquí sin generar la app otra vez.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final ApiService _api = ApiService();
  late final TextEditingController _campo = TextEditingController(text: Servidor.instancia.url);

  bool _probando = false;
  String? _error;
  String? _exito;

  /// La última prueba falló al guardar: se ofrece guardar de todos modos.
  String? _urlSinProbar;

  @override
  void initState() {
    super.initState();
    Servidor.instancia.addListener(_alCambiarServidor);
  }

  @override
  void dispose() {
    Servidor.instancia.removeListener(_alCambiarServidor);
    _campo.dispose();
    super.dispose();
  }

  void _alCambiarServidor() {
    if (mounted) setState(() {});
  }

  /// Valida lo escrito; si no sirve, muestra cómo debe ser.
  String? _leerCampo() {
    final url = normalizarUrl(_campo.text);
    if (url == null) {
      setState(() {
        _error = 'Escribe la dirección y el puerto del servidor, por ejemplo http://192.168.1.13:8000';
        _exito = null;
        _urlSinProbar = null;
      });
      return null;
    }
    if (_campo.text != url) _campo.text = url;
    return url;
  }

  Future<void> _probar({required bool guardar}) async {
    final url = _leerCampo();
    if (url == null) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _probando = true;
      _error = null;
      _exito = null;
      _urlSinProbar = null;
    });

    try {
      final rutas = await _api.probarServidor(url);
      if (guardar) await Servidor.instancia.cambiar(url);
      if (!mounted) return;
      final cuantas = rutas == 1 ? '1 ruta' : '$rutas rutas';
      setState(() => _exito = guardar
          ? 'Guardado. La app ya usa este servidor ($cuantas).'
          : 'Conexión correcta: el servidor responde y tiene $cuantas.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _urlSinProbar = guardar ? url : null;
      });
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  Future<void> _guardarSinProbar() async {
    final url = _urlSinProbar;
    if (url == null) return;
    await Servidor.instancia.cambiar(url);
    if (!mounted) return;
    setState(() {
      _urlSinProbar = null;
      _error = null;
      _exito = 'Guardado sin probar. La app lo usará y avisará si no logra conectarse.';
    });
  }

  Future<void> _restablecer() async {
    await Servidor.instancia.restablecer();
    if (!mounted) return;
    _campo.text = Servidor.instancia.url;
    setState(() {
      _error = null;
      _urlSinProbar = null;
      _exito = 'Se volvió a la dirección inicial.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final enUso = Servidor.instancia.url;

    return Scaffold(
      appBar: barraSuperior(context, 'Ajustes'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const EncabezadoSeccion('Servidor'),
          Text(
            'Dirección del computador donde corre Django, con el puerto. '
            'Si cambia la IP, corrígela aquí: no hace falta instalar la app otra vez.',
            style: TextStyle(color: c.grisTexto),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _campo,
            enabled: !_probando,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _probar(guardar: true),
            onChanged: (_) {
              if (_error != null || _exito != null) {
                setState(() {
                  _error = null;
                  _exito = null;
                  _urlSinProbar = null;
                });
              }
            },
            decoration: decoracionCampo(
              context,
              etiqueta: 'Dirección del servidor',
              ayuda: 'http://192.168.1.13:8000',
              prefijo: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Text('En uso ahora: $enUso', style: TextStyle(fontSize: 13, color: c.grisTexto)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _probando ? null : () => _probar(guardar: false),
                  child: const Text('Probar conexión'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _probando ? null : () => _probar(guardar: true),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_probando) const Align(alignment: Alignment.centerLeft, child: EstadoCargando('Probando conexión…')),
          if (_exito != null) _mensaje(Icons.check_circle_outline, _exito!, c.verde),
          if (_error != null) ...[
            _mensaje(Icons.error_outline, _error!, c.rojoInterfaz),
            if (_urlSinProbar != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _guardarSinProbar,
                  child: const Text('Guardar de todos modos'),
                ),
              ),
          ],
          if (!Servidor.instancia.esLaInicial)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _probando ? null : _restablecer,
                child: Text('Volver a la dirección inicial (${Config.apiUrl})'),
              ),
            ),
          const SizedBox(height: 16),
          Divider(color: c.linea),
          const SizedBox(height: 8),
          const EncabezadoSeccion('Si no conecta'),
          _paso('1', 'En el computador, abre una terminal y escribe ipconfig. '
              'Usa la "Dirección IPv4" del adaptador Wi-Fi.'),
          _paso('2', 'Arranca Django escuchando en la red: python manage.py runserver 0.0.0.0:8000'),
          _paso('3', 'Pon esa IP en DJANGO_ALLOWED_HOSTS del archivo .env de Django y reinícialo.'),
          _paso('4', 'El celular y el computador deben estar en la misma red Wi-Fi.'),
        ],
      ),
    );
  }

  Widget _mensaje(IconData icono, String texto, Color color) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  Widget _paso(String numero, String texto) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text(numero, style: estiloTitulo(size: 18, color: c.azul))),
          Expanded(child: Text(texto, style: TextStyle(color: c.tinta))),
        ],
      ),
    );
  }
}
