
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/event_model.dart';
import '../presenters/event_presenter.dart';
import 'add_event_sheet.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
      ),
      child: const _EventsView(),
    );
  }
}

class _EventsView extends StatefulWidget {
  const _EventsView();

  @override
  State<_EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<_EventsView> {
  late final EventsPresenter _presenter = EventsPresenter();

  final _searchCtrl = TextEditingController();

  CalendarFormat _format = CalendarFormat.month;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _presenter.dispose();
    super.dispose();
  }

  // Show error messages
  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $error'),
        ),
      );
  }

  // Add event
  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<Event>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddEventSheet(
        initialDate: _presenter.selectedDay,
      ),
    );

    if (result == null) return;

    try {
      await _presenter.addEvent(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Event added'),
          ),
        );
    } catch (e) {
      _showError(e);
    }
  }

  // Delete event
  Future<void> _delete(Event event) async {
    try {
      await _presenter.deleteEvent(event);
    } catch (e) {
      _showError(e);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${event.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _presenter.restoreEvent(event).catchError(_showError);
            },
          ),
        ),
      );
  }

  // Show event details
  void _showDetails(Event event) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(
                avatar: Icon(event.category.icon, size: 18),
                label: Text(event.category.label),
              ),

              const SizedBox(height: 8),

              Text(
                event.title,
                style: text.headlineSmall,
              ),

              const SizedBox(height: 12),

              _InfoRow(
                icon: Icons.calendar_today,
                text: DateFormat.yMMMMEEEEd().format(event.date),
              ),

              _InfoRow(
                icon: Icons.schedule,
                text: DateFormat.jm().format(event.date),
              ),

              if (event.location.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  text: event.location,
                ),

              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.description,
                  style: text.bodyMedium,
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _delete(event);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete event'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Get events for a selected day
  List<Event> _eventsOn(List<Event> all, DateTime day) {
    return all.where((e) => isSameDay(e.date, day)).toList();
  }

  // Display day labels
  String _dayLabel(DateTime date) {
    final now = DateTime.now();

    if (isSameDay(date, now)) return 'Today';

    if (isSameDay(
      date,
      now.add(const Duration(days: 1)),
    )) {
      return 'Tomorrow';
    }

    return DateFormat.MMMEd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _presenter,
      builder: (context, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            ),

            body: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Browse'),
                    Tab(text: 'Calendar'),
                  ],
                ),

                Expanded(
                  child: StreamBuilder<List<Event>>(
                    stream: _presenter.eventsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              "Couldn't load events. "
                              "Check your connection and Firestore rules.\n\n"
                              "${snapshot.error}",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final all = snapshot.data!;

                      return TabBarView(
                        children: [
                          _buildBrowse(all),
                          _buildCalendar(all),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Browse tab
  Widget _buildBrowse(List<Event> all) {
    final now = DateTime.now();

    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final query = _presenter.searchQuery.trim().toLowerCase();

    final upcoming = all
        .where((e) => !e.date.isBefore(startOfToday))
        .where(
          (e) =>
              _presenter.selectedCategory == null ||
              e.category == _presenter.selectedCategory,
        )
        .where(
          (e) =>
              query.isEmpty ||
              e.title.toLowerCase().contains(query) ||
              e.location.toLowerCase().contains(query),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final items = <Object>[];

    DateTime? last;

    for (final event in upcoming) {
      if (last == null || !isSameDay(last, event.date)) {
        items.add(event.date);
        last = event.date;
      }

      items.add(event);
    }

    final filtering =
        query.isNotEmpty || _presenter.selectedCategory != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _presenter.searchEvents,
            decoration: InputDecoration(
              hintText: 'Search events or places',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _presenter.searchEvents('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
              ),
            ),
          ),
        ),

        // Category filters
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _presenter.selectedCategory == null,
                  onSelected: (_) {
                    _presenter.filterEvents(null);
                  },
                ),
              ),

              for (final category in EventCategory.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: Icon(category.icon, size: 18),
                    label: Text(category.label),
                    selected:
                        _presenter.selectedCategory == category,
                    onSelected: (_) {
                      _presenter.filterEvents(
                        _presenter.selectedCategory == category
                            ? null
                            : category,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // Event list
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  message: filtering
                      ? 'No events match your search.'
                      : 'No upcoming events yet.\n'
                          'Tap "Add event" to create one.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];

                    if (item is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          4, 12, 4, 4,
                        ),
                        child: Text(
                          _dayLabel(item),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall,
                        ),
                      );
                    }

                    final event = item as Event;

                    return _EventTile(
                      event: event,
                      onTap: () => _showDetails(event),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Calendar tab
  Widget _buildCalendar(List<Event> all) {
    final dayEvents = _eventsOn(
      all,
      _presenter.selectedDay,
    )..sort((a, b) => a.date.compareTo(b.date));

    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        TableCalendar<Event>(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),

          focusedDay: _presenter.focusedDay,
          calendarFormat: _format,

          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
            CalendarFormat.week: 'Week',
          },

          selectedDayPredicate: (day) {
            return isSameDay(
              day,
              _presenter.selectedDay,
            );
          },

          eventLoader: (day) => _eventsOn(all, day),

          onDaySelected: (selected, focused) {
            _presenter.selectDay(selected, focused);
          },

          onFormatChanged: (format) {
            setState(() => _format = format);
          },

          onPageChanged: (focused) {
            _presenter.updateFocusedDay(focused);
          },
        ),

        const Divider(height: 1),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat.yMMMMEEEEd().format(
                _presenter.selectedDay,
              ),
              style: text.titleMedium,
            ),
          ),
        ),

        Expanded(
          child: dayEvents.isEmpty
              ? const _EmptyState(
                  message: 'Nothing planned for this day.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: dayEvents.length,
                  itemBuilder: (context, i) {
                    final event = dayEvents[i];

                    return _EventTile(
                      event: event,
                      onTap: () => _showDetails(event),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Event details information row
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// Event list tile
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(event.category.icon),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: text.titleMedium,
                    ),

                    const SizedBox(height: 2),

                    Text(
                      event.location.isEmpty
                          ? DateFormat.jm().format(event.date)
                          : '${DateFormat.jm().format(event.date)}'
                              '  •  ${event.location}',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
