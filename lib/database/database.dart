import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get workMinutes => integer().withDefault(const Constant(25))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer().references(Activities, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
  TextColumn get sessionType => text()(); // 'work' or 'break'
}

@DriftDatabase(tables: [Activities, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Activities
  Stream<List<Activity>> watchAllActivities() =>
      select(activities).watch();

  Future<List<Activity>> getAllActivities() =>
      select(activities).get();

  Future<int> insertActivity(ActivitiesCompanion entry) =>
      into(activities).insert(entry);

  Future<bool> updateActivity(Activity entry) =>
      update(activities).replace(entry);

  Future<int> deleteActivity(int id) =>
      (delete(activities)..where((t) => t.id.equals(id))).go();

  // Sessions
  Future<int> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry);

  Future<List<Session>> getSessionsInRange(DateTime from, DateTime to) {
    return (select(sessions)
          ..where((s) => s.startedAt.isBetweenValues(from, to)))
        .get();
  }

  Stream<List<Session>> watchSessionsInRange(DateTime from, DateTime to) {
    return (select(sessions)
          ..where((s) => s.startedAt.isBetweenValues(from, to)))
        .watch();
  }

  Future<Map<int, int>> getTotalSecondsByActivity(
      DateTime from, DateTime to) async {
    final rows = await getSessionsInRange(from, to);
    final map = <int, int>{};
    for (final s in rows) {
      if (s.sessionType == 'work') {
        map[s.activityId] = (map[s.activityId] ?? 0) + s.durationSeconds;
      }
    }
    return map;
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'chrono',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
