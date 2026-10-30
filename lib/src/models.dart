enum TaskStatus { todo, done }

enum TaskPriority { low, medium, high, urgent }

enum QuickFilter { all, today, urgent, week }

enum SyncStatus { synced, pending, offline, error }

enum AppTheme { light, dark }

TaskStatus parseStatus(String value) =>
    value == 'done' ? TaskStatus.done : TaskStatus.todo;

TaskPriority parsePriority(String value) {
  for (final priority in TaskPriority.values) {
    if (priority.name == value) return priority;
  }
  return TaskPriority.medium;
}

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String color;
  final String createdAt;
}

class Category {
  const Category({
    required this.id,
    required this.profileId,
    required this.name,
    required this.color,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String name;
  final String color;
  final String? emoji;
  final String createdAt;
}

class Tag {
  const Tag({
    required this.id,
    required this.profileId,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String name;
  final String color;
  final String createdAt;
}

class Subtask {
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.position,
  });

  final String id;
  final String taskId;
  final String title;
  final bool done;
  final int position;

  Subtask copyWith({String? title, bool? done, int? position}) {
    return Subtask(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      done: done ?? this.done,
      position: position ?? this.position,
    );
  }
}

class Task {
  const Task({
    required this.id,
    required this.profileId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.dueAt,
    required this.categoryId,
    required this.pinned,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.tags,
    required this.subtasks,
    this.images = const [],
  });

  final String id;
  final String profileId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? dueAt;
  final String? categoryId;
  final bool pinned;
  final int position;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final List<Tag> tags;
  final List<Subtask> subtasks;
  final List<TaskImage> images;
}

class TaskImage {
  const TaskImage({
    required this.id,
    required this.taskId,
    required this.path,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String path;
  final String createdAt;
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.dueAt,
    this.categoryId,
    this.pinned = false,
    this.tagIds = const [],
    this.subtasks = const [],
    this.imagePaths = const [],
  });

  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? dueAt;
  final String? categoryId;
  final bool pinned;
  final List<String> tagIds;
  final List<({String title, bool done})> subtasks;
  final List<String> imagePaths;
}

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.updatedAt,
  });

  final String id;
  final String entity;
  final String entityId;
  final String op;
  final Map<String, dynamic> payload;
  final String updatedAt;
}

const tagColors = [
  '#0F766E',
  '#0369A1',
  '#7C3AED',
  '#DB2777',
  '#DC2626',
  '#D97706',
  '#65A30D',
  '#475569',
];

const syncEntities = [
  'profiles',
  'categories',
  'tags',
  'tasks',
  'task_tags',
  'subtasks',
];
