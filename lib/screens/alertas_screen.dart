import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../services/api_service.dart';
import '../tema.dart';
import '../utils/estados.dart';
import '../utils/formato.dart';
import '../widgets/comunes.dart';

class AlertasScreen extends StatefulWidget {
  /// Abre el mapa con la ruta de la alerta elegida.
  final ValueChanged<int> onVerEnMapa;

  const AlertasScreen({super.key, required this.onVerEnMapa});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  final ApiService _apiService = ApiService();
  List<Alerta> _alertas = [];
  bool _cargando = true;
  String? _error;

  String? _empresa;
  int? _rutaId;

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    setState(() {
      _cargando = _alertas.isEmpty;
      _error = null;
    });

    try {
      final alertas = await _apiService.obtenerAlertas();
      if (mounted) {
        setState(() {
          _alertas = alertas;
          _cargando = false;
          // Si lo elegido ya no tiene alertas, se quita el filtro
          if (_empresa != null && !alertas.any((a) => a.empresa == _empresa)) _empresa = null;
          if (_rutaId != null && !alertas.any((a) => a.rutaId == _rutaId)) _rutaId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraSuperior(context, 'Alertas', acciones: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
          onPressed: _cargarAlertas,
        ),
      ]),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const EstadoCargando('Cargando alertas…');

    if (_error != null && _alertas.isEmpty) {
      return EstadoError(
        titulo: 'No se pudieron cargar las alertas',
        mensaje: _error!,
        onReintentar: _cargarAlertas,
      );
    }

    if (_alertas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarAlertas,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            EstadoVacio('No hay alertas publicadas. Cuando una empresa publique una, aparecerá aquí.'),
          ],
        ),
      );
    }

    final filtradas = _alertas
        .where((a) => _empresa == null || a.empresa == _empresa)
        .where((a) => _rutaId == null || a.rutaId == _rutaId)
        .toList();

    // Primero las que siguen en proceso; dentro de cada grupo, la publicada más reciente arriba
    int porFecha(Alerta a, Alerta b) => b.fechaVisible.compareTo(a.fechaVisible);
    final enProceso = filtradas.where((a) => a.estaVigente).toList()..sort(porFecha);
    final resueltas = filtradas.where((a) => !a.estaVigente).toList()..sort(porFecha);

    return RefreshIndicator(
      onRefresh: _cargarAlertas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_error != null)
            EstadoVacio('No se pudo actualizar: $_error', accion: 'Reintentar', onAccion: _cargarAlertas),
          _filtros(),
          const SizedBox(height: 16),
          EncabezadoSeccion('En proceso', cantidad: enProceso.length),
          if (enProceso.isEmpty)
            const EstadoVacio('Ninguna alerta está en proceso ahora.')
          else
            ...enProceso.map(_ficha),
          if (resueltas.isNotEmpty) ...[
            const SizedBox(height: 8),
            EncabezadoSeccion('Resueltas', cantidad: resueltas.length),
            ...resueltas.map(_ficha),
          ],
        ],
      ),
    );
  }

  Widget _filtros() {
    final empresas = _alertas.map((a) => a.empresa).where((e) => e.isNotEmpty).toSet().toList()..sort();
    // Las rutas que se ofrecen son las de la empresa elegida, sin repetir
    final rutas = <int, String>{};
    for (final a in _alertas) {
      if (_empresa == null || a.empresa == _empresa) {
        rutas[a.rutaId] = a.rutaCodigo.isEmpty ? a.ruta : '${a.rutaCodigo}  ${a.ruta}';
      }
    }
    final rutasOrdenadas = rutas.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      children: [
        if (empresas.length > 1) ...[
          Desplegable<String?>(
            etiqueta: 'Empresa',
            valor: _empresa,
            opciones: {null: 'Todas las empresas', for (final e in empresas) e: e},
            alCambiar: (valor) => setState(() {
              _empresa = valor;
              _rutaId = null;
            }),
          ),
          const SizedBox(height: 12),
        ],
        Desplegable<int?>(
          etiqueta: 'Ruta',
          valor: _rutaId,
          opciones: {null: 'Todas las rutas', for (final r in rutasOrdenadas) r.key: r.value},
          alCambiar: (valor) => setState(() => _rutaId = valor),
        ),
      ],
    );
  }

  Widget _ficha(Alerta alerta) {
    final c = context.colores;
    final tipo = etiquetaTipoAlerta(alerta.tipo);
    final estado = etiquetaEstadoAlerta(alerta);
    final resuelta = alerta.estaResuelta;

    return Ficha(
      // Resueltas: franja gris, ya no piden atención
      franjaIzquierda: resuelta ? c.linea : c.de(tipo.tono),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Insignia(tipo, relleno: !resuelta),
              const SizedBox(width: 8),
              Text(
                estado.texto,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.de(estado.tono)),
              ),
              const Spacer(),
              Text(haceCuanto(alerta.fechaVisible), style: TextStyle(fontSize: 12, color: c.grisTexto)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alerta.descripcion,
            style: TextStyle(fontSize: 16, color: resuelta ? c.grisTexto : c.tinta),
          ),
          if (alerta.estaVigente && alerta.vence != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 15, color: c.grisTexto),
                const SizedBox(width: 4),
                Text(hastaCuando(alerta.vence!), style: TextStyle(fontSize: 13, color: c.grisTexto)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (alerta.rutaCodigo.isNotEmpty) ...[
                PlacaRuta(codigo: alerta.rutaCodigo, rutaId: alerta.rutaId, tamano: 14),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  alerta.ruta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.tinta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reportó: ${alerta.usuario}',
            style: TextStyle(fontSize: 12, color: c.grisTexto),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => widget.onVerEnMapa(alerta.rutaId),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(alerta.tieneUbicacion && alerta.estaVigente ? 'Ver en el mapa' : 'Ver la ruta en el mapa'),
            ),
          ),
        ],
      ),
    );
  }
}
