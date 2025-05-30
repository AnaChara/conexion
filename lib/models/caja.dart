// Archivo: models/caja.dart
class Caja {
  final int?    id;
  final int?    createe;
  final String  qr;
  final String  folio;
  final int     sync;
  final String  fechaEscaneo;

  Caja({
    this.id,
    this.createe,
    required this.qr,
    required this.folio,
    this.sync = 0,
    this.fechaEscaneo = '',
  });

  /// Mapea tanto filas SQLite como datos mixtos
  factory Caja.fromMap(Map<String, dynamic> m) {
    // id
    final rawId = m['id'];
    final id = rawId == null
        ? null
        : rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId.toString());
    // createe
    final rawCreate = m['createe'];
    final createe = rawCreate == null
        ? null
        : rawCreate is num
        ? rawCreate.toInt()
        : int.tryParse(rawCreate.toString());
    // sync
    final rawSync = m['sync'];
    final sync = rawSync == null
        ? 0
        : rawSync is num
        ? rawSync.toInt()
        : int.tryParse(rawSync.toString()) ?? 0;
    // qr
    final qr = m['qr']?.toString() ?? '';
    // folio
    final folio = m['folio']?.toString() ?? '';
    // fechaEscaneo
    final fechaEscaneo = m['fechaEscaneo']?.toString() ?? '';

    return Caja(
      id: id,
      createe: createe,
      qr: qr,
      folio: folio,
      sync: sync,
      fechaEscaneo: fechaEscaneo,
    );
  }

  /// Para tu JSON remoto (sólo qr e id_folioSalidaGranja)
  factory Caja.fromJson(Map<String, dynamic> j) => Caja(
    qr: j['qr'] as String,
    folio: j['id_folioSalidaGranja'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'createe': createe,
    'qr': qr,
    'folio': folio,
    'sync': sync,
    'fechaEscaneo': fechaEscaneo,
  };
}
