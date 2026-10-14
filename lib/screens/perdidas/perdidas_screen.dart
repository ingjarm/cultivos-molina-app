import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/eliminar_registro.dart';

class PerdidasScreen extends StatefulWidget {
  const PerdidasScreen({super.key});
  @override State<PerdidasScreen> createState() => _PerdidasScreenState();
}

class _PerdidasScreenState extends State<PerdidasScreen> {
  final _fmt = NumberFormat('#,##0.0', 'es_CO');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final desde = DateTime(now.year, now.month, 1);
    final hasta = DateTime(now.year, now.month + 1, 0, 23, 59);
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1F1),
      body: StreamBuilder<List<ProduccionModel>>(
        stream: context.read<FirestoreService>().getProducciones(desde: desde, hasta: hasta),
        builder: (ctx, snapProd) {
          return StreamBuilder<List<PerdidaModel>>(
            stream: context.read<FirestoreService>().getPerdidas(desde: desde, hasta: hasta),
            builder: (ctx, snapPerd) {
              final prodList = snapProd.data ?? [];
              final perdList = snapPerd.data ?? [];

              final totalProd = prodList.fold(0.0, (s, p) => s + p.cantidadKg);
              final totalPerd = perdList.fold(0.0, (s, p) => s + p.cantidadKg);
              final pct = totalProd > 0 ? (totalPerd / totalProd) * 100 : 0.0;
              final aprovechado = 100 - pct;
              final alerta = pct > 10;

              // Causas
              final Map<CausaPerdida, double> causas = {};
              for (final p in perdList) {
                causas[p.causa] = (causas[p.causa] ?? 0) + p.cantidadKg;
              }

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: alerta ? const Color(0xFF8B1A1A) : const Color(0xFFB22222),
                    title: const Text('Análisis de Pérdidas', style: TextStyle(color: Colors.white)),
                    pinned: true,
                    actions: [
                      // El admin solo consulta: no registra
                      if (!usuario.esAdmin)
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _showFormDialog(context),
                        ),
                    ],
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.list(children: [

                      // ALERTA
                      if (alerta)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Pérdidas superan el 10% — se recomienda revisión inmediata',
                                style: TextStyle(color: Colors.red[800], fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),

                      // KPIs
                      Row(children: [
                        _kpi('${pct.toStringAsFixed(1)}%', '% Pérdida', alerta ? const Color(0xFFB22222) : Colors.orange),
                        const SizedBox(width: 8),
                        _kpi('${aprovechado.toStringAsFixed(1)}%', '% Aprovechado', const Color(0xFF2D5A3D)),
                        const SizedBox(width: 8),
                        _kpi('${_fmt.format(totalPerd)} kg', 'Pérdida total', Colors.grey[700]!),
                      ]),
                      const SizedBox(height: 16),

                      // GRÁFICO DONA
                      if (totalPerd > 0) ...[
                        _cardTitle('Distribución de pérdidas'),
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
                          ),
                          child: Row(children: [
                            Expanded(
                              child: PieChart(PieChartData(
                                centerSpaceRadius: 40,
                                sections: _buildSections(causas, totalPerd),
                                sectionsSpace: 2,
                              )),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: causas.entries.map((e) {
                                final pctC = totalPerd > 0 ? (e.value / totalPerd) * 100 : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(
                                      color: _causaColor(e.key), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('${e.key.label} (${pctC.toStringAsFixed(0)}%)',
                                      style: const TextStyle(fontSize: 11)),
                                  ]),
                                );
                              }).toList(),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // CAUSAS PRINCIPALES
                      _cardTitle('Causas principales'),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
                        ),
                        child: Column(
                          children: CausaPerdida.values.map((c) {
                            final kg = causas[c] ?? 0;
                            final pctC = totalPerd > 0 ? kg / totalPerd : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                Text(_causaEmoji(c), style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: pctC,
                                    backgroundColor: Colors.grey[100],
                                    valueColor: AlwaysStoppedAnimation(_causaColor(c)),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ])),
                                const SizedBox(width: 10),
                                Text('${(pctC * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: _causaColor(c), fontSize: 13)),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // REGISTROS DEL MES (todos, para poder corregir cualquiera)
                      _cardTitle('Registros del mes'),
                      if (perdList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Sin pérdidas registradas este mes.',
                            style: TextStyle(color: Colors.grey))),
                        ),
                      ...perdList.map((p) => _PerdidaCard(
                        p: p,
                        fmt: _fmt,
                        // Cada operario solo puede borrar lo que él registró
                        onEliminar: !usuario.esAdmin && p.usuarioId == usuario.uid
                            ? () => context.read<FirestoreService>().eliminarPerdida(p.id)
                            : null,
                      )),
                    ]),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: usuario.esAdmin ? null : FloatingActionButton.extended(
        backgroundColor: const Color(0xFFB22222),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar pérdida'),
        onPressed: () => _showFormDialog(context),
      ),
    );
  }

  Widget _kpi(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6)],
        ),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _cardTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A), letterSpacing: .08)),
  );

  List<PieChartSectionData> _buildSections(Map<CausaPerdida, double> causas, double total) {
    return causas.entries.map((e) {
      final pct = total > 0 ? (e.value / total) * 100 : 0.0;
      return PieChartSectionData(
        value: pct,
        color: _causaColor(e.key),
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
        radius: 50,
      );
    }).toList();
  }

  Color _causaColor(CausaPerdida c) {
    switch (c) {
      case CausaPerdida.plagas:        return const Color(0xFFE53935);
      case CausaPerdida.clima:         return const Color(0xFFE8C547);
      case CausaPerdida.enfermedades:  return const Color(0xFF7B1FA2);
      case CausaPerdida.manipulacion:  return const Color(0xFF9E9E9E);
    }
  }

  String _causaEmoji(CausaPerdida c) {
    switch (c) {
      case CausaPerdida.plagas:        return '🦟';
      case CausaPerdida.clima:         return '🌧';
      case CausaPerdida.enfermedades:  return '🔬';
      case CausaPerdida.manipulacion:  return '📦';
    }
  }

  void _showFormDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: RepositoryProvider.value(
          value: context.read<FirestoreService>(),
          child: const _PerdidaForm(),
        ),
      ),
    );
  }
}

