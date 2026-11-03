import 'package:flutter/material.dart';
import '../presenters/badge_presenter.dart';
import '../models/badge_model.dart';

class BadgesScreen extends StatelessWidget {
  BadgesScreen({super.key});

  final BadgePresenter _presenter = BadgePresenter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BadgeProgress>>(
      future: _presenter.getBadgeProgress(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final progress = snapshot.data!;
        final badges = _presenter.allBadges;

        return GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          children: [
            for (int i = 0; i < badges.length; i++)
              _badgeTile(badges[i], progress[i].isAchieved),
          ],
        );
      },
    );
  }

  Widget _badgeTile(BadgeDefinition badge, bool achieved) {
    final color = achieved ? Colors.amber : Colors.grey;
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 50, color: color),
          const SizedBox(height: 8),
          Text(badge.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: achieved ? Colors.black : Colors.grey)),
          Text(badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}