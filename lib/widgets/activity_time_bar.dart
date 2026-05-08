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
        if (stats.isEmpty) {
          return const Text(
            'Aún no hay sesiones esta semana',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          );
        }
        final total = stats.values.fold<int>(0, (a, b) => a + b);
        if (total == 0) return const SizedBox(height: 8);

        return activitiesAsync.when(
          loading: () => const SizedBox(height: 8),
          error: (e, s) => const SizedBox(height: 8),
          data: (acts) => _buildList(context, stats, acts, total),
        );
      },
    );
  }

  Widget _buildList(
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
      children: entries.map((e) {
        final act = actMap[e.key];
        final color = Color(act?.colorValue ?? 0xFFE05A3A);
        final pct = e.value / total;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      act?.name ?? '?',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatDuration(e.value),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(pct * 100).round()}%',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: color.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
