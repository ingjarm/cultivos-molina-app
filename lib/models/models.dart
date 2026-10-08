import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────
enum Variedad { batavia, romana, crespa }

extension VariedadExt on Variedad {
  String get label {
    switch (this) {
      case Variedad.batavia: return 'Batavia';
      case Variedad.romana:  return 'Romana';
      case Variedad.crespa:  return 'Crespa';
    }
  }
  static Variedad fromString(String s) =>
      Variedad.values.firstWhere((v) => v.name == s, orElse: () => Variedad.batavia);
}

enum CausaPerdida { plagas, clima, enfermedades, manipulacion }

extension CausaExt on CausaPerdida {
  String get label {
    switch (this) {
      case CausaPerdida.plagas:        return 'Plagas';
      case CausaPerdida.clima:         return 'Condiciones climáticas';
      case CausaPerdida.enfermedades:  return 'Enfermedades';
      case CausaPerdida.manipulacion:  return 'Manipulación';
    }
  }
  static CausaPerdida fromString(String s) =>
      CausaPerdida.values.firstWhere((c) => c.name == s, orElse: () => CausaPerdida.manipulacion);
}

// ─────────────────────────────────────────────────────────────
// USUARIO
// ─────────────────────────────────────────────────────────────
class UsuarioModel {
  final String uid;
  final String nombre;
  final String email;
  final String rol; // 'admin' | 'operario'
  final bool activo;
  final DateTime creadoEn;

  const UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.activo,
    required this.creadoEn,
  });

  bool get esAdmin => rol == 'admin';

  factory UsuarioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UsuarioModel(
      uid: doc.id,
      nombre: d['nombre'] ?? '',
      email: d['email'] ?? '',
      rol: d['rol'] ?? 'operario',
      activo: d['activo'] ?? true,
      creadoEn: (d['creado_en'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'email': email,
    'rol': rol,
    'activo': activo,
    'creado_en': Timestamp.fromDate(creadoEn),
  };
}

// ─────────────────────────────────────────────────────────────
// LOTE
// ─────────────────────────────────────────────────────────────
class LoteModel {
  final String id;
  final String nombre;
  final double areaM2;
  final bool activo;

  const LoteModel({
    required this.id,
    required this.nombre,
    required this.areaM2,
    required this.activo,
  });

  factory LoteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LoteModel(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      areaM2: (d['area_m2'] ?? 0).toDouble(),
      activo: d['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'area_m2': areaM2,
    'activo': activo,
    'creado_en': Timestamp.now(),
  };
}

// ─────────────────────────────────────────────────────────────
// PRODUCCIÓN
// ─────────────────────────────────────────────────────────────
class ProduccionModel {
  final String id;
  final String loteId;
  final String loteNombre;
  final String usuarioId;
  final Variedad variedad;
  final double cantidadKg;
  final DateTime fecha;
  final String condicionClimatica; // 'soleado' | 'lluvia' | 'nublado'
  final String observaciones;
  final bool sincronizado;
  final DateTime creadoEn;

  const ProduccionModel({
    required this.id,
    required this.loteId,
    this.loteNombre = '',
    required this.usuarioId,
    required this.variedad,
    required this.cantidadKg,
    required this.fecha,
    this.condicionClimatica = 'soleado',
    this.observaciones = '',
    this.sincronizado = true,
    required this.creadoEn,
  });

  factory ProduccionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProduccionModel(
      id: doc.id,
      loteId: d['lote_id'] ?? '',
      loteNombre: d['lote_nombre'] ?? '',
      usuarioId: d['usuario_id'] ?? '',
      variedad: VariedadExt.fromString(d['variedad'] ?? 'batavia'),
      cantidadKg: (d['cantidad_kg'] ?? 0).toDouble(),
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      condicionClimatica: d['condicion_climatica'] ?? 'soleado',
      observaciones: d['observaciones'] ?? '',
      sincronizado: d['sincronizado'] ?? true,
      creadoEn: (d['creado_en'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'lote_id': loteId,
    'lote_nombre': loteNombre,
    'usuario_id': usuarioId,
    'variedad': variedad.name,
    'cantidad_kg': cantidadKg,
    'fecha': Timestamp.fromDate(fecha),
    'condicion_climatica': condicionClimatica,
    'observaciones': observaciones,
    'sincronizado': sincronizado,
    'creado_en': Timestamp.fromDate(creadoEn),
  };
}

// ─────────────────────────────────────────────────────────────
// PÉRDIDA
// ─────────────────────────────────────────────────────────────
class PerdidaModel {
  final String id;
  final String loteId;
  final String loteNombre;
  final String usuarioId;
  final Variedad variedad;
  final double cantidadKg;
  final CausaPerdida causa;
  final String causaDetalle;
  final DateTime fecha;
  final bool sincronizado;

  const PerdidaModel({
    required this.id,
    required this.loteId,
    this.loteNombre = '',
    required this.usuarioId,
    required this.variedad,
    required this.cantidadKg,
    required this.causa,
    this.causaDetalle = '',
    required this.fecha,
    this.sincronizado = true,
  });

  factory PerdidaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PerdidaModel(
      id: doc.id,
      loteId: d['lote_id'] ?? '',
      loteNombre: d['lote_nombre'] ?? '',
      usuarioId: d['usuario_id'] ?? '',
      variedad: VariedadExt.fromString(d['variedad'] ?? 'batavia'),
      cantidadKg: (d['cantidad_kg'] ?? 0).toDouble(),
      causa: CausaExt.fromString(d['causa'] ?? 'manipulacion'),
      causaDetalle: d['causa_detalle'] ?? '',
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sincronizado: d['sincronizado'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'lote_id': loteId,
    'lote_nombre': loteNombre,
    'usuario_id': usuarioId,
    'variedad': variedad.name,
    'cantidad_kg': cantidadKg,
    'causa': causa.name,
    'causa_detalle': causaDetalle,
    'fecha': Timestamp.fromDate(fecha),
    'sincronizado': sincronizado,
    'creado_en': Timestamp.now(),
  };
}

// ─────────────────────────────────────────────────────────────
// VENTA
// ─────────────────────────────────────────────────────────────
class VentaModel {
  final String id;
  final String usuarioId;
  final Variedad variedad;
  final String cliente;
  final double cantidadKg;
  final double precioKg;
  final double total;
  final DateTime fecha;
  final bool sincronizado;

  const VentaModel({
    required this.id,
    required this.usuarioId,
    required this.variedad,
    required this.cliente,
    required this.cantidadKg,
    required this.precioKg,
    required this.total,
    required this.fecha,
    this.sincronizado = true,
  });

  factory VentaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VentaModel(
      id: doc.id,
      usuarioId: d['usuario_id'] ?? '',
      variedad: VariedadExt.fromString(d['variedad'] ?? 'batavia'),
      cliente: d['cliente'] ?? '',
      cantidadKg: (d['cantidad_kg'] ?? 0).toDouble(),
      precioKg: (d['precio_kg'] ?? 0).toDouble(),
      total: (d['total'] ?? 0).toDouble(),
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sincronizado: d['sincronizado'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'variedad': variedad.name,
    'cliente': cliente,
    'cantidad_kg': cantidadKg,
    'precio_kg': precioKg,
    'total': cantidadKg * precioKg,
    'fecha': Timestamp.fromDate(fecha),
    'sincronizado': sincronizado,
    'creado_en': Timestamp.now(),
  };
}
