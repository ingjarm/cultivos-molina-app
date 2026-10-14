import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── LOTES ────────────────────────────────────────────────
  Stream<List<LoteModel>> getLotesActivos() {
    return _db
        .collection('lotes')
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map(LoteModel.fromFirestore).toList());
  }

  Future<void> crearLote(LoteModel lote) async {
    await _db.collection('lotes').add(lote.toMap());
  }

  // ─── PRODUCCIONES ─────────────────────────────────────────
  Stream<List<ProduccionModel>> getProducciones({DateTime? desde, DateTime? hasta}) {
    Query q = _db.collection('producciones').orderBy('fecha', descending: true);
    if (desde != null) q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    if (hasta != null) q = q.where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    return q.snapshots().map((s) => s.docs.map(ProduccionModel.fromFirestore).toList());
  }

  Future<void> guardarProduccion(ProduccionModel p) async {
    if (p.id.isEmpty) {
      await _db.collection('producciones').add(p.toMap());
    } else {
      await _db.collection('producciones').doc(p.id).set(p.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> eliminarProduccion(String id) async {
    await _db.collection('producciones').doc(id).delete();
  }

  // ─── PÉRDIDAS ─────────────────────────────────────────────
  Stream<List<PerdidaModel>> getPerdidas({DateTime? desde, DateTime? hasta}) {
    Query q = _db.collection('perdidas').orderBy('fecha', descending: true);
    if (desde != null) q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    if (hasta != null) q = q.where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    return q.snapshots().map((s) => s.docs.map(PerdidaModel.fromFirestore).toList());
  }

  Future<void> guardarPerdida(PerdidaModel p) async {
    if (p.id.isEmpty) {
      await _db.collection('perdidas').add(p.toMap());
    } else {
      await _db.collection('perdidas').doc(p.id).set(p.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> eliminarPerdida(String id) async {
    await _db.collection('perdidas').doc(id).delete();
  }

  // ─── VENTAS ───────────────────────────────────────────────
  Stream<List<VentaModel>> getVentas({DateTime? desde, DateTime? hasta}) {
    Query q = _db.collection('ventas').orderBy('fecha', descending: true);
    if (desde != null) q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    if (hasta != null) q = q.where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    return q.snapshots().map((s) => s.docs.map(VentaModel.fromFirestore).toList());
  }

  Future<void> guardarVenta(VentaModel v) async {
    if (v.id.isEmpty) {
      await _db.collection('ventas').add(v.toMap());
    } else {
      await _db.collection('ventas').doc(v.id).set(v.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> eliminarVenta(String id) async {
    await _db.collection('ventas').doc(id).delete();
  }

  // ─── ESTADO POR MES (todo un año) ─────────────────────────
  // Devuelve 12 resúmenes (enero..diciembre) con 3 consultas en vez de 36
  Future<List<ResumenMes>> getResumenAnual(int year) async {
    final desde = Timestamp.fromDate(DateTime(year, 1, 1));
    final hasta = Timestamp.fromDate(DateTime(year + 1, 1, 1));

    Future<QuerySnapshot<Map<String, dynamic>>> delAnio(String col) => _db
        .collection(col)
        .where('fecha', isGreaterThanOrEqualTo: desde)
        .where('fecha', isLessThan: hasta)
        .get();

    final res = await Future.wait([delAnio('producciones'), delAnio('perdidas'), delAnio('ventas')]);
    final meses = List.generate(12, (i) => ResumenMes(year: year, month: i + 1));

    int mesDe(Map<String, dynamic> d) => (d['fecha'] as Timestamp).toDate().month - 1;
    double kg(Map<String, dynamic> d) => (d['cantidad_kg'] ?? 0).toDouble();

    for (final doc in res[0].docs) {
      meses[mesDe(doc.data())].produccionKg += kg(doc.data());
    }
    for (final doc in res[1].docs) {
      meses[mesDe(doc.data())].perdidaKg += kg(doc.data());
    }
    for (final doc in res[2].docs) {
      final m = meses[mesDe(doc.data())];
      m.vendidoKg += kg(doc.data());
      m.ingresos += (doc.data()['total'] ?? 0).toDouble();
      m.numVentas++;
    }
    return meses;
  }

  // ─── ESTADÍSTICAS DEL MES ─────────────────────────────────
  Future<Map<String, dynamic>> getResumenMes(int year, int month) async {
    final desde = DateTime(year, month, 1);
    final hasta = DateTime(year, month + 1, 0, 23, 59, 59);

    final prodSnap = await _db.collection('producciones')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .get();

    final perdSnap = await _db.collection('perdidas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .get();

    final ventSnap = await _db.collection('ventas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .get();

    double totalProd = 0;
    for (final d in prodSnap.docs) {
      totalProd += (d['cantidad_kg'] ?? 0).toDouble();
    }

    double totalPerd = 0;
    for (final d in perdSnap.docs) {
      totalPerd += (d['cantidad_kg'] ?? 0).toDouble();
    }

    double totalVentas = 0;
    double totalIngresos = 0;
    for (final d in ventSnap.docs) {
      totalVentas += (d['cantidad_kg'] ?? 0).toDouble();
      totalIngresos += (d['total'] ?? 0).toDouble();
    }

    final pctPerdida = totalProd > 0 ? (totalPerd / totalProd) * 100 : 0.0;

    return {
      'produccion_kg': totalProd,
      'perdida_kg': totalPerd,
      'pct_perdida': pctPerdida,
      'vendido_kg': totalVentas,
      'ingresos': totalIngresos,
      'num_ventas': ventSnap.docs.length,
    };
  }
}
