import 'package:flutter/material.dart';

import '../src/app_model.dart';
import '../src/models.dart';
import '../src/scope.dart';
import '../theme.dart';
import 'text_prompt.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? accentDark : accent;
    final onPrimary = dark ? const Color(0xFF06241F) : Colors.white;

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Paramètres'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _Section(
                icon: Icons.person_outline,
                title: 'Compte',
                children: [
                  Text(
                    user?.email.isNotEmpty == true ? user!.email : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 14,
                        color: _syncColor(model.syncStatus),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _syncStatusLabel(model.syncStatus),
                        style: TextStyle(
                          color: _syncColor(model.syncStatus),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Dernière sync : ${_formatLastSync(model.lastSyncAt)}',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (model.syncError != null &&
                      model.syncStatus == SyncStatus.error)
                    Text(
                      model.syncError!,
                      style: const TextStyle(
                        color: danger,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  _PillButton(
                    icon: Icons.sync,
                    label: model.syncing
                        ? 'Synchronisation…'
                        : 'Synchroniser maintenant',
                    filled: true,
                    spinning: model.syncing,
                    onPressed: model.syncing ? null : model.syncNow,
                    background: primary,
                    foreground: onPrimary,
                  ),
                  _PillButton(
                    icon: Icons.logout,
                    label: 'Déconnexion',
                    filled: false,
                    onPressed: model.logout,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.tune,
                title: 'Apparence',
                children: [
                  Row(
                    children: [
                      Icon(
                        model.theme == AppTheme.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          model.theme == AppTheme.dark
                              ? 'Mode sombre'
                              : 'Mode clair',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Switch(
                        value: model.theme == AppTheme.dark,
                        onChanged: (_) => model.toggleTheme(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.notifications_outlined,
                title: 'Rappels',
                children: [
                  InkWell(
                    onTap: () => _pickEveTime(context, model),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'La veille',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Heure du rappel la veille de l’échéance',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            model.eveReminderLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.account_circle_outlined,
                title: 'Profils',
                children: [
                  for (final profile in model.profiles)
                    _ProfileRow(
                      profile: profile,
                      selected: profile.id == model.activeProfileId,
                      onSelect: () => model.selectProfile(profile.id),
                      onDelete: () =>
                          _deleteProfile(context, model, profile.id),
                    ),
                  _PillButton(
                    icon: Icons.add,
                    label: 'Nouveau profil',
                    filled: true,
                    onPressed: () => _createProfile(context, model),
                    background: primary,
                    foreground: onPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.sell_outlined,
                title: 'Tags du profil',
                children: [_TagManager(model: model)],
              ),
              const SizedBox(height: 18),
              const Text(
                'Mes Tâches v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEveTime(BuildContext context, AppModel model) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: model.eveReminderHour,
        minute: model.eveReminderMinute,
      ),
      helpText: 'Heure de la veille',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (picked == null) return;
    await model.setEveReminderTime(picked.hour, picked.minute);
  }

  Color _syncColor(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => const Color(0xFF059669),
      SyncStatus.pending => warning,
      SyncStatus.offline => muted,
      SyncStatus.error => danger,
    };
  }

  String _syncStatusLabel(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => 'Synchronisé',
      SyncStatus.pending => 'En attente',
      SyncStatus.offline => 'Hors ligne',
      SyncStatus.error => 'Erreur',
    };
  }

  String _formatLastSync(String? iso) {
    if (iso == null || iso.isEmpty) return 'Jamais';
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return 'Jamais';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year} $hh:$min';
  }

  Future<void> _createProfile(BuildContext context, AppModel model) async {
    final name = await askText(context, 'Nouveau profil', 'Nom');
    if (name == null || name.isEmpty) return;
    await model.createProfile(
      name,
      tagColors[model.profiles.length % tagColors.length],
    );
  }

  Future<void> _deleteProfile(
    BuildContext context,
    AppModel model,
    String id,
  ) async {
    try {
      await model.deleteProfile(id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is StateError ? error.message : '$error')),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF151E31) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0x14152033),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._spaced(children),
        ],
      ),
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    final spaced = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 8));
      spaced.add(items[i]);
    }
    return spaced;
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
    this.background,
    this.foreground,
    this.spinning = false,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        spinning
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground ?? muted,
                ),
              )
            : Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: muted,
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : const Color(0x33152033),
        ),
      ),
      child: child,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorFromHex(profile.color),
              radius: 7,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                profile.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 16, color: accent),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18, color: danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagManager extends StatefulWidget {
  const _TagManager({required this.model});

  final AppModel model;

  @override
  State<_TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends State<_TagManager> {
  final _name = TextEditingController();
  var _color = tagColors.first;
  String? _editingId;
  final _editName = TextEditingController();
  var _editColor = tagColors.first;

  @override
  void dispose() {
    _name.dispose();
    _editName.dispose();
    super.dispose();
  }

  int _usage(String id) {
    return widget.model.tasks
        .where((task) => task.tags.any((tag) => tag.id == id))
        .length;
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    try {
      await widget.model.createTag(name, _color);
      _name.clear();
      setState(() => _color = tagColors.first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is StateError ? error.message : '$error')),
      );
    }
  }

  Future<void> _saveEdit() async {
    final id = _editingId;
    final name = _editName.text.trim();
    if (id == null || name.isEmpty) return;
    try {
      await widget.model.updateTag(id, name: name, color: _editColor);
      setState(() => _editingId = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is StateError ? error.message : '$error')),
      );
    }
  }

  Future<void> _delete(Tag tag) async {
    final usage = _usage(tag.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          usage > 0
              ? 'Supprimer ce tag ? Il sera retiré de $usage tâche${usage > 1 ? 's' : ''}.'
              : 'Supprimer ce tag ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.model.deleteTag(tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.model.tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Aucun tag pour ce profil.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        for (final tag in tags) ...[
          if (_editingId == tag.id)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _editName,
                  decoration: const InputDecoration(hintText: 'Nom du tag'),
                  onSubmitted: (_) => _saveEdit(),
                ),
                const SizedBox(height: 8),
                _Swatches(
                  selected: _editColor,
                  onPick: (color) => setState(() => _editColor = color),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _saveEdit,
                      icon: const Icon(Icons.check, color: accent),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _editingId = null),
                      icon: const Icon(Icons.close, color: muted),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorFromHex(tag.color),
                  radius: 7,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_usage(tag.id)} tâche${_usage(tag.id) == 1 ? '' : 's'}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _editName.text = tag.name;
                    setState(() {
                      _editingId = tag.id;
                      _editColor = tag.color;
                    });
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16, color: muted),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _delete(tag),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: danger,
                  ),
                ),
              ],
            ),
        ],
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.sell_outlined, size: 12, color: muted),
            SizedBox(width: 6),
            Text(
              'Nouveau tag',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Nom du tag'),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _create, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 8),
        _Swatches(
          selected: _color,
          onPick: (color) => setState(() => _color = color),
        ),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in tagColors)
          GestureDetector(
            onTap: () => onPick(color),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colorFromHex(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toLowerCase() == color.toLowerCase()
                      ? ink
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
