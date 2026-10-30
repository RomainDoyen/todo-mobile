import 'package:flutter/material.dart';

import '../src/models.dart';
import '../src/scope.dart';
import '../theme.dart';
import 'task_images.dart';
import 'task_page.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    Task? task;
    for (final item in model.tasks) {
      if (item.id == taskId) {
        task = item;
        break;
      }
    }
    if (task == null) {
      return AppShell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Détail')),
          body: const Center(child: Text('Cette tâche n’est plus là')),
        ),
      );
    }

    final current = task;
    Category? category;
    for (final item in model.categories) {
      if (item.id == current.categoryId) category = item;
    }
    final done = current.status == TaskStatus.done;
    final doneSubs = current.subtasks.where((sub) => sub.done).length;
    final tone = dueTone(current.dueAt);
    final dueColor = switch (tone) {
      DueTone.late => danger,
      DueTone.today => warning,
      _ => null,
    };

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Détail'),
          actions: [
            IconButton(
              tooltip: 'Épingler',
              onPressed: () => model.togglePin(current.id),
              icon: Icon(
                current.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: current.pinned ? accent : muted,
              ),
            ),
            IconButton(
              tooltip: 'Modifier',
              onPressed: () {
                showTaskEditor(context, taskId: current.id);
              },
              icon: const Icon(Icons.edit_outlined, color: muted),
            ),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: () async {
                final confirmed = await confirmDeleteTask(context);
                if (!confirmed || !context.mounted) return;
                final navigator = Navigator.of(context);
                final currentId = current.id;
                navigator.pop();
                await model.deleteTask(currentId);
              },
              icon: const Icon(Icons.delete_outline, color: danger),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
          child: FilledButton.icon(
              onPressed: () {
                showTaskEditor(context, taskId: current.id);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? accentDark : accent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF06241F)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CheckBox(checked: done, onTap: () => model.toggleDone(current.id)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    current.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: -0.3,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? muted : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Panel(
              child: Text(
                (current.description == null || current.description!.isEmpty)
                    ? 'Aucune description'
                    : current.description!,
                style: TextStyle(
                  color: (current.description == null || current.description!.isEmpty) ? muted : null,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Pair(
              left: _InfoTile(
                icon: Icons.signal_cellular_alt,
                label: 'Priorité',
                child: ColorPill(label: priorityLabel(current.priority), color: priorityColor(current.priority)),
              ),
              right: _InfoTile(
                icon: Icons.calendar_today_outlined,
                label: 'Échéance',
                child: Text(
                  current.dueAt == null ? 'Sans date' : formatDueLong(current.dueAt),
                  style: TextStyle(
                    color: dueColor ?? (current.dueAt == null ? muted : null),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _Pair(
              left: _InfoTile(
                icon: Icons.folder_outlined,
                label: 'Catégorie',
                child: category == null
                    ? const Text('Aucune', style: TextStyle(color: muted, fontWeight: FontWeight.w600))
                    : ColorPill(label: category.name, color: colorFromHex(category.color)),
              ),
              right: _InfoTile(
                icon: Icons.sell_outlined,
                label: 'Tags',
                child: current.tags.isEmpty
                    ? const Text('Aucun', style: TextStyle(color: muted, fontWeight: FontWeight.w600))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in current.tags)
                            ColorPill(label: tag.name, color: colorFromHex(tag.color)),
                        ],
                      ),
              ),
            ),
            TaskImageGallery(
              fillWidth: true,
              photos: [
                for (final image in current.images) TaskPhoto(id: image.id, path: image.path),
              ],
              onAdd: () async {
                final paths = await pickTaskImages(context);
                if (paths.isEmpty || !context.mounted) return;
                await model.addTaskImages(current.id, paths);
              },
              onRemove: (photo) => model.removeTaskImage(photo.id),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.checklist, size: 16, color: muted),
                const SizedBox(width: 6),
                const Text('Sous-tâches', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (current.subtasks.isNotEmpty)
                  Text('$doneSubs/${current.subtasks.length}', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            _Panel(
              child: current.subtasks.isEmpty
                  ? const Text('Aucune sous-tâche', style: TextStyle(color: muted, fontWeight: FontWeight.w600))
                  : Column(
                      children: [
                        for (var i = 0; i < current.subtasks.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: hairline(Theme.of(context).brightness)),
                          InkWell(
                            onTap: () => model.toggleSubtask(current.subtasks[i].id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  _CheckBox(
                                    checked: current.subtasks[i].done,
                                    onTap: () => model.toggleSubtask(current.subtasks[i].id),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      current.subtasks[i].title,
                                      style: TextStyle(
                                        decoration: current.subtasks[i].done ? TextDecoration.lineThrough : null,
                                        color: current.subtasks[i].done ? muted : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Stamp(label: 'Créée', value: formatDueLong(current.createdAt))),
                Expanded(
                  child: _Stamp(
                    label: 'Modifiée',
                    value: formatDueLong(current.updatedAt),
                    align: current.completedAt == null ? TextAlign.end : TextAlign.center,
                  ),
                ),
                if (current.completedAt != null)
                  Expanded(
                    child: _Stamp(
                      label: 'Terminée',
                      value: formatDueLong(current.completedAt),
                      align: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardSolid(brightness),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairline(brightness)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.value, this.align = TextAlign.start});

  final String label;
  final String value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: switch (align) {
        TextAlign.end => CrossAxisAlignment.end,
        TextAlign.center => CrossAxisAlignment.center,
        _ => CrossAxisAlignment.start,
      },
      children: [
        Text(label.toUpperCase(), textAlign: align, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, textAlign: align, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, required this.onTap, this.size = 28});

  final bool checked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? const Color(0xFF059669) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? const Color(0xFF059669) : accent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: checked ? Icon(Icons.check, size: size * 0.55, color: Colors.white) : null,
      ),
    );
  }
}

Future<bool> confirmDeleteTask(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer cette tâche ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
      ],
    ),
  );
  return confirmed == true;
}
