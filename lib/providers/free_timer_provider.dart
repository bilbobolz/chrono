import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/sound_service.dart';
import 'db_provider.dart';

enum FreeTimerStatus { idle, running }

class FreeTimerState {
  final int? activityId;
  final FreeTimerStatus status;
  final int elapsedSeconds;
  final DateTime? sessionStart;
  final int? lastSessionSeconds;

  const FreeTimerState({
    this.activityId,
    this.status = FreeTimerStatus.idle,
    this.elapsedSeconds = 0,
    this.sessionStart,
    this.lastSessionSeconds,
  });

  FreeTimerState copyWith({
    int? activityId,
    FreeTimerStatus? status,
    int? elapsedSeconds,
    DateTime? sessionStart,
    int? lastSessionSeconds,
  }) {
    return FreeTimerState(
      activityId: activityId ?? this.activityId,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      sessionStart: sessionStart ?? this.sessionStart,
      lastSessionSeconds: lastSessionSeconds ?? this.lastSessionSeconds,
    );
  }
}

class FreeTimerNotifier extends StateNotifier<FreeTimerState> {
  final Ref _ref;
  Timer? _ticker;

  FreeTimerNotifier(this._ref) : super(const FreeTimerState());

  AppDatabase get _db => _ref.read(dbProvider);

  void selectActivity(Activity activity) {
    if (state.status == FreeTimerStatus.running) return;
    state = FreeTimerState(activityId: activity.id);
  }

  void start() {
    if (state.activityId == null || state.status == FreeTimerStatus.running) return;
    state = state.copyWith(
      status: FreeTimerStatus.running,
      sessionStart: DateTime.now(),
      elapsedSeconds: 0,
      lastSessionSeconds: null,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  Future<void> stop() async {
    _ticker?.cancel();
    if (state.sessionStart == null ||
        state.activityId == null ||
        state.elapsedSeconds < 5) {
      state = FreeTimerState(activityId: state.activityId);
      return;
    }
    final now = DateTime.now();
    final elapsed = state.elapsedSeconds;
    await _db.insertSession(SessionsCompanion.insert(
      activityId: state.activityId!,
      startedAt: state.sessionStart!,
      endedAt: now,
      durationSeconds: elapsed,
      sessionType: 'work',
    ));
    playCompletionSound();
    state = FreeTimerState(
      activityId: state.activityId,
      lastSessionSeconds: elapsed,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final freeTimerProvider =
    StateNotifierProvider<FreeTimerNotifier, FreeTimerState>((ref) {
  return FreeTimerNotifier(ref);
});
