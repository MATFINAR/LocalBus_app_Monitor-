/// Minúsculas y sin tildes, para buscar sin que importen («itagui» encuentra «Itagüí»).
String textoSimple(String texto) {
  const con = 'áéíóúüñ', sin = 'aeiouun';
  var r = texto.toLowerCase();
  for (var i = 0; i < con.length; i++) {
    r = r.replaceAll(con[i], sin[i]);
  }
  return r;
}

/// La búsqueda coincide si todas sus palabras están en alguno de los campos.
bool coincideBusqueda(String busqueda, Iterable<String> campos) {
  final palabras = textoSimple(busqueda).split(' ').where((p) => p.isNotEmpty);
  if (palabras.isEmpty) return true;
  final texto = textoSimple(campos.join(' '));
  return palabras.every(texto.contains);
}
