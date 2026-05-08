import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/activities_provider.dart';
import '../providers/timer_provider.dart';
import '../widgets/circular_timer.dart';
import '../widgets/activity_time_bar.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final activitiesAsync = ref.watch(activitiesProvider);

    return activitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (activities) {
        Activity? selected;
        if (timer.activityId != null) {
          try {
            selected = activities.firstWhere((a) => a.id == timer.activityId);
          } catch (_) {}
        }
        final color = selected != null
            ? Color(selected.colorValue)
            : Theme.of(context).colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Activity selector
              _ActivitySelector(
                activities: activities,
                selectedId: timer.activityId,
                enabled: timer.status == TimerStatus.idle,
              ),
              const SizedBox(height: 40),

              // Timer ring
              CircularTimer(
                progress: timer.progress,
                remainingSeconds: timer.remainingSeconds,
                color: color,
                isBreak: timer.phase == TimerPhase.breakPhase,
              ),

              const SizedBox(height: 12),

              // Pomodoros count
              if (timer.completedPomodoros > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    timer.completedPomodoros.clamp(0, 8),
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.circle, size: 13, color: color),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Controls
              _TimerControls(
                status: timer.status,
                hasActivity: timer.activityId != null,
              ),

              const Spacer(),

              // Time bar (current week)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esta semana',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const ActivityTimeBar(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivitySelector extends ConsumerWidget {
  final List<Activity> activities;
  final int? selectedId;
  final bool enabled;

  const _ActivitySelector({
    required this.activities,
    required this.selectedId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activities.isEmpty) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.add),
        label: const Text('Creá una actividad primero'),
      );
    }

    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: DropdownButton<int>(
          value: selectedId,
          hint: const Text('Elegí una actividad'),
          dropdownColor: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          items: activities.map((a) {
            return DropdownMenuItem(
              value: a.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(a.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(a.name),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (id) {
                  if (id == null) return;
                  final act = activities.firstWhere((a) => a.id == id);
                  ref.read(timerProvider.notifier).selectActivity(act);
                }
              : null,
        ),
      ),
    );
  }
}

class _TimerControls extends ConsumerWidget {
  final TimerStatus status;
  final bool hasActivity;

  const _TimerControls({required this.status, required this.hasActivity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timerProvider.notifier);
    final color = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (status != TimerStatus.idle)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.outlined(
              onPressed: () => notifier.stop(),
              icon: const Icon(Icons.stop),
              iconSize: 34,
            ),
          ),
        FilledButton(
          onPressed: hasActivity
              ? () {
                  if (status == TimerStatus.running) {
                    notifier.pause();
                  } else {
                    notifier.start();
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            status == TimerStatus.running ? 'Pausar' : 'Iniciar',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
