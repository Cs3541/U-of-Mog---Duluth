import 'dart:async';
import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../presenters/friend_presenter.dart';
import 'friend_alerts.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendsPresenter _presenter = FriendsPresenter();
  final TextEditingController _search = TextEditingController();
  final List<StreamSubscription> _subs = [];
  final Set<String> _busy = {};

  List<FriendUser> _friends = [];
  List<FriendRequest> _incoming = [];
  List<FriendRequest> _outgoing = [];
  List<FriendUser> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_presenter.watchFriends().listen(
        (v) => setState(() => _friends = v),
        onError: (e) => _showLoadError('friends', e)));
    _subs.add(_presenter.watchIncoming().listen(
        (v) => setState(() => _incoming = v),
        onError: (e) => _showLoadError('incoming requests', e)));
    _subs.add(_presenter.watchOutgoing().listen(
        (v) => setState(() => _outgoing = v),
        onError: (e) => _showLoadError('sent requests', e)));
  }

  void _showLoadError(String what, Object error) {
    debugPrint('FriendsScreen: failed to load $what: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load $what.')),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await _presenter.search(_search.text);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _run(String key, Future<String?> Function() action) async {
    setState(() => _busy.add(key));
    final error = await action();
    if (!mounted) return;
    setState(() => _busy.remove(key));
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_incoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PendingRequestsBanner(requests: _incoming),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: const InputDecoration(
                    labelText: 'Search by display name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _searching ? null : _runSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searched && _results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No users found.', textAlign: TextAlign.center),
            )
          else
            for (final user in _results)
              ListTile(
                leading: ProfileAvatar(photo: user.photo),
                title: Text(user.displayName),
                trailing: _searchAction(user),
              ),
          if (_incoming.isNotEmpty) ...[
            _header('Requests'),
            for (final r in _incoming)
              ListTile(
                leading: const ProfileAvatar(),
                title: Text(r.fromName),
                trailing: _busy.contains(r.from)
                    ? _spinner()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decline',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                _run(r.from, () => _presenter.decline(r)),
                          ),
                          IconButton(
                            tooltip: 'Accept',
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                _run(r.from, () => _presenter.accept(r)),
                          ),
                        ],
                      ),
              ),
          ],
          if (_outgoing.isNotEmpty) ...[
            _header('Sent'),
            for (final r in _outgoing)
              ListTile(
                leading: const ProfileAvatar(),
                title: Text(r.toName),
                subtitle: const Text('Pending'),
                trailing: _busy.contains(r.to)
                    ? _spinner()
                    : TextButton(
                        onPressed: () => _run(r.to, () => _presenter.cancel(r)),
                        child: const Text('Cancel'),
                      ),
              ),
          ],
          _header('Your friends'),
          if (_friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No friends yet. Search above to send a request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            for (final f in _friends)
              ListTile(
                leading: ProfileAvatar(photo: f.photo),
                title: Text(f.displayName),
                trailing: _busy.contains(f.uid)
                    ? _spinner()
                    : TextButton(
                        onPressed: () => _confirmRemove(f),
                        child: const Text('Remove'),
                      ),
              ),
        ],
      ),
    );
  }

  Widget _searchAction(FriendUser user) {
    if (_busy.contains(user.uid)) return _spinner();
    if (_friends.any((f) => f.uid == user.uid)) {
      return const Text('Friends', style: TextStyle(color: Colors.green));
    }
    final incoming = _incoming.where((r) => r.from == user.uid).firstOrNull;
    if (incoming != null) {
      return FilledButton(
        onPressed: () => _run(user.uid, () => _presenter.accept(incoming)),
        child: const Text('Accept'),
      );
    }
    final outgoing = _outgoing.where((r) => r.to == user.uid).firstOrNull;
    if (outgoing != null) {
      return OutlinedButton(
        onPressed: () => _run(user.uid, () => _presenter.cancel(outgoing)),
        child: const Text('Requested'),
      );
    }
    return FilledButton(
      onPressed: () => _run(user.uid, () => _presenter.sendRequest(user)),
      child: const Text('Add'),
    );
  }

  Future<void> _confirmRemove(FriendUser friend) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${friend.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) {
      _run(friend.uid, () => _presenter.removeFriend(friend.uid));
    }
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _spinner() => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}