import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activities_provider.dart';
import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _GlobalSummary(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _PeriodSelector(selected: period),
        ),
        Expanded(child: _StatsBody(period: period)),
      ],
    );
  }
}

class _GlobalSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalFocusProvider);
    final daysAsync = ref.watch(activeDaysProvider);
    final streakAsync = ref.watch(streakProvider);

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.local_fire_department,
          iconColor: const Color(0xFFE05A3A),
          label: 'Racha',
          value: streakAsync.when(
            data: (v) => '$v día${v == 1 ? '' : 's'}',
            loading: () => '—',
            error: (e, s) => '—',
          ),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          icon: Icons.timer,
          iconColor: const Color(0xFF4FC3F7),
          label: 'Foco total',
          value: totalAsync.when(
            data: (s) => _formatHours(s),
            loading: () => '—',
            error: (e, s) => '—',
          ),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF43C6AC),
          label: 'Días activo',
          value: daysAsync.when(
            data: (v) => '$v',
            loading: () => '—',
            error: (e, s) => '—',
          ),
        ),
      ],
    );
  }

  String _formatHours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  final StatsPeriod selected;
  const _PeriodSelector({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      (StatsPeriod.day, 'Hoy'),
      (StatsPeriod.week, 'Semana'),
      (StatsPeriod.month, 'Mes'),
      (StatsPeriod.year, 'Año'),
    ];
    return SegmentedButton<StatsPeriod>(
      segments: options
          .map((o) => ButtonSegment(value: o.$1, label: Text(o.$2)))
          .toList(),
      selected: {selected},
      onSelectionChanged: (s) =>
          ref.read(statsPeriodProvider.notifier).state = s.first,
    );
  }
}

class _StatsBody extends ConsumerWidget {
  final StatsPeriod period;
  const _StatsBody({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsByActivityProvider);
    final activitiesAsync = ref.watch(activitiesProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activities) => _buildContent(context, stats, activities),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<int, int> stats, activities) {
    final actMap = {for (final a in activities) a.id: a};
    final totalSeconds =
        stats.values.fold(0, (a, b) => a + b);

    if (totalSeconds == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Sin datos para este período'),
          ],
        ),
      );
    }

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Total',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDuration(totalSeconds),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pie chart
        if (entries.length > 1)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: entries.map((e) {
                      final color = Color(actMap[e.key]?.colorValue ?? 0xFF6C63FF);
                      final pct = e.value / totalSeconds * 100;
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        color: color,
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 70,
                        titleStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Per activity list
        ...entries.map((e) {
          final act = actMap[e.key];
          if (act == null) return const SizedBox.shrink();
          final color = Color(act.colorValue);
          final pct = e.value / totalSeconds;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(act.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        formatDuration(e.value),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withAlpha(40),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}% del total',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
