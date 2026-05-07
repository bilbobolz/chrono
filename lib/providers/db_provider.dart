import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
