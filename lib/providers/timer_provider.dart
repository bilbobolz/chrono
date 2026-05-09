import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/sound_service.dart';
import 'db_provider.dart';

enum TimerPhase { work, breakPhase }

enum TimerStatus { idle, running, paused }

enum TimerMode { pomodoro, libre }

final timerModeProvider = StateProvider<TimerMode>((ref) => TimerMode.pomodoro);

class TimerState {
  final int? activityId;
  final TimerPhase phase;
  final TimerStatus status;
  final int remainingSeconds;
  final int totalSeconds;
  final int completedPomodoros;
  final DateTime? sessionStart;

  const TimerState({
    this.activityId,
    this.phase = TimerPhase.work,
    this.status = TimerStatus.idle,
    this.remainingSeconds = 0,
    this.totalSeconds = 1,
    this.completedPomodoros = 0,
    this.sessionStart,
  });

  double get progress =>
      totalSeconds > 0 ? 1 - (remainingSeconds / totalSeconds) : 0;

  TimerState copyWith({
    int? activityId,
    TimerPhase? phase,
    TimerStatus? status,
    int? remainingSeconds,
    int? totalSeconds,
    int? completedPomodoros,
    DateTime? sessionStart,
  }) {
    return TimerState(
      activityId: activityId ?? this.activityId,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      sessionStart: sessionStart ?? this.sessionStart,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  final Ref _ref;
  Timer? _ticker;
  int _workMinutes = 25;
  int _breakMinutes = 5;

  TimerNotifier(this._ref) : super(const TimerState());

  AppDatabase get _db => _ref.read(dbProvider);

  void selectActivity(Activity activity) {
    _stop(save: false);
    _workMinutes = activity.workMinutes;
    _breakMinutes = activity.breakMinutes;
    state = TimerState(
      activityId: activity.id,
      phase: TimerPhase.work,
      status: TimerStatus.idle,
      remainingSeconds: activity.workMinutes * 60,
      totalSeconds: activity.workMinutes * 60,
      completedPomodoros: 0,
    );
  }

  void start() {
    if (state.activityId == null) return;
    if (state.status == TimerStatus.running) return;

    final sessionStart =
        state.sessionStart ?? DateTime.now();

    state = state.copyWith(
      status: TimerStatus.running,
      sessionStart: sessionStart,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (state.status != TimerStatus.running) return;
    _ticker?.cancel();
    state = state.copyWith(status: TimerStatus.paused);
  }

  void resume() => start();

  Future<void> stop() => _stop(save: true);

  Future<void> _stop({required bool save}) async {
    _ticker?.cancel();
    if (save && state.sessionStart != null && state.activityId != null) {
      final now = DateTime.now();
      final elapsed = now.difference(state.sessionStart!).inSeconds;
      if (elapsed > 5) {
        await _saveSession(elapsed, now);
      }
    }
    if (state.activityId != null) {
      state = TimerState(
        activityId: state.activityId,
        phase: TimerPhase.work,
        status: TimerStatus.idle,
        remainingSeconds: _workMinutes * 60,
        totalSeconds: _workMinutes * 60,
        completedPomodoros: state.completedPomodoros,
      );
    } else {
      state = const TimerState();
    }
  }

  Future<void> _tick() async {
    if (state.remainingSeconds <= 1) {
      _ticker?.cancel();
      final now = DateTime.now();
      final elapsed = state.totalSeconds;
      await _saveSession(elapsed, now);
      playCompletionSound();

      if (state.phase == TimerPhase.work) {
        final pomodoros = state.completedPomodoros + 1;
        final breakSecs = _breakMinutes * 60;
        state = TimerState(
          activityId: state.activityId,
          phase: TimerPhase.breakPhase,
          status: TimerStatus.idle,
          remainingSeconds: breakSecs,
          totalSeconds: breakSecs,
          completedPomodoros: pomodoros,
        );
      } else {
        final workSecs = _workMinutes * 60;
        state = TimerState(
          activityId: state.activityId,
          phase: TimerPhase.work,
          status: TimerStatus.idle,
          remainingSeconds: workSecs,
          totalSeconds: workSecs,
          completedPomodoros: state.completedPomodoros,
        );
      }
      return;
    }
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds - 1,
    );
  }

  Future<void> _saveSession(int durationSeconds, DateTime endedAt) async {
    if (state.activityId == null || state.sessionStart == null) return;
    await _db.insertSession(SessionsCompanion.insert(
      activityId: state.activityId!,
      startedAt: state.sessionStart!,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      sessionType: state.phase == TimerPhase.work ? 'work' : 'break',
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref);
});
