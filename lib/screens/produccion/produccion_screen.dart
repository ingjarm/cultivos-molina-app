import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/eliminar_registro.dart';

class ProduccionScreen extends StatefulWidget {
  const ProduccionScreen({super.key});
  @override State<ProduccionScreen> createState() => _ProduccionScreenState();
}

class _ProduccionScreenState extends State<ProduccionScreen> {
  static const _green  = Color(0xFF1B3A26);
  static const _green2 = Color(0xFF2D5A3D);
  final _fmt = NumberFormat('#,##0.0', 'es_CO');

  @override
  Widget build(BuildContext context) {
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F2),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _green,
            title: const Text('Producción', style: TextStyle(color: Colors.white)),
            pinned: true,
            actions: [
              // El admin solo consulta: no registra
              if (!usuario.esAdmin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: () => _showFormDialog(context),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<ProduccionModel>>(
              stream: context.read<FirestoreService>().getProducciones(
                desde: DateTime(DateTime.now().year, DateTime.now().month, 1),
                hasta: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final lista = snap.data ?? [];
                final totalKg = lista.fold(0.0, (s, p) => s + p.cantidadKg);

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI total mes
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2D5A3D), Color(0xFF3D7A52)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Total producido este mes',
                            style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('${_fmt.format(totalKg / 1000)} t',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                          Text('${_fmt.format(totalKg)} kg',
                            style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      const Text('REGISTROS DEL MES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A), letterSpacing: .1)),
                      const SizedBox(height: 10),

                      if (lista.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(usuario.esAdmin ? 'Sin registros este mes.' : 'Sin registros este mes.\nToca + para agregar.', textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ...lista.map((p) => _ProduccionCard(
                          p: p,
                          fmt: _fmt,
                          // Cada operario solo puede borrar lo que él registró
                          onEliminar: !usuario.esAdmin && p.usuarioId == usuario.uid
                              ? () => context.read<FirestoreService>().eliminarProduccion(p.id)
                              : null,
                        )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: usuario.esAdmin ? null : FloatingActionButton.extended(
        backgroundColor: _green2,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cosecha'),
        onPressed: () => _showFormDialog(context),
      ),
    );
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
          child: const _ProduccionForm(),
        ),
      ),
    );
  }
}

// ── CARD ──────────────────────────────────────────────────────
class _ProduccionCard extends StatelessWidget {
  final ProduccionModel p;
  final NumberFormat fmt;
  final Future<void> Function()? onEliminar;
  const _ProduccionCard({required this.p, required this.fmt, this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final color = _variedadColor(p.variedadLabel);
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
          decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('🥬', style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.loteNombre} — ${p.variedadLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(DateFormat('dd MMM yyyy', 'es_CO').format(p.fecha),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (p.usuarioNombre.isNotEmpty)
            Text('Registró: ${p.usuarioNombre}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${fmt.format(p.cantidadKg)} kg',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          if (!p.sincronizado)
            const Icon(Icons.cloud_off, size: 14, color: Colors.orange),
        ]),
        if (onEliminar != null)
          EliminarRegistroButton(
            descripcion: '${p.loteNombre} — ${p.variedadLabel} · ${fmt.format(p.cantidadKg)} kg',
            onEliminar: onEliminar!,
          ),
      ]),
    );
  }

  Color _variedadColor(String v) {
    if (v == 'Batavia') return const Color(0xFF2D5A3D);
    if (v == 'Romana')  return const Color(0xFF1A5276);
    return const Color(0xFF6A1B4D);
  }
}

extension on ProduccionModel {
  String get variedadLabel => variedad.label;
}

// ── FORMULARIO ────────────────────────────────────────────────
class _ProduccionForm extends StatefulWidget {
  const _ProduccionForm();
  @override State<_ProduccionForm> createState() => _ProduccionFormState();
}

class _ProduccionFormState extends State<_ProduccionForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = DateTime.now();
  LoteModel? _lote;
  Variedad _variedad = Variedad.batavia;
  final _cantCtrl = TextEditingController();
  String _clima = 'soleado';
  final _obsCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _lote == null) {
      if (_lote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un lote')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;

    final produccion = ProduccionModel(
      id: '',
      loteId: _lote!.id,
      loteNombre: _lote!.nombre,
      usuarioId: usuario.uid,
      usuarioNombre: usuario.nombre,
      variedad: _variedad,
      cantidadKg: double.parse(_cantCtrl.text.replaceAll(',', '.')),
      fecha: _fecha,
      condicionClimatica: _clima,
      observaciones: _obsCtrl.text,
      sincronizado: true,
      creadoEn: DateTime.now(),
    );

    try {
      await context.read<FirestoreService>().guardarProduccion(produccion);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cosecha de ${_variedad.label} guardada — ${_cantCtrl.text} kg'),
            backgroundColor: const Color(0xFF2D5A3D),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
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
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Nueva Producción',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Fecha
            _label('FECHA DE COSECHA'),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _fecha = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2D5A3D), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF0F7F2),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF2D5A3D)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd / MM / yyyy').format(_fecha),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Lote
            _label('LOTE / PARCELA'),
            StreamBuilder<List<LoteModel>>(
              stream: context.read<FirestoreService>().getLotesActivos(),
              builder: (context, snap) {
                final lotes = snap.data ?? [];
                return DropdownButtonFormField<LoteModel>(
                  initialValue: _lote,
                  hint: const Text('Seleccionar lote'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: lotes.map((l) => DropdownMenuItem(
                    value: l,
                    child: Text('${l.nombre} — ${NumberFormat('#,##0', 'es_CO').format(l.areaM2)} m²'),
                  )).toList(),
                  onChanged: (l) => setState(() => _lote = l),
                );
              },
            ),
            const SizedBox(height: 14),

            // Cantidad
            _label('CANTIDAD COSECHADA (KG)'),
            TextFormField(
              controller: _cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1B3A26)),
              decoration: InputDecoration(
                suffix: const Text('kg', style: TextStyle(color: Colors.grey)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D5A3D), width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D5A3D), width: 1.5)),
                fillColor: const Color(0xFFF0F7F2),
                filled: true,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa la cantidad';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Variedad
            _label('VARIEDAD DE LECHUGA'),
            Wrap(spacing: 8, children: Variedad.values.map((v) =>
              FilterChip(
                label: Text(v.label),
                selected: _variedad == v,
                onSelected: (_) => setState(() => _variedad = v),
                selectedColor: const Color(0xFF2D5A3D),
                labelStyle: TextStyle(
                  color: _variedad == v ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                checkmarkColor: Colors.white,
              ),
            ).toList()),
            const SizedBox(height: 14),

            // Clima
            _label('CONDICIÓN CLIMÁTICA'),
            Wrap(spacing: 8, children: [
              for (final c in [('soleado','☀ Soleado'), ('lluvia','🌧 Lluvia'), ('nublado','☁ Nublado')])
                FilterChip(
                  label: Text(c.$2),
                  selected: _clima == c.$1,
                  onSelected: (_) => setState(() => _clima = c.$1),
                  selectedColor: const Color(0xFFFDF5DC),
                  labelStyle: TextStyle(
                    color: _clima == c.$1 ? const Color(0xFF7A5500) : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ]),
            const SizedBox(height: 14),

            // Observaciones
            _label('OBSERVACIONES'),
            TextFormField(
              controller: _obsCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Agregar nota opcional...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5A3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Guardando...' : 'Guardar registro',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
