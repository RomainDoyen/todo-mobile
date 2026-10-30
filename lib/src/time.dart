import 'models.dart';

/// Millisecond UTC timestamp, same precision as `Date.toISOString()`.
String nowIso([DateTime? value]) {
  final iso = (value ?? DateTime.now()).toUtc().toIso8601String();
  final match = RegExp(r'^(.*T\d{2}:\d{2}:\d{2}\.\d{3})\d*(Z)$').firstMatch(iso);
  if (match != null) return '${match.group(1)}${match.group(2)}';
  return iso;
}

DateTime startOfToday([DateTime? now]) {
  final d = now ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

DateTime endOfToday([DateTime? now]) {
  final d = startOfToday(now);
  return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

/// Sunday-based end of week, matching the extension (`Date.getDay()`).
DateTime endOfWeek([DateTime? now]) {
  final start = startOfToday(now);
  final jsDay = start.weekday % 7;
  final diff = jsDay == 0 ? 0 : 7 - jsDay;
  final end = start.add(Duration(days: diff));
  return DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
}

String dueIsoFromDate(DateTime date) {
  final localNoon = DateTime(date.year, date.month, date.day, 12);
  return nowIso(localNoon);
}

bool isDueBetween(String? iso, DateTime start, DateTime end) {
  if (iso == null || iso.isEmpty) return false;
  final due = DateTime.parse(iso).toLocal();
  return !due.isBefore(start) && !due.isAfter(end);
}

bool matchesFilter(Task task, QuickFilter filter, [DateTime? now]) {
  switch (filter) {
    case QuickFilter.all:
      return true;
    case QuickFilter.urgent:
      return task.priority == TaskPriority.urgent && task.status != TaskStatus.done;
    case QuickFilter.today:
      return isDueBetween(task.dueAt, startOfToday(now), endOfToday(now));
    case QuickFilter.week:
      return isDueBetween(task.dueAt, startOfToday(now), endOfWeek(now));
  }
}

List<Task> filterTasks(
  List<Task> tasks, {
  QuickFilter filter = QuickFilter.all,
  String search = '',
  String? tagId,
  DateTime? now,
}) {
  final query = search.trim().toLowerCase();
  return tasks.where((task) {
    if (!matchesFilter(task, filter, now)) return false;
    if (tagId != null && !task.tags.any((tag) => tag.id == tagId)) return false;
    if (query.isEmpty) return true;
    final description = task.description?.toLowerCase() ?? '';
    return task.title.toLowerCase().contains(query) || description.contains(query);
  }).toList();
}

({int done, int total}) dayProgress(List<Task> tasks, [DateTime? now]) {
  final today = tasks.where(
    (task) => isDueBetween(task.dueAt, startOfToday(now), endOfToday(now)),
  );
  final list = today.toList();
  final done = list.where((task) => task.status == TaskStatus.done).length;
  return (done: done, total: list.length);
}