// ── CARD ──────────────────────────────────────────────────────
class _PerdidaCard extends StatelessWidget {
  final PerdidaModel p;
  final NumberFormat fmt;
  final Future<void> Function()? onEliminar;
  const _PerdidaCard({required this.p, required this.fmt, this.onEliminar});

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
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(_emoji(p.causa), style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.loteNombre} — ${p.variedad.label}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${p.causa.label} · ${DateFormat('dd MMM', 'es_CO').format(p.fecha)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (p.usuarioNombre.isNotEmpty)
            Text('Registró: ${p.usuarioNombre}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        Text('${fmt.format(p.cantidadKg)} kg',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFB22222))),
        if (onEliminar != null)
          EliminarRegistroButton(
            descripcion: '${p.loteNombre} — ${p.causa.label} · ${fmt.format(p.cantidadKg)} kg',
            onEliminar: onEliminar!,
          ),
      ]),
    );
  }

  String _emoji(CausaPerdida c) {
    switch (c) {
      case CausaPerdida.plagas:        return '🦟';
      case CausaPerdida.clima:         return '🌧';
      case CausaPerdida.enfermedades:  return '🔬';
      case CausaPerdida.manipulacion:  return '📦';
    }
  }
}

// ── FORMULARIO ────────────────────────────────────────────────
class _PerdidaForm extends StatefulWidget {
  const _PerdidaForm();
  @override State<_PerdidaForm> createState() => _PerdidaFormState();
}

class _PerdidaFormState extends State<_PerdidaForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = DateTime.now();
  LoteModel? _lote;
  Variedad _variedad = Variedad.batavia;
  CausaPerdida _causa = CausaPerdida.plagas;
  final _cantCtrl = TextEditingController();
  final _detalleCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _cantCtrl.dispose(); _detalleCtrl.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _lote == null) return;
    setState(() => _saving = true);
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;

    final perdida = PerdidaModel(
      id: '',
      loteId: _lote!.id,
      loteNombre: _lote!.nombre,
      usuarioId: usuario.uid,
      usuarioNombre: usuario.nombre,
      variedad: _variedad,
      cantidadKg: double.parse(_cantCtrl.text.replaceAll(',', '.')),
      causa: _causa,
      causaDetalle: _detalleCtrl.text,
      fecha: _fecha,
    );

    try {
      await context.read<FirestoreService>().guardarPerdida(perdida);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pérdida registrada'), backgroundColor: Color(0xFFB22222)),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Registrar Pérdida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                  border: Border.all(color: const Color(0xFFB22222), width: 1.5),
                  borderRadius: BorderRadius.circular(12), color: Colors.red[50],
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFB22222)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd / MM / yyyy').format(_fecha), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Lote
            _label('LOTE'),
            StreamBuilder<List<LoteModel>>(
              stream: context.read<FirestoreService>().getLotesActivos(),
              builder: (ctx, snap) {
                final lotes = snap.data ?? [];
                return DropdownButtonFormField<LoteModel>(
                  initialValue: _lote,
                  hint: const Text('Seleccionar lote'),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: lotes.map((l) => DropdownMenuItem(value: l, child: Text(l.nombre))).toList(),
                  onChanged: (l) => setState(() => _lote = l),
                );
              },
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

            // Cantidad
            _label('CANTIDAD PERDIDA (KG)'),
            TextFormField(
              controller: _cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFB22222)),
              decoration: InputDecoration(
                suffix: const Text('kg'),
                fillColor: Colors.red[50], filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa la cantidad';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Causa
            _label('CAUSA'),
            Wrap(spacing: 8, children: CausaPerdida.values.map((c) =>
              ChoiceChip(label: Text(c.label), selected: _causa == c,
                onSelected: (_) => setState(() => _causa = c),
                selectedColor: const Color(0xFFB22222),
                labelStyle: TextStyle(color: _causa == c ? Colors.white : Colors.black87, fontSize: 12),
              ),
            ).toList()),
            const SizedBox(height: 14),

            // Detalle
            _label('DETALLE (OPCIONAL)'),
            TextFormField(
              controller: _detalleCtrl,
              decoration: InputDecoration(
                hintText: 'Descripción adicional...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB22222), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando...' : 'Guardar pérdida', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
