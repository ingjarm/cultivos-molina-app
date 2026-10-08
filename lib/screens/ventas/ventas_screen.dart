import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../blocs/auth/auth_bloc.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});
  @override State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _fmtM   = NumberFormat('\$#,##0', 'es_CO');
  final _fmtKg  = NumberFormat('#,##0.0', 'es_CO');

  static const _amber  = Color(0xFFE8C547);
  static const _dark   = Color(0xFF1B3A26);
  static const _green  = Color(0xFF2D5A3D);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final desde = DateTime(now.year, now.month, 1);
    final hasta = DateTime(now.year, now.month + 1, 0, 23, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EC),
      body: StreamBuilder<List<VentaModel>>(
        stream: context.read<FirestoreService>().getVentas(desde: desde, hasta: hasta),
        builder: (ctx, snap) {
          final lista = snap.data ?? [];
          final totalIngresos = lista.fold(0.0, (s, v) => s + v.total);
          final totalKg       = lista.fold(0.0, (s, v) => s + v.cantidadKg);
          final precioPromedio = lista.isEmpty ? 0.0 : totalIngresos / totalKg;

          // Datos para la gráfica por semana
          final Map<int, double> semanas = {1:0,2:0,3:0,4:0,5:0,6:0};
          for (final v in lista) {
            final w = ((v.fecha.day - 1) ~/ 7 + 1).clamp(1, 6);
            semanas[w] = (semanas[w] ?? 0) + v.total;
          }

          final esAdmin = (context.read<AuthBloc>().state as AuthAuthenticated).usuario.esAdmin;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF5A3E00),
                title: const Text('💰 Ventas', style: TextStyle(color: Color(0xFFFDF5DC))),
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _showFormDialog(context),
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(children: [

                  // KPIs
                  Row(children: [
                    _kpi(_fmtM.format(totalIngresos), 'Ingreso total', _amber, const Color(0xFFFDF5DC)),
                    const SizedBox(width: 8),
                    _kpi('${_fmtKg.format(totalKg / 1000)} t', 'Total vendido', _dark, Colors.white),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _kpi(esAdmin ? _fmtM.format(precioPromedio) : '---', 'Precio/kg prom.', _dark, Colors.white),
                    const SizedBox(width: 8),
                    _kpi('${lista.length}', 'Ventas este mes', _green, const Color(0xFFE8F5EC)),
                  ]),
                  const SizedBox(height: 16),

                  // Gráfica de línea
                  _sectionTitle('Evolución de ingresos (semanas)'),
                  Container(
                    height: 160,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
                    ),
                    child: LineChart(LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(6, (i) => FlSpot((i + 1).toDouble(), semanas[i + 1]! / 1000)),
                          isCurved: true,
                          color: _green,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            getDotPainter: (spot, __, ___, ____) => FlDotCirclePainter(
                              radius: 4,
                              color: _green,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _green.withOpacity(.08),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) => Text('S${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    )),
                  ),
                  const SizedBox(height: 16),

                  // Lista de ventas
                  _sectionTitle('ÚLTIMAS VENTAS'),
                  if (lista.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Sin ventas este mes.\nToca + para registrar.', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...lista.map((v) => _VentaCard(v: v, fmtM: _fmtM, fmtKg: _fmtKg, esAdmin: esAdmin)),
                ]),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _amber,
        foregroundColor: _dark,
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showFormDialog(context),
      ),
    );
  }

  Widget _kpi(String value, String label, Color textColor, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A), letterSpacing: .08)),
  );

  void _showFormDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: RepositoryProvider.value(
          value: context.read<FirestoreService>(),
          child: const _VentaForm(),
        ),
      ),
    );
  }
}

// ── CARD ──────────────────────────────────────────────────────
class _VentaCard extends StatelessWidget {
  final VentaModel v;
  final NumberFormat fmtM, fmtKg;
  final bool esAdmin;
  const _VentaCard({required this.v, required this.fmtM, required this.fmtKg, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFD8F3DC), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(_varEmoji(v.variedad), style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.cliente, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${DateFormat('dd MMM', 'es_CO').format(v.fecha)} · ${fmtKg.format(v.cantidadKg)} kg',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        Text(esAdmin ? fmtM.format(v.total) : '---',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF2D5A3D))),
      ]),
    );
  }

  String _varEmoji(Variedad v) {
    switch (v) {
      case Variedad.batavia: return '🥬';
      case Variedad.romana:  return '🌿';
      case Variedad.crespa:  return '🍃';
    }
  }
}

// ── FORMULARIO ────────────────────────────────────────────────
class _VentaForm extends StatefulWidget {
  const _VentaForm();
  @override State<_VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<_VentaForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = DateTime.now();
  Variedad _variedad = Variedad.batavia;
  final _clienteCtrl = TextEditingController();
  final _cantCtrl    = TextEditingController();
  final _precioCtrl  = TextEditingController();
  double _total = 0;
  bool _saving = false;

  @override
  void dispose() {
    _clienteCtrl.dispose(); _cantCtrl.dispose(); _precioCtrl.dispose();
    super.dispose();
  }

  void _calcTotal() {
    final cant  = double.tryParse(_cantCtrl.text.replaceAll(',', '.')) ?? 0;
    final precio = double.tryParse(_precioCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    setState(() => _total = cant * precio);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;

    final venta = VentaModel(
      id: '',
      usuarioId: usuario.uid,
      variedad: _variedad,
      cliente: _clienteCtrl.text.trim(),
      cantidadKg: double.parse(_cantCtrl.text.replaceAll(',', '.')),
      precioKg: double.parse(_precioCtrl.text.replaceAll('.', '')),
      total: _total,
      fecha: _fecha,
    );

    try {
      await context.read<FirestoreService>().guardarVenta(venta);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venta de ${_variedad.label} registrada'), backgroundColor: const Color(0xFF2D5A3D)),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtM = NumberFormat('\$#,##0', 'es_CO');
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Nueva Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Fecha
            _label('FECHA'),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => _fecha = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8C547), width: 1.5),
                  borderRadius: BorderRadius.circular(12), color: const Color(0xFFFDF5DC),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF7A5500)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd / MM / yyyy').format(_fecha), style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Cliente
            _label('CLIENTE'),
            TextFormField(
              controller: _clienteCtrl,
              decoration: InputDecoration(hintText: 'Nombre del cliente o punto de venta', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa el cliente' : null,
            ),
            const SizedBox(height: 14),

            // Variedad
            _label('VARIEDAD'),
            Wrap(spacing: 8, children: Variedad.values.map((v) =>
              FilterChip(label: Text(v.label), selected: _variedad == v,
                onSelected: (_) => setState(() => _variedad = v),
                selectedColor: const Color(0xFF2D5A3D),
                labelStyle: TextStyle(color: _variedad == v ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
              ),
            ).toList()),
            const SizedBox(height: 14),

            // Cantidad y precio
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('CANTIDAD (KG)'),
                TextFormField(
                  controller: _cantCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(suffix: const Text('kg'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  onChanged: (_) => _calcTotal(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                    return null;
                  },
                ),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('PRECIO/KG'),
                TextFormField(
                  controller: _precioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(prefix: const Text('\$'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  onChanged: (_) => _calcTotal(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    return null;
                  },
                ),
              ])),
            ]),
            const SizedBox(height: 14),

            // Total calculado
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFD8F3DC), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Ingreso total', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D5A3D))),
                Text(fmtM.format(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1B3A26))),
              ]),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8C547), foregroundColor: const Color(0xFF1B3A26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Guardando...' : 'Guardar venta', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A), letterSpacing: .08)),
  );
}
