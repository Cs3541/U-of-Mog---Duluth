import 'package:flutter/material.dart';
import '../models/broadcast_model.dart';
import '../presenters/broadcast_presenter.dart';

class BroadcastAlerts extends StatefulWidget {
  const BroadcastAlerts({super.key});

  @override
  State<BroadcastAlerts> createState() => _BroadcastAlertsState();
}

class _BroadcastAlertsState extends State<BroadcastAlerts> {
  final BroadcastPresenter _presenter = BroadcastPresenter();
  late final Stream<List<Broadcast>> _recent = _presenter.watchRecent();
  late final Stream<DateTime?> _lastSeen = _presenter.watchLastSeen();
  bool _dismissing = false;

  Future<void> _dismiss(List<Broadcast> shown) async {
    setState(() => _dismissing = true);
    final error = await _presenter.dismiss(shown);
    if (!mounted) return;
    setState(() => _dismissing = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime?>(
      stream: _lastSeen,
      builder: (context, seenSnap) {
        if (!seenSnap.hasData && seenSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<List<Broadcast>>(
          stream: _recent,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('BroadcastAlerts failed: ${snapshot.error}');
            }
            final unseen = _presenter.unseen(
              snapshot.data ?? const <Broadcast>[],
              seenSnap.data,
            );
            if (unseen.isEmpty) return const SizedBox.shrink();
            return Card(
              color: Colors.lightBlue.shade50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          unseen.length == 1
                              ? 'New message from Get Fit'
                              : '${unseen.length} new messages from Get Fit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        _dismissing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Dismiss',
                                icon: const Icon(Icons.close),
                                onPressed: () => _dismiss(unseen),
                              ),
                      ],
                    ),
                    for (final b in unseen) ...[
                      const SizedBox(height: 4),
                      Text(
                        b.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(b.message),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}