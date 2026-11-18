import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../services/api_service.dart';
import '../utils/estados.dart';
import '../utils/formato.dart';

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
      _cargando = true;
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
      appBar: AppBar(
        title: const Text('⚠️ Alertas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarAlertas,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error al cargar alertas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargarAlertas,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_alertas.isEmpty) {
      return const Center(child: Text('No hay alertas publicadas'));
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
        padding: const EdgeInsets.all(12),
        children: [
          _filtros(),
          const SizedBox(height: 12),
          _encabezado('En proceso', enProceso.length),
          if (enProceso.isEmpty)
            _vacio('Ninguna alerta está en proceso ahora.')
          else
            ...enProceso.map(_buildAlertaCard),
          if (resueltas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _encabezado('Resueltas', resueltas.length),
            ...resueltas.map(_buildAlertaCard),
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
        rutas[a.rutaId] = a.rutaCodigo.isEmpty ? a.ruta : '${a.rutaCodigo} ${a.ruta}';
      }
    }
    final rutasOrdenadas = rutas.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      children: [
        if (empresas.length > 1) ...[
          _desplegable<String?>(
            etiqueta: 'Empresa',
            valor: _empresa,
            opciones: {null: 'Todas las empresas', for (final e in empresas) e: e},
            alCambiar: (valor) => setState(() {
              _empresa = valor;
              _rutaId = null;
            }),
          ),
          const SizedBox(height: 8),
        ],
        _desplegable<int?>(
          etiqueta: 'Ruta',
          valor: _rutaId,
          opciones: {null: 'Todas las rutas', for (final r in rutasOrdenadas) r.key: r.value},
          alCambiar: (valor) => setState(() => _rutaId = valor),
        ),
      ],
    );
  }

  Widget _desplegable<T>({
    required String etiqueta,
    required T valor,
    required Map<T, String> opciones,
    required ValueChanged<T?> alCambiar,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          items: opciones.entries
              .map((o) => DropdownMenuItem<T>(
                    value: o.key,
                    child: Text(o.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: alCambiar,
        ),
      ),
    );
  }

  Widget _encabezado(String titulo, int cantidad) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        '$titulo ($cantidad)',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _vacio(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(texto, style: TextStyle(color: Colors.grey.shade700)),
    );
  }

  Widget _buildAlertaCard(Alerta alerta) {
    final tipo = etiquetaTipoAlerta(alerta.tipo);
    final estado = etiquetaEstadoAlerta(alerta);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: tipo.color, width: 5)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _insignia(tipo),
                const SizedBox(width: 6),
                _insignia(estado),
                const Spacer(),
                Text(
                  haceCuanto(alerta.fechaVisible),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alerta.descripcion,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (alerta.estaVigente && alerta.vence != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    hastaCuando(alerta.vence!),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.route, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alerta.ruta,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  alerta.usuario,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.onVerEnMapa(alerta.rutaId),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(alerta.tieneUbicacion && alerta.estaVigente
                    ? 'Ver en el mapa'
                    : 'Ver la ruta en el mapa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insignia(Etiqueta etiqueta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: etiqueta.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(etiqueta.icono, size: 14, color: etiqueta.color),
          const SizedBox(width: 4),
          Text(
            etiqueta.texto,
            style: TextStyle(
              color: etiqueta.color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
