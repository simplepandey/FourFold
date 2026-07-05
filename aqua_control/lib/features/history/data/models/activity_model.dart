import 'package:equatable/equatable.dart';

enum ActivityType { autoOn, autoOff, manualOn, manualOff, scheduleOn, alert }

class ActivityModel extends Equatable {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final Duration? duration;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.duration,
  });

  static List<ActivityModel> get mockList => [
        ActivityModel(
          id: '1',
          type: ActivityType.autoOff,
          title: 'Auto — Motor OFF',
          description: 'Tank reached 90% threshold',
          timestamp: DateTime(2026, 5, 7, 17, 31),
          duration: const Duration(hours: 1, minutes: 24),
        ),
        ActivityModel(
          id: '2',
          type: ActivityType.autoOn,
          title: 'Auto — Motor ON',
          description: 'Tank dropped below 20%',
          timestamp: DateTime(2026, 5, 7, 16, 7),
        ),
        ActivityModel(
          id: '3',
          type: ActivityType.alert,
          title: 'Low Underground Tank',
          description: 'Dropped to 15% — alert sent',
          timestamp: DateTime(2026, 5, 7, 15, 52),
        ),
        ActivityModel(
          id: '4',
          type: ActivityType.manualOff,
          title: 'Manual — Motor OFF',
          description: 'By Navin Bind',
          timestamp: DateTime(2026, 5, 7, 11, 30),
          duration: const Duration(minutes: 42),
        ),
        ActivityModel(
          id: '5',
          type: ActivityType.manualOn,
          title: 'Manual — Motor ON',
          description: 'By Navin Bind',
          timestamp: DateTime(2026, 5, 7, 10, 48),
        ),
        ActivityModel(
          id: '6',
          type: ActivityType.scheduleOn,
          title: 'Schedule — Motor ON',
          description: 'Daily 6AM schedule',
          timestamp: DateTime(2026, 5, 6, 6, 0),
          duration: const Duration(hours: 2, minutes: 15),
        ),
      ];

  @override
  List<Object?> get props => [id];
}
