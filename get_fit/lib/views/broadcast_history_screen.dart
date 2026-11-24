import 'package:flutter/material.dart';
import '../models/broadcast_model.dart';
import '../presenters/broadcast_presenter.dart';

class BroadcastHistoryScreen extends StatefulWidget {
  const BroadcastHistoryScreen({super.key});

  @override
  State<BroadcastHistoryScreen> createState() => _BroadcastHistoryScreenState();
}

class _BroadcastHistoryScreenState extends State<BroadcastHistoryScreen> {
  final BroadcastPresenter _presenter = BroadcastPresenter();
  late final Stream<List<Broadcast>> _history = _presenter.watchHistory();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(Broadcast b) async {
    final titleController = TextEditingController(text: b.title);
    final messageController = TextEditingController(text: b.message);

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit broadcast'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: BroadcastRules.maxTitleLength,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: messageController,
                maxLength: BroadcastRules.maxMessageLength,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) return;

    final error = await _presenter.edit(
      b.id,
      titleController.text,
      messageController.text,
    );
    if (!mounted) return;
    _showMessage(error ?? 'Broadcast updated.');
  }

  Future<void> _remove(Broadcast b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove broadcast?'),
        content: Text('"${b.title}" will be removed for all users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error = await _presenter.remove(b.id);
    if (!mounted) return;
    _showMessage(error ?? 'Broadcast removed.');
  }

  String _formatDate(BuildContext context, DateTime? when) {
    if (when == null) return 'Sending…';
    final loc = MaterialLocalizations.of(context);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(when));
    return '${loc.formatMediumDate(when)} at $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast History')),
      body: StreamBuilder<List<Broadcast>>(
        stream: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load history.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No broadcasts sent yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final b = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.blue),
                  title: Text(b.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.message),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(context, b.sentAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _edit(b);
                      if (value == 'remove') _remove(b);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}