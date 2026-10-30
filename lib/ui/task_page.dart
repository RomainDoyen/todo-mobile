import 'package:flutter/material.dart';

import '../src/models.dart';
import '../src/scope.dart';
import '../theme.dart';
import '../src/time.dart';
import 'task_images.dart';
import 'text_prompt.dart';

Future<void> showTaskEditor(BuildContext context, {String? taskId}) {
  final brightness = Theme.of(context).brightness;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cardSolid(brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => TaskPage(taskId: taskId),
  );
}

class TaskPage extends StatefulWidget {
  const TaskPage({super.key, this.taskId});

  final String? taskId;

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _newTag = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime? _due;
  String? _categoryId;
  var _pinned = false;
  final _tagIds = <String>{};
  var _subKey = 0;
  final _subtasks = <({int key, String title, bool done})>[];
  final _pendingImages = <String>[];
  var _ready = false;
  var _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final id = widget.taskId;
    if (id != null) {
      final model = AppScope.of(context);
      Task? task;
      for (final item in model.tasks) {
        if (item.id == id) {
          task = item;
          break;
        }
      }
      if (task != null) {
        _title.text = task.title;
        _description.text = task.description ?? '';
        _priority = task.priority;
        _status = task.status;
        _due = task.dueAt == null ? null : DateTime.parse(task.dueAt!).toLocal();
        _categoryId = task.categoryId;
        _pinned = task.pinned;
        _tagIds.addAll(task.tags.map((tag) => tag.id));
        _subtasks.addAll(
          task.subtasks.map((sub) => (key: _subKey++, title: sub.title, done: sub.done)),
        );
      }
    }
    _ready = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    final model = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final draft = TaskDraft(
        title: _title.text,
        description: _description.text,
        status: _status,
        priority: _priority,
        dueAt: _due == null ? null : dueIsoFromDate(_due!),
        categoryId: _categoryId,
        pinned: _pinned,
        tagIds: _tagIds.toList(),
        subtasks: [
          for (final sub in _subtasks)
            if (sub.title.trim().isNotEmpty) (title: sub.title.trim(), done: sub.done),
        ],
        imagePaths: widget.taskId == null ? List.of(_pendingImages) : const [],
      );
      if (widget.taskId == null) {
        await model.createTask(draft);
      } else {
        await model.updateTask(widget.taskId!, draft);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(error is StateError ? error.message : '$error')),
      );
    }
  }

  Future<void> _delete() async {
    final id = widget.taskId;
    if (id == null) return;
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
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    final model = AppScope.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    navigator.pop();
    await model.deleteTask(id);
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final creating = widget.taskId == null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final brightness = Theme.of(context).brightness;
    return Material(
      color: cardSolid(brightness),
      child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    creating ? 'Nouvelle tâche' : 'Modifier',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!creating)
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: danger),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
            TextField(
              controller: _title,
              autofocus: creating,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Titre de la tâche',
                filled: false,
                contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
                border: UnderlineInputBorder(borderSide: BorderSide(color: hairline(brightness))),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: hairline(brightness))),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: brightness == Brightness.dark ? accentDark : accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: fieldDecoration(context, hint: 'Description (optionnel)'),
            ),
            const SizedBox(height: 16),
            const _SectionLabel(icon: Icons.signal_cellular_alt, label: 'Priorité'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final priority in TaskPriority.values)
                  ColorPill(
                    label: priorityLabel(priority),
                    color: priorityColor(priority),
                    filled: _priority == priority,
                    onTap: () => setState(() => _priority = priority),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionLabel(icon: Icons.calendar_today_outlined, label: 'Échéance'),
            InkWell(
              onTap: _pickDue,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: fieldFill(brightness),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hairline(brightness)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _due == null ? 'Sans date' : formatDueLong(dueIsoFromDate(_due!)),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _due == null ? muted : null,
                        ),
                      ),
                    ),
                    if (_due != null)
                      GestureDetector(
                        onTap: () => setState(() => _due = null),
                        child: const Icon(Icons.close, size: 18, color: muted),
                      )
                    else
                      const Icon(Icons.event, size: 18, color: muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel(icon: Icons.folder_outlined, label: 'Catégorie'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in model.categories)
                  ColorPill(
                    label: category.name,
                    color: colorFromHex(category.color),
                    filled: _categoryId == category.id,
                    onTap: () => setState(() {
                      _categoryId = _categoryId == category.id ? null : category.id;
                    }),
                  ),
                ColorPill(
                  label: 'Nouvelle',
                  color: dark ? accentDark : accent,
                  onTap: () => _createCategory(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionLabel(icon: Icons.sell_outlined, label: 'Tags'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in model.tags)
                  ColorPill(
                    label: tag.name,
                    color: colorFromHex(tag.color),
                    filled: _tagIds.contains(tag.id),
                    onTap: () => setState(() {
                      if (!_tagIds.add(tag.id)) _tagIds.remove(tag.id);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTag,
                    decoration: fieldDecoration(context, hint: 'Nouveau tag (Entrée pour ajouter)'),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TaskImageGallery(
              photos: [
                if (widget.taskId != null)
                  for (final image in model.tasks.where((task) => task.id == widget.taskId).expand((task) => task.images))
                    TaskPhoto(id: image.id, path: image.path),
                for (var index = 0; index < _pendingImages.length; index++)
                  TaskPhoto(id: 'pending-$index', path: _pendingImages[index]),
              ],
              onAdd: _addImages,
              onRemove: (photo) async {
                if (photo.id.startsWith('pending-')) {
                  final index = int.tryParse(photo.id.replaceFirst('pending-', ''));
                  if (index == null) return;
                  setState(() => _pendingImages.removeAt(index));
                  return;
                }
                await model.removeTaskImage(photo.id);
              },
            ),
            const SizedBox(height: 16),
            const _SectionLabel(icon: Icons.checklist, label: 'Sous-tâches'),
            for (var index = 0; index < _subtasks.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _subtasks[index].done,
                      onChanged: (value) => setState(() {
                        final current = _subtasks[index];
                        _subtasks[index] = (key: current.key, title: current.title, done: value ?? false);
                      }),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_subtasks[index].key),
                        initialValue: _subtasks[index].title,
                        decoration: fieldDecoration(context, hint: 'Sous-tâche'),
                        onChanged: (value) {
                          final current = _subtasks[index];
                          _subtasks[index] = (key: current.key, title: value, done: current.done);
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _subtasks.removeAt(index)),
                      icon: const Icon(Icons.close, size: 18, color: muted),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: ColorPill(
                label: 'Sous-tâche',
                color: dark ? accentDark : accent,
                onTap: () => setState(() => _subtasks.add((key: _subKey++, title: '', done: false))),
              ),
            ),
          ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + screenBottomInset(context)),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: Icon(creating ? Icons.check : Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Enregistrement…' : (creating ? 'Créer la tâche' : 'Enregistrer')),
              style: FilledButton.styleFrom(
                backgroundColor: dark ? accentDark : accent,
                foregroundColor: dark ? const Color(0xFF06241F) : Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _addImages() async {
    final paths = await pickTaskImages(context);
    if (paths.isEmpty || !mounted) return;
    final id = widget.taskId;
    if (id == null) {
      setState(() => _pendingImages.addAll(paths));
      return;
    }
    await AppScope.of(context).addTaskImages(id, paths);
  }

  Future<void> _addTag() async {
    final name = _newTag.text.trim();
    if (name.isEmpty) return;
    await AppScope.of(context).createTag(name, '#0F766E');
    if (!mounted) return;
    final model = AppScope.of(context);
    Tag? created;
    for (final tag in model.tags) {
      if (tag.name == name) created = tag;
    }
    setState(() {
      if (created != null) _tagIds.add(created.id);
      _newTag.clear();
    });
  }

  Future<void> _createCategory(BuildContext context) async {
    final created = await askText(context, 'Catégorie', 'Nom');
    if (created == null || created.isEmpty || !context.mounted) return;
    final category = await AppScope.of(context).createCategory(created, '#0369A1');
    if (mounted) setState(() => _categoryId = category.id);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
