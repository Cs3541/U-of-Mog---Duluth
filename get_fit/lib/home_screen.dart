import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/exp_model.dart';
import '../models/feed_model.dart';
import '../repositories/event_repository.dart';
import '../presenters/home_presenter.dart';
import '../views/friend_alerts.dart';
import '../views/broadcast_alerts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomePresenter _presenter = HomePresenter();
  final EventRepository _eventRepository = EventRepository();

  final Set<String> _hidden = {};

  String? _uid;
  Stream<ExpStatus>? _expStream;
  Stream<List<FeedItem>>? _feedStream;
  late final Stream<List<Event>> _eventStream;

  @override
  void initState() {
    super.initState();
    _eventStream = _eventRepository.watchEvents();
    _uid = _presenter.currentUid;
    if (_uid != null) {
      _expStream = _presenter.watchExp(_uid!);
      _feedStream = _presenter.watchFeed(_uid!);
    }
  }

  Future<void> _dismiss(FeedItem item) async {
    setState(() => _hidden.add(item.id));
    try {
      await _presenter.dismiss(_uid!, item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hidden.remove(item.id));
      _showError('Could not dismiss. Try again.');
    }
  }

  Future<void> _dismissAll(List<FeedItem> items) async {
    final ids = items.map((i) => i.id).toList();
    setState(() => _hidden.addAll(ids));
    try {
      await _presenter.dismissAll(_uid!, ids);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hidden.removeAll(ids));
      _showError('Could not clear. Try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUpcomingEvents(List<Event> events) {
    final goingEventIds = <String>{
      if (_uid != null)
        for (final event in events)
          if (event.attendingUids.contains(_uid)) event.id,
    };
    final pendingEventIds = <String>{};

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.7,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upcoming events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No upcoming events.')),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final localizations =
                              MaterialLocalizations.of(context);
                          final date =
                              localizations.formatMediumDate(event.date);
                          final time = localizations.formatTimeOfDay(
                            TimeOfDay.fromDateTime(event.date),
                          );
                          final isGoing = goingEventIds.contains(event.id);
                          final isPending = pendingEventIds.contains(event.id);

                          return ListTile(
                            leading: Icon(event.category.icon),
                            title: Text(event.title),
                            subtitle: Text(
                              [
                                '$date at $time',
                                if (event.location.isNotEmpty) event.location,
                              ].join(' · '),
                            ),
                            trailing: _uid == null
                                ? const OutlinedButton(
                                    onPressed: null,
                                    child: Text('Sign in to RSVP'),
                                  )
                                : isGoing
                                ? OutlinedButton.icon(
                                    onPressed: isPending
                                        ? null
                                        : () => _setEventAttendance(
                                            event,
                                            false,
                                            goingEventIds,
                                            pendingEventIds,
                                            setSheetState,
                                          ),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Going'),
                                  )
                                : FilledButton(
                                    onPressed: isPending
                                        ? null
                                        : () => _setEventAttendance(
                                            event,
                                            true,
                                            goingEventIds,
                                            pendingEventIds,
                                            setSheetState,
                                          ),
                                    child: const Text("I'm going"),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setEventAttendance(
    Event event,
    bool going,
    Set<String> goingEventIds,
    Set<String> pendingEventIds,
    StateSetter setSheetState,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    setSheetState(() => pendingEventIds.add(event.id));
    try {
      await _eventRepository.setGoing(event.id, uid, going);
      setSheetState(() {
        if (going) {
          goingEventIds.add(event.id);
        } else {
          goingEventIds.remove(event.id);
        }
      });
    } catch (error) {
      if (mounted) {
        _showError("Couldn't update your RSVP. Please try again.");
      }
    } finally {
      setSheetState(() => pendingEventIds.remove(event.id));
    }
  }

  Widget _buildUpcomingEventsButton() {
    return StreamBuilder<List<Event>>(
      stream: _eventStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load upcoming events.');
        }

        final upcoming =
            snapshot.data
                ?.where((event) => event.date.isAfter(DateTime.now()))
                .toList() ??
            [];

        return OutlinedButton.icon(
          onPressed: snapshot.hasData
              ? () => _showUpcomingEvents(upcoming)
              : null,
          icon: const Icon(Icons.notifications_outlined),
          label: Text(
            snapshot.hasData
                ? 'Upcoming events (${upcoming.length})'
                : 'Loading upcoming events…',
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Welcome to Get Fit!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildUpcomingEventsButton(),
            const SizedBox(height: 16),
            const BroadcastAlerts(),
            const FriendAlerts(),
            if (_expStream != null) _buildLevelCard(),
            if (_feedStream != null) ...[
              const SizedBox(height: 24),
              _buildFeed(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    return StreamBuilder<ExpStatus>(
      stream: _expStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();

        final expLeft = status.expToNextLevel - status.expIntoLevel;
        final closeToLevel = status.progress >= 0.95;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (closeToLevel)
              _buildNotice(
                icon: Icons.trending_up,
                color: Colors.green,
                text: 'Almost there! Only $expLeft EXP until level '
                    '${status.level + 1}.',
              ),
            if (status.streakDays > 0)
              _buildNotice(
                icon: Icons.local_fire_department,
                color: Colors.orange,
                text: 'You are on a ${status.streakDays}-day workout streak. '
                    'Keep it going!',
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Level ${status.level}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (status.streakDays > 0) ...[
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text('${status.streakDays}-day streak'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: status.progress, minHeight: 8),
                    const SizedBox(height: 6),
                    Text(
                      '${status.expIntoLevel} / ${status.expToNextLevel} EXP '
                      'to level ${status.level + 1}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Card(
      color: color.withAlpha(30),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text),
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<List<FeedItem>>(
      stream: _feedStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load recent activity.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!
            .where((i) => !_hidden.contains(i.id))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () => _dismissAll(items),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing new yet. Finish a workout to earn EXP and badges.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...items.map(_buildFeedCard),
          ],
        );
      },
    );
  }

  Widget _buildFeedCard(FeedItem item) {
    final (icon, color) = switch (item.type) {
      FeedType.exp => (Icons.bolt, Colors.blue),
      FeedType.levelUp => (Icons.trending_up, Colors.green),
      FeedType.badge => (Icons.emoji_events, Colors.amber),
    };

    return Dismissible(
      key: ValueKey(item.id),
      onDismissed: (_) => _dismiss(item),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(38),
            child: Icon(icon, color: color),
          ),
          title: Text(item.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.subtitle.isNotEmpty) Text(item.subtitle),
              if (!item.timeUnknown)
                Text(
                  _formatWhen(context, item.achievedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          isThreeLine: item.subtitle.isNotEmpty && !item.timeUnknown,
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Dismiss',
            onPressed: () => _dismiss(item),
          ),
        ),
      ),
    );
  }

  String _formatWhen(BuildContext context, DateTime? when) {
    if (when == null) return 'Just now';

    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';

    final loc = MaterialLocalizations.of(context);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(when));
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);

    if (day == today) return 'Today at $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at $time';
    }
    if (when.year == now.year) {
      return '${loc.formatShortMonthDay(when)} at $time';
    }
    return '${loc.formatShortDate(when)} at $time';
  }
}