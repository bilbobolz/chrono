import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activities_provider.dart';
import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';

class ActivityTimeBar extends ConsumerWidget {
  const ActivityTimeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsByActivityProvider);
    final activitiesAsync = ref.watch(activitiesProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 8),
      error: (e, s) => const SizedBox(height: 8),
      data: (stats) {
        if (stats.isEmpty) return const SizedBox(height: 8);
        final total = stats.values.fold(0, (a, b) => a + b);
        if (total == 0) return const SizedBox(height: 8);

        return activitiesAsync.when(
          loading: () => const SizedBox(height: 8),
          error: (e, s) => const SizedBox(height: 8),
          data: (acts) => _buildBar(context, stats, acts, total),
        );
      },
    );
  }

  Widget _buildBar(
    BuildContext context,
    Map<int, int> stats,
    activities,
    int total,
  ) {
    final actMap = {for (final a in activities) a.id: a};
    final entries = (stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: entries.map((e) {
                final color = Color(actMap[e.key]?.colorValue ?? 0xFF6C63FF);
                final flex = (e.value / total * 1000).round().clamp(1, 999);
                return Expanded(
                  flex: flex,
                  child: Container(color: color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: entries.map((e) {
            final act = actMap[e.key];
            final color = Color(act?.colorValue ?? 0xFF6C63FF);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  '${act?.name ?? '?'} · ${formatDuration(e.value)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
