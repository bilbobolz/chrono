import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'db_provider.dart';

final activitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(dbProvider).watchAllActivities();
});

final activitiesNotifierProvider =
    NotifierProvider<ActivitiesNotifier, void>(ActivitiesNotifier.new);

class ActivitiesNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(dbProvider);

  Future<void> add({
    required String name,
    required Color color,
    required int workMinutes,
    required int breakMinutes,
  }) async {
    await _db.insertActivity(ActivitiesCompanion.insert(
      name: name,
      colorValue: color.toARGB32(),
      workMinutes: Value(workMinutes),
      breakMinutes: Value(breakMinutes),
    ));
  }

  Future<void> update(Activity activity) async {
    await _db.updateActivity(activity);
  }

  Future<void> delete(int id) async {
    await _db.deleteActivity(id);
  }
}
