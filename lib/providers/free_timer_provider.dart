import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/sound_service.dart';
import 'db_provider.dart';

enum FreeTimerStatus { idle, running }

class FreeTimerState {
  final int? activityId;
  final String activityName;
  final Color activityColor;
  final FreeTimerStatus status;
  final int elapsedSeconds;
  final DateTime? sessionStart;
  final int? lastSessionSeconds;

  const FreeTimerState({
    this.activityId,
    this.activityName = '',
    this.activityColor = const Color(0xFFE05A3A),
    this.status = FreeTimerStatus.idle,
    this.elapsedSeconds = 0,
    this.sessionStart,
    this.lastSessionSeconds,
  });
}

class FreeTimerNotifier extends StateNotifier<FreeTimerState> {
  final Ref _ref;
  Timer? _ticker;

  FreeTimerNotifier(this._ref) : super(const FreeTimerState());

  AppDatabase get _db => _ref.read(dbProvider);

  void setName(String name) {
    if (state.status == FreeTimerStatus.running) return;
    state = FreeTimerState(
      activityName: name,
      activityColor: state.activityColor,
      lastSessionSeconds: state.lastSessionSeconds,
    );
  }

  void setColor(Color color) {
    if (state.status == FreeTimerStatus.running) return;
    state = FreeTimerState(
      activityName: state.activityName,
      activityColor: color,
      lastSessionSeconds: state.lastSessionSeconds,
    );
  }

  Future<void> start() async {
    final name = state.activityName.trim();
    if (name.isEmpty || state.status == FreeTimerStatus.running) return;

    // Find existing activity or create new one
    final activities = await _db.getAllActivities();
    Activity? existing;
    try {
      existing = activities.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {}

    int activityId;
    if (existing != null) {
      activityId = existing.id;
    } else {
      activityId = await _db.insertActivity(ActivitiesCompanion.insert(
        name: name,
        colorValue: state.activityColor.toARGB32(),
      ));
    }

    state = FreeTimerState(
      activityId: activityId,
      activityName: name,
      activityColor: state.activityColor,
      status: FreeTimerStatus.running,
      sessionStart: DateTime.now(),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = FreeTimerState(
        activityId: state.activityId,
        activityName: state.activityName,
        activityColor: state.activityColor,
        status: state.status,
        elapsedSeconds: state.elapsedSeconds + 1,
        sessionStart: state.sessionStart,
      );
    });
  }

  Future<void> stop() async {
    _ticker?.cancel();
    if (state.sessionStart == null ||
        state.activityId == null ||
        state.elapsedSeconds < 5) {
      state = FreeTimerState(
        activityName: state.activityName,
        activityColor: state.activityColor,
      );
      return;
    }
    final elapsed = state.elapsedSeconds;
    await _db.insertSession(SessionsCompanion.insert(
      activityId: state.activityId!,
      startedAt: state.sessionStart!,
      endedAt: DateTime.now(),
      durationSeconds: elapsed,
      sessionType: 'work',
    ));
    playCompletionSound();
    state = FreeTimerState(
      activityName: state.activityName,
      activityColor: state.activityColor,
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
