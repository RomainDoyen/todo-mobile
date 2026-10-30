import 'package:flutter/material.dart';

import '../src/app_model.dart';
import '../src/models.dart';
import '../src/scope.dart';
import '../src/time.dart';
import '../theme.dart';
import 'notched_tab_bar.dart';
import 'settings_page.dart';
import 'task_detail_page.dart';
import 'task_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _taskPageSize = 3;

int _pageCount(int count) =>
    count == 0 ? 1 : ((count + _taskPageSize - 1) ~/ _taskPageSize);

List<Task> _pageOf(List<Task> tasks, int page) {
  if (tasks.isEmpty) return const [];
  final safe = page.clamp(0, _pageCount(tasks.length) - 1);
  final start = safe * _taskPageSize;
  final end = start + _taskPageSize > tasks.length
      ? tasks.length
      : start + _taskPageSize;
  return tasks.sublist(start, end);
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _homePage = 0;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final progress = model.today;
    final ratio = progress.total == 0 ? 0.0 : progress.done / progress.total;

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(
                    profileName: model.activeProfile?.name ?? 'Profil',
                    profileColor: model.activeProfile?.color ?? '#0F766E',
                    activeCount: model.openCount,
                    progress: ratio,
                    syncing: model.syncing,
                    syncIcon: _syncIcon(model.syncStatus),
                    syncColor: _syncColor(model),
                    onSync: model.syncing ? null : model.syncNow,
                    onProfiles: () => _showProfiles(context, model),
                    onSettings: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  if (model.pendingAuth)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Serveur indisponible. Identifiants enregistrés sur l’appareil, synchronisation dès qu’il répond.',
                        style: TextStyle(color: muted, fontSize: 12.5),
                      ),
                    ),
                  if (_tab == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher une tâche...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF151E31)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: hairline(Theme.of(context).brightness),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: hairline(Theme.of(context).brightness),
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _homePage = 0);
                              model.setSearch(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter in QuickFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _FilterPill(
                                      label: filterLabel(filter),
                                      selected: model.filter == filter,
                                      onTap: () {
                                        setState(() => _homePage = 0);
                                        model.setFilter(filter);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (model.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final tag in model.tags)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _FilterPill(
                                        label: tag.name,
                                        color: colorFromHex(tag.color),
                                        selected: model.selectedTagId == tag.id,
                                        onTap: () {
                                          setState(() => _homePage = 0);
                                          model.setSelectedTag(tag.id);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Expanded(child: _tabBody(model)),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: NotchedTabBar(
                  index: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                  onCreate: () => showTaskEditor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody(AppModel model) {
    switch (_tab) {
      case 1:
        return const _CalendarBody();
      case 2:
        return const _StatsBody();
      case 3:
        return _ProfileBody(
          onSettings: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
          },
          onProfiles: () => _showProfiles(context, model),
        );
      default:
        final tasks = model.visibleTasks;
        if (tasks.isEmpty) {
          return const Center(child: Text('Aucune tâche pour ce filtre'));
        }
        final pages = _pageCount(tasks.length);
        final page = _homePage.clamp(0, pages - 1);
        final slice = _pageOf(tasks, page);
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                key: ValueKey('home-$page'),
                padding: EdgeInsets.fromLTRB(16, 8, 16, pages > 1 ? 12 : 128),
                itemCount: slice.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _TaskCard(task: slice[index]),
              ),
            ),
            if (pages > 1)
              _TaskPager(
                page: page,
                pages: pages,
                onPage: (next) => setState(() => _homePage = next),
              ),
          ],
        );
    }
  }

  IconData _syncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      case SyncStatus.pending:
        return Icons.cloud_upload_outlined;
      case SyncStatus.offline:
        return Icons.cloud_off_outlined;
      case SyncStatus.error:
        return Icons.cloud_off;
    }
  }

  Color? _syncColor(AppModel model) {
    if (model.syncStatus == SyncStatus.error) return danger;
    if (model.syncing) return accent;
    return null;
  }

  Future<void> _showProfiles(BuildContext context, AppModel model) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: screenBottomInset(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final profile in model.profiles)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorFromHex(profile.color),
                    radius: 8,
                  ),
                  title: Text(profile.name),
                  trailing: profile.id == model.activeProfileId
                      ? const Icon(Icons.check, color: accent)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    model.selectProfile(profile.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final done = task.status == TaskStatus.done;
    final due = formatDue(task.dueAt);
    final tone = dueTone(task.dueAt);
    final doneSubs = task.subtasks.where((sub) => sub.done).length;

    return Opacity(
      opacity: done ? 0.62 : 1,
      child: Material(
        color: done
            ? const Color(0xFF059669).withValues(alpha: dark ? 0.16 : 0.08)
            : (dark ? const Color(0xFF151E31) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: dark ? Colors.white12 : const Color(0x14152033),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 42,
                color: priorityColor(task.priority),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => model.toggleDone(task.id),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFF059669) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: done
                          ? const Color(0xFF059669)
                          : accent.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailPage(taskId: task.id),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (task.pinned) ...[
                            const Icon(Icons.push_pin, size: 13, color: accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final tag in task.tags)
                            ColorPill(
                              label: tag.name,
                              color: colorFromHex(tag.color),
                            ),
                          if (due.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 12,
                                  color: tone == DueTone.late
                                      ? danger
                                      : tone == DueTone.today
                                      ? warning
                                      : muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  due,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tone == DueTone.late
                                        ? danger
                                        : tone == DueTone.today
                                        ? warning
                                        : muted,
                                  ),
                                ),
                              ],
                            ),
                          if (task.images.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  size: 12,
                                  color: muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${task.images.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          if (task.subtasks.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.checklist,
                                  size: 12,
                                  color: muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$doneSubs/${task.subtasks.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  _CardAction(
                    icon: Icons.push_pin_outlined,
                    active: task.pinned,
                    onTap: () => model.togglePin(task.id),
                  ),
                  _CardAction(
                    icon: Icons.edit_outlined,
                    onTap: () => showTaskEditor(context, taskId: task.id),
                  ),
                  _CardAction(
                    icon: Icons.delete_outline,
                    danger: true,
                    onTap: () async {
                      final confirmed = await confirmDeleteTask(context);
                      if (confirmed) await model.deleteTask(task.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE11D48) : (active ? accent : muted);
    return SizedBox(
      width: 32,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profileName,
    required this.profileColor,
    required this.activeCount,
    required this.progress,
    required this.syncing,
    required this.syncIcon,
    required this.syncColor,
    required this.onSync,
    required this.onProfiles,
    required this.onSettings,
  });

  final String profileName;
  final String profileColor;
  final int activeCount;
  final double progress;
  final bool syncing;
  final IconData syncIcon;
  final Color? syncColor;
  final VoidCallback? onSync;
  final VoidCallback onProfiles;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pct = (progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xCC121A2B) : const Color(0xB8FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dark ? Colors.white12 : const Color(0x14152033),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Image(
                    image: AssetImage('assets/icon/app_icon_rounded.png'),
                    width: 34,
                    height: 34,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mes Tâches',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        profileName,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: dark ? accentDark : accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount',
                    style: TextStyle(
                      color: dark ? const Color(0xFF06241F) : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Synchroniser',
                  onPressed: onSync,
                  icon: Icon(
                    syncing ? Icons.sync : syncIcon,
                    color: syncColor,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Profils',
                  onPressed: onProfiles,
                  icon: CircleAvatar(
                    radius: 12,
                    backgroundColor: colorFromHex(profileColor),
                    child: Text(
                      profileName.isEmpty
                          ? '?'
                          : profileName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Réglages',
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Jour',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      color: dark ? accentDark : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? (dark
                ? accentDark.withValues(alpha: 0.18)
                : accent.withValues(alpha: 0.12))
          : (dark ? const Color(0xFF151E31) : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                CircleAvatar(backgroundColor: color, radius: 4),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? (dark ? accentDark : accent) : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody();

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  late DateTime _month;
  late DateTime _day;
  bool _undated = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final today = startOfToday();
    _month = DateTime(today.year, today.month);
    _day = today;
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final today = startOfToday();
    setState(() {
      _month = next;
      _undated = false;
      _page = 0;
      _day = today.year == next.year && today.month == next.month
          ? today
          : DateTime(next.year, next.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = AppScope.of(context).tasks;
    final byDay = <DateTime, List<Task>>{};
    final undated = <Task>[];
    for (final task in tasks) {
      final day = _taskDay(task);
      if (day == null) {
        undated.add(task);
      } else {
        byDay.putIfAbsent(day, () => []).add(task);
      }
    }
    final selected = _undated ? undated : (byDay[_day] ?? const <Task>[]);
    final pages = _pageCount(selected.length);
    final page = selected.isEmpty ? 0 : _page.clamp(0, pages - 1);
    final slice = _pageOf(selected, page);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? accentDark : accent;

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(
              'calendar-${_month.year}-${_month.month}-$page-$_undated',
            ),
            padding: EdgeInsets.fromLTRB(16, 8, 16, pages > 1 ? 12 : 128),
            children: [
              _MonthCard(
                month: _month,
                selected: _undated ? null : _day,
                marked: byDay.keys.toSet(),
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onSelect: (day) => setState(() {
                  _day = day;
                  _undated = false;
                  _page = 0;
                }),
              ),
              if (undated.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _undated = true;
                      _page = 0;
                    }),
                    child: Text(
                      'Sans date (${undated.length})',
                      style: TextStyle(
                        color: _undated ? primary : muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Text(
                  _undated ? 'Sans date' : _dayLabel(_day, startOfToday()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (slice.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucune tâche ce jour',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                )
              else
                for (final task in slice) ...[
                  _TaskCard(task: task),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
        if (pages > 1)
          _TaskPager(
            page: page,
            pages: pages,
            onPage: (next) => setState(() => _page = next),
          ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selected,
    required this.marked,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime? selected;
  final Set<DateTime> marked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final primary = dark ? accentDark : accent;
    final onPrimary = dark ? const Color(0xFF06241F) : Colors.white;
    final today = startOfToday();
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month).weekday - 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardSolid(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline(brightness)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: onPrevious,
                  icon: Icon(Icons.chevron_left, color: primary),
                ),
                Expanded(
                  child: Text(
                    _monthTitle(month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: onNext,
                  icon: Icon(Icons.chevron_right, color: primary),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                for (var index = 0; index < leading; index++)
                  const SizedBox.shrink(),
                for (var day = 1; day <= days; day++)
                  _DayCell(
                    day: DateTime(month.year, month.month, day),
                    selected:
                        selected != null &&
                        selected!.year == month.year &&
                        selected!.month == month.month &&
                        selected!.day == day,
                    today:
                        today.year == month.year &&
                        today.month == month.month &&
                        today.day == day,
                    marked: marked.contains(
                      DateTime(month.year, month.month, day),
                    ),
                    primary: primary,
                    onPrimary: onPrimary,
                    onTap: () =>
                        onSelect(DateTime(month.year, month.month, day)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.marked,
    required this.primary,
    required this.onPrimary,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool marked;
  final Color primary;
  final Color onPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              shape: BoxShape.circle,
              border: today && !selected
                  ? Border.all(color: primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? onPrimary : null,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: marked
                  ? (selected ? onPrimary : primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _monthTitle(DateTime month) {
  final name = _monthNames[month.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
}

class _TaskPager extends StatelessWidget {
  const _TaskPager({
    required this.page,
    required this.pages,
    required this.onPage,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? accentDark : accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: page == 0 ? null : () => onPage(page - 1),
            icon: Icon(Icons.chevron_left, color: page == 0 ? muted : color),
          ),
          Text(
            'Page ${page + 1} sur $pages',
            style: const TextStyle(fontWeight: FontWeight.w700, color: muted),
          ),
          IconButton(
            tooltip: 'Page suivante',
            onPressed: page >= pages - 1 ? null : () => onPage(page + 1),
            icon: Icon(
              Icons.chevron_right,
              color: page >= pages - 1 ? muted : color,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _taskDay(Task task) {
  final iso = task.dueAt;
  if (iso == null || iso.isEmpty) return null;
  final local = DateTime.parse(iso).toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _dayLabel(DateTime day, DateTime today) {
  final date = DateTime(day.year, day.month, day.day);
  if (date == today) return "Aujourd'hui";
  if (date == today.add(const Duration(days: 1))) return 'Demain';
  if (date == today.subtract(const Duration(days: 1))) return 'Hier';
  return formatDueLong(dueIsoFromDate(date));
}

class _StatsBody extends StatelessWidget {
  const _StatsBody();

  @override
  Widget build(BuildContext context) {
    final tasks = AppScope.of(context).tasks;
    final open = tasks.where((task) => task.status == TaskStatus.todo).length;
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final late = tasks
        .where(
          (task) =>
              task.status == TaskStatus.todo &&
              dueTone(task.dueAt) == DueTone.late,
        )
        .length;
    final urgent = tasks
        .where(
          (task) =>
              task.status == TaskStatus.todo &&
              task.priority == TaskPriority.urgent,
        )
        .length;
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _StatCard(label: 'Ouvertes', value: '$open', color: accent),
        _StatCard(
          label: 'Terminées',
          value: '$done',
          color: const Color(0xFF059669),
        ),
        _StatCard(label: 'En retard', value: '$late', color: danger),
        _StatCard(label: 'Urgentes', value: '$urgent', color: warning),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardSolid(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline(brightness)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.onSettings, required this.onProfiles});

  final VoidCallback onSettings;
  final VoidCallback onProfiles;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = model.activeProfile?.name ?? 'Profil';
    final email = model.user?.email ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardSolid(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hairline(Theme.of(context).brightness)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorFromHex(
                    model.activeProfile?.color ?? '#0F766E',
                  ),
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Paramètres'),
          style: FilledButton.styleFrom(
            backgroundColor: dark ? accentDark : accent,
            foregroundColor: dark ? const Color(0xFF06241F) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onProfiles,
          icon: const Icon(Icons.switch_account_outlined, size: 18),
          label: const Text('Changer de profil'),
          style: OutlinedButton.styleFrom(
            foregroundColor: dark ? accentDark : accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
            side: BorderSide(color: dark ? accentDark : accent),
          ),
        ),
      ],
    );
  }
}
