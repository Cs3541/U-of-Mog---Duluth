import 'package:flutter/material.dart';
import '../models/exp_model.dart';
import '../models/feed_model.dart';
import '../presenters/home_presenter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomePresenter _presenter = HomePresenter();

  final Set<String> _hidden = {};

  String? _uid;
  Stream<ExpStatus>? _expStream;
  Stream<List<FeedItem>>? _feedStream;

  @override
  void initState() {
    super.initState();
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

        return Card(
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
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (status.streakDays > 0) ...[
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 20),
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
        );
      },
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

        final items =
            snapshot.data!.where((i) => !_hidden.contains(i.id)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Recent activity',
                    style: Theme.of(context).textTheme.titleMedium),
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