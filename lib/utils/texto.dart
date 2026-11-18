const _conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
const _sinTilde = 'aeiouunAEIOUUN';

/// Minúsculas y sin tildes, para buscar "berrio" y encontrar "Berrío".
String normalizar(String texto) {
  final buffer = StringBuffer();
  for (final letra in texto.split('')) {
    final i = _conTilde.indexOf(letra);
    buffer.write(i >= 0 ? _sinTilde[i] : letra);
  }
  return buffer.toString().toLowerCase();
}

/// true si `busqueda` aparece en alguno de los textos (sin importar tildes ni mayúsculas).
bool coincide(String busqueda, List<String> textos) {
  final q = normalizar(busqueda.trim());
  if (q.isEmpty) return true;
  return textos.any((t) => normalizar(t).contains(q));
}
