import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'db_provider.dart';

enum StatsPeriod { day, week, month, year }

final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.week);

DateTimeRange _rangeFor(StatsPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case StatsPeriod.day:
      return DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      );
    case StatsPeriod.week:
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return DateTimeRange(
        start: monday,
        end: monday.add(const Duration(days: 7)),
      );
    case StatsPeriod.month:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 1),
      );
    case StatsPeriod.year:
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year + 1, 1, 1),
      );
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}

// Map of activityId -> totalSeconds for the selected period
final statsByActivityProvider =
    FutureProvider<Map<int, int>>((ref) async {
  final period = ref.watch(statsPeriodProvider);
  final db = ref.watch(dbProvider);
  final range = _rangeFor(period);
  return db.getTotalSecondsByActivity(range.start, range.end);
});

final sessionsInPeriodProvider =
    FutureProvider<List<Session>>((ref) async {
  final period = ref.watch(statsPeriodProvider);
  final db = ref.watch(dbProvider);
  final range = _rangeFor(period);
  return db.getSessionsInRange(range.start, range.end);
});
