import 'package:flutter/material.dart';
import '../presenters/badge_presenter.dart';
import '../models/badge_model.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final BadgePresenter _presenter = BadgePresenter();
  late final Stream<List<BadgeProgress>> _progressStream =
      _presenter.watchBadgeProgress();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BadgeProgress>>(
      stream: _progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final progress = snapshot.data!;
        final badges = _presenter.allBadges;

        return GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          padding: const EdgeInsets.all(16),
          children: [
            for (int i = 0; i < badges.length; i++)
              _badgeTile(badges[i], progress[i]),
          ],
        );
      },
    );
  }

  Widget _badgeTile(BadgeDefinition badge, BadgeProgress progress) {
    final achieved = progress.isAchieved;
    final color = achieved ? Colors.amber : Colors.grey;
    final count = progress.currentProgress > badge.threshold
        ? badge.threshold
        : progress.currentProgress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 50, color: color),
            const SizedBox(height: 8),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: achieved ? Colors.black : Colors.grey,
              ),
            ),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (achieved)
              const Text(
                'Earned',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            else ...[
              LinearProgressIndicator(
                value: count / badge.threshold,
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '$count / ${badge.threshold}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}