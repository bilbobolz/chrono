import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/activities_provider.dart';
import '../providers/free_timer_provider.dart';
import '../providers/timer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/circular_timer.dart';
import '../widgets/activity_time_bar.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(timerModeProvider);
    final activitiesAsync = ref.watch(activitiesProvider);

    return activitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (activities) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Mode toggle
              SegmentedButton<TimerMode>(
                segments: const [
                  ButtonSegment(
                    value: TimerMode.pomodoro,
                    icon: Icon(Icons.timer),
                    label: Text('Pomodoro'),
                  ),
                  ButtonSegment(
                    value: TimerMode.libre,
                    icon: Icon(Icons.play_circle_outline),
                    label: Text('Cronómetro'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    ref.read(timerModeProvider.notifier).state = s.first,
              ),
              const SizedBox(height: 32),

              if (mode == TimerMode.pomodoro)
                _PomodoroSection(activities: activities)
              else
                _FreeTimerSection(activities: activities),
            ],
          ),
        );
      },
    );
  }
}

// ─── Pomodoro ────────────────────────────────────────────────────────────────

class _PomodoroSection extends ConsumerWidget {
  final List<Activity> activities;
  const _PomodoroSection({required this.activities});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    Activity? selected;
    if (timer.activityId != null) {
      try {
        selected = activities.firstWhere((a) => a.id == timer.activityId);
      } catch (_) {}
    }
    final color = selected != null
        ? Color(selected.colorValue)
        : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        _ActivitySelector(
          activities: activities,
          selectedId: timer.activityId,
          enabled: timer.status == TimerStatus.idle,
          onSelect: (act) =>
              ref.read(timerProvider.notifier).selectActivity(act),
        ),
        const SizedBox(height: 40),
        CircularTimer(
          progress: timer.progress,
          remainingSeconds: timer.remainingSeconds,
          color: color,
          isBreak: timer.phase == TimerPhase.breakPhase,
        ),
        const SizedBox(height: 12),
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
        _PomodoroControls(
          status: timer.status,
          hasActivity: timer.activityId != null,
          color: color,
        ),
        const SizedBox(height: 32),
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
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 10),
              const ActivityTimeBar(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PomodoroControls extends ConsumerWidget {
  final TimerStatus status;
  final bool hasActivity;
  final Color color;
  const _PomodoroControls(
      {required this.status,
      required this.hasActivity,
      required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timerProvider.notifier);
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
            padding:
                const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            status == TimerStatus.running ? 'Pausar' : 'Iniciar',
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ─── Cronómetro libre ─────────────────────────────────────────────────────────

class _FreeTimerSection extends ConsumerStatefulWidget {
  final List<Activity> activities;
  const _FreeTimerSection({required this.activities});

  @override
  ConsumerState<_FreeTimerSection> createState() => _FreeTimerSectionState();
}

class _FreeTimerSectionState extends ConsumerState<_FreeTimerSection> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(freeTimerProvider).activityName,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeTimerProvider);
    final notifier = ref.read(freeTimerProvider.notifier);
    final isRunning = state.status == FreeTimerStatus.running;
    final color = state.activityColor;
    final canStart = _nameCtrl.text.trim().isNotEmpty;

    return Column(
      children: [
        // Name field
        TextField(
          controller: _nameCtrl,
          enabled: !isRunning,
          onChanged: (v) {
            setState(() {});
            notifier.setName(v);
          },
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: '¿Qué vas a hacer?',
            hintText: 'Gym, Estudio, Lectura...',
            prefixIcon: const Icon(Icons.edit_note_rounded),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),

        const SizedBox(height: 16),

        // Color picker (hidden while running)
        if (!isRunning)
          Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: AppTheme.activityColors.map((c) {
              final selected = state.activityColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => notifier.setColor(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                state.activityName,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),

        const SizedBox(height: 48),

        // Big elapsed time
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: isRunning ? color : Colors.white38,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Text(_formatElapsed(state.elapsedSeconds)),
        ),

        const SizedBox(height: 6),
        Text(
          isRunning ? 'Registrando...' : 'Listo para iniciar',
          style: TextStyle(
            color: isRunning ? color.withAlpha(180) : Colors.white24,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 48),

        // Start / Stop button
        FilledButton(
          onPressed: (isRunning || canStart)
              ? () {
                  if (isRunning) {
                    notifier.stop();
                  } else {
                    notifier.start();
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: isRunning ? Colors.redAccent : color,
            padding:
                const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isRunning ? 'Detener' : 'Iniciar',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Result card
        if (state.lastSessionSeconds != null) ...[
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded, color: color, size: 36),
                const SizedBox(height: 8),
                Text(
                  '¡Sesión guardada!',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.activityName} · ${formatDuration(state.lastSessionSeconds!)}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Shared widget ────────────────────────────────────────────────────────────

class _ActivitySelector extends StatelessWidget {
  final List<Activity> activities;
  final int? selectedId;
  final bool enabled;
  final ValueChanged<Activity> onSelect;

  const _ActivitySelector({
    required this.activities,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
                        color: Color(a.colorValue), shape: BoxShape.circle),
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
                  onSelect(act);
                }
              : null,
        ),
      ),
    );
  }
}
