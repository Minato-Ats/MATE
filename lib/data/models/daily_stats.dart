import 'package:flutter/foundation.dart';

/// A single day's worth of MATE activity.
///
/// All figures are framed positively: [temptationsWon] counts the number of
/// times the user chose "やめる" instead of opening a guarded app.
@immutable
class DailyStats {
  const DailyStats({
    required this.date,
    required this.temptationsWon,
    required this.launchAttempts,
    required this.minutesSaved,
  });

  final DateTime date;
  final int temptationsWon;
  final int launchAttempts;
  final int minutesSaved;

  /// Win rate as a 0.0-1.0 fraction. Guarded against divide-by-zero on days
  /// with no recorded attempts yet.
  double get winRate => launchAttempts == 0 ? 0 : temptationsWon / launchAttempts;
}
