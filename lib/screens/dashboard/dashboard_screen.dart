import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../services/firestore_service.dart';
import '../produccion/produccion_screen.dart';
import '../perdidas/perdidas_screen.dart';
import '../ventas/ventas_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  final _fmt = NumberFormat('#,##0', 'es_CO');
  final _fmtM = NumberFormat('#,##0.0', 'es_CO');

  static const _green  = Color(0xFF1B3A26);
  static const _green2 = Color(0xFF2D5A3D);
  static const _amber  = Color(0xFFE8C547);

  @override
  Widget build(BuildContext context) {
    final usuario = (context.read<AuthBloc>().state as AuthAuthenticated).usuario;
    final now = DateTime.now();

    final screens = [
      _buildHome(usuario, now),
      const ProduccionScreen(),
      const PerdidasScreen(),
      const VentasScreen(),
    ];

    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD8F3DC),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco_rounded), label: 'Producción'),
          NavigationDestination(icon: Icon(Icons.trending_down_outlined), selectedIcon: Icon(Icons.trending_down_rounded), label: 'Pérdidas'),
          NavigationDestination(icon: Icon(Icons.attach_money_outlined), selectedIcon: Icon(Icons.attach_money_rounded), label: 'Ventas'),
        ],
      ),
    );
  }

  Widget _buildHome(usuario, DateTime now) {
    return FutureBuilder<Map<String, dynamic>>(
      future: context.read<FirestoreService>().getResumenMes(now.year, now.month),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final prodKg    = (data['produccion_kg'] ?? 0.0) as double;
        final perdKg    = (data['perdida_kg'] ?? 0.0) as double;
        final pctPerd   = (data['pct_perdida'] ?? 0.0) as double;
        final vendKg    = (data['vendido_kg'] ?? 0.0) as double;
        final ingresos  = (data['ingresos'] ?? 0.0) as double;
        final loading   = snap.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: _green,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B3A26), Color(0xFF2D5A3D)],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Bienvenido', style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 13)),
                      const Text('Cultivos Molina',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        DateFormat('MMMM yyyy · La Cumbre, Valle del Cauca', 'es_CO').format(DateTime.now()),
                        style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Text('RESUMEN DEL MES',
                        style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 10, letterSpacing: .1),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        _kpiCard('🥬 Producción', loading ? '...' : '${_fmtM.format(prodKg/1000)} t', _green2, true),
                        const SizedBox(width: 8),
                        _kpiCard('💰 Ingresos', loading ? '...' : '\$${_fmtM.format(ingresos/1000000)}M', null, false),
                        const SizedBox(width: 8),
                        _kpiCard('📉 Pérdidas', loading ? '...' : '${pctPerd.toStringAsFixed(1)}%',
                          pctPerd > 10 ? Colors.red[800] : null, false),
                        const SizedBox(width: 8),
                        _kpiCard('🛒 Vendido', loading ? '...' : '${_fmtM.format(vendKg/1000)} t', null, false),
                      ]),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(children: [
                if (pctPerd > 10)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '⚠ Margen de pérdidas supera el 10%. Revisa el módulo de pérdidas.',
                          style: TextStyle(color: Colors.red[800], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),

                _sectionTitle('Producción · Ventas'),
                const SizedBox(height: 10),
                _chartCard(loading),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, Color? bg, bool big) {
    return Expanded(
      flex: big ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withOpacity(.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 10)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
              style: TextStyle(
                color: bg == null ? _amber : Colors.white,
                fontSize: big ? 18 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A), letterSpacing: .08),
  );

  Widget _chartCard(bool loading) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10)],
      ),
      child: StreamBuilder(
        stream: context.read<FirestoreService>().getProducciones(
          desde: DateTime(DateTime.now().year, DateTime.now().month, 1),
          hasta: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        ),
        builder: (context, snapProd) {
          return StreamBuilder(
            stream: context.read<FirestoreService>().getVentas(
              desde: DateTime(DateTime.now().year, DateTime.now().month, 1),
              hasta: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
            ),
            builder: (context, snapVent) {
              // Agrupar por semana
              final Map<int, double> prod = {1:0,2:0,3:0,4:0,5:0,6:0};
              final Map<int, double> vent = {1:0,2:0,3:0,4:0,5:0,6:0};

              if (snapProd.hasData) {
                for (final p in snapProd.data!) {
                  final w = ((p.fecha.day - 1) ~/ 7 + 1).clamp(1, 6);
                  prod[w] = (prod[w] ?? 0) + p.cantidadKg;
                }
              }
              if (snapVent.hasData) {
                for (final v in snapVent.data!) {
                  final w = ((v.fecha.day - 1) ~/ 7 + 1).clamp(1, 6);
                  vent[w] = (vent[w] ?? 0) + v.cantidadKg;
                }
              }

              return BarChart(BarChartData(
                barGroups: List.generate(6, (i) {
                  final s = i + 1;
                  return BarChartGroupData(x: s, barRods: [
                    BarChartRodData(toY: prod[s]!, color: const Color(0xFF3D7A52), width: 10, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: vent[s]!, color: const Color(0xFFE8C547), width: 10, borderRadius: BorderRadius.circular(4)),
                  ]);
                }),
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
              ));
            },
          );
        },
      ),
    );
  }
}
