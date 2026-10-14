import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../blocs/auth/auth_bloc.dart';

// Estado por mes: un resumen por cada mes del año para comparar y decidir
class MesesScreen extends StatefulWidget {
  const MesesScreen({super.key});
  @override State<MesesScreen> createState() => _MesesScreenState();
}

class _MesesScreenState extends State<MesesScreen> {
  static const _green = Color(0xFF1B3A26);
  final _fmt  = NumberFormat('#,##0.0', 'es_CO');
  final _fmtM = NumberFormat('\$#,##0', 'es_CO');

  late int _year;
  late Future<List<ResumenMes>> _future;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _cargar();
  }

  void _cargar() {
    _future = context.read<FirestoreService>().getResumenAnual(_year);
  }

  void _cambiarAnio(int delta) {
    setState(() {
      _year += delta;
      _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = (context.read<AuthBloc>().state as AuthAuthenticated).usuario.esAdmin;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F2),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_cargar);
          await _future;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: _green,
              pinned: true,
              title: const Text('Estado por mes', style: TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  tooltip: 'Año anterior',
                  onPressed: () => _cambiarAnio(-1),
                ),
                Center(child: Text('$_year',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _year < now.year ? Colors.white : Colors.white24),
                  tooltip: 'Año siguiente',
                  onPressed: _year < now.year ? () => _cambiarAnio(1) : null,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<ResumenMes>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error al cargar: ${snap.error}', style: const TextStyle(color: Colors.red)),
                    );
                  }

                  // Del año en curso solo se muestran los meses que ya empezaron
                  final ultimoMes = _year == now.year ? now.month : 12;
                  final meses = snap.data!.take(ultimoMes).toList();
                  final recientes = meses.reversed.toList();

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _resumenAnual(meses, esAdmin),
                      const SizedBox(height: 12),
                      _leyenda(),
                      const SizedBox(height: 16),
                      for (var i = 0; i < recientes.length; i++)
                        _MesCard(
                          m: recientes[i],
                          // El mes anterior (para comparar la producción)
                          anterior: i + 1 < recientes.length ? recientes[i + 1] : null,
                          esAdmin: esAdmin,
                          fmt: _fmt,
                          fmtM: _fmtM,
                        ),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenAnual(List<ResumenMes> meses, bool esAdmin) {
    final prod = meses.fold(0.0, (s, m) => s + m.produccionKg);
    final perd = meses.fold(0.0, (s, m) => s + m.perdidaKg);
    final vend = meses.fold(0.0, (s, m) => s + m.vendidoKg);
    final ing  = meses.fold(0.0, (s, m) => s + m.ingresos);
    final pct  = prod > 0 ? perd / prod * 100 : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2D5A3D), Color(0xFF3D7A52)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ACUMULADO $_year',
          style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11, letterSpacing: .1)),
        const SizedBox(height: 10),
        Wrap(spacing: 20, runSpacing: 10, children: [
          _dato('Producción', '${_fmt.format(prod / 1000)} t'),
          _dato('Pérdidas', '${pct.toStringAsFixed(1)}%'),
          _dato('Vendido', '${_fmt.format(vend / 1000)} t'),
          if (esAdmin) _dato('Ingresos', _fmtM.format(ing)),
        ]),
      ]),
    );
  }

  Widget _dato(String label, String valor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(valor, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 11)),
    ],
  );

  Widget _leyenda() => Wrap(spacing: 12, runSpacing: 4, children: [
    for (final e in [EstadoMes.bueno, EstadoMes.atencion, EstadoMes.critico])
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: estadoColor(e), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('${e.label} ${_umbral(e)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
  ]);

  String _umbral(EstadoMes e) {
    switch (e) {
      case EstadoMes.bueno:    return '(pérdida ≤ 5%)';
      case EstadoMes.atencion: return '(5–10%)';
      case EstadoMes.critico:  return '(> 10%)';
      case EstadoMes.sinDatos: return '';
    }
  }
}

Color estadoColor(EstadoMes e) {
  switch (e) {
    case EstadoMes.bueno:    return const Color(0xFF2E7D32);
    case EstadoMes.atencion: return const Color(0xFFE09B00);
    case EstadoMes.critico:  return const Color(0xFFB22222);
    case EstadoMes.sinDatos: return Colors.grey;
  }
}

// ── TARJETA DE UN MES ─────────────────────────────────────────
class _MesCard extends StatelessWidget {
  final ResumenMes m;
  final ResumenMes? anterior;
  final bool esAdmin;
  final NumberFormat fmt, fmtM;

  const _MesCard({
    required this.m,
    required this.anterior,
    required this.esAdmin,
    required this.fmt,
    required this.fmtM,
  });

  @override
  Widget build(BuildContext context) {
    final estado = m.estado;
    final color = estadoColor(estado);
    final nombreMes = DateFormat('MMMM', 'es_CO').format(DateTime(m.year, m.month));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${nombreMes[0].toUpperCase()}${nombreMes.substring(1)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
            child: Text(estado.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        if (m.tieneDatos) ...[
          const SizedBox(height: 10),
          Row(children: [
            _celda('Producción', '${fmt.format(m.produccionKg)} kg', _variacion()),
            _celda('Pérdida', '${m.pctPerdida.toStringAsFixed(1)}%', '${fmt.format(m.perdidaKg)} kg'),
            _celda('Vendido', '${fmt.format(m.vendidoKg)} kg', '${m.numVentas} ventas'),
          ]),
          if (esAdmin) ...[
            const SizedBox(height: 8),
            Text('Ingresos: ${fmtM.format(m.ingresos)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D5A3D))),
          ],
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No hay registros en este mes.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
      ]),
    );
  }

  // Cambio de la producción frente al mes anterior, ej. "▲ 12% vs mes ant."
  String? _variacion() {
    final a = anterior;
    if (a == null || a.produccionKg == 0) return null;
    final pct = (m.produccionKg - a.produccionKg) / a.produccionKg * 100;
    final flecha = pct >= 0 ? '▲' : '▼';
    return '$flecha ${pct.abs().toStringAsFixed(0)}% vs mes ant.';
  }

  Widget _celda(String label, String valor, String? sub) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
      if (sub != null)
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );
}
