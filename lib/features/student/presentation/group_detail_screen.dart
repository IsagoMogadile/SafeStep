import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_service.dart';
import '../data/group_repository.dart';
import '../domain/group_preset_messages.dart';

/// Walking group "chat" — deliberately regulated to only pre-typed
/// messages (no free text), and members can only see each other's names,
/// never send private messages (feedback: treat groups like a group
/// chat, but keep it to basic, safe, pre-approved content).
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repository = GroupRepository();
  final _messagesScrollController = ScrollController();
  late final TabController _tabController;
  late Future<Map<String, dynamic>> _groupFuture;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<List<Map<String, dynamic>>> _messagesFuture;
  bool _isMember = false;
  bool _isBusy = false;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _groupFuture = _repository.fetchGroup(widget.groupId);
    _membersFuture = _repository.fetchMembers(widget.groupId);
    _messagesFuture = _repository.fetchMessages(widget.groupId)
      ..then((_) => _scrollToBottom());
    _checkMembership();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  /// Messages are already fetched oldest-first (`created_at` ascending),
  /// so the newest message is the *last* item in a normal top-to-bottom
  /// ListView — the sort order was never the problem. What was missing
  /// is scrolling there automatically: without this, opening the screen
  /// (or sending a new message) left you looking at the oldest messages
  /// with the newest one off-screen below, which reads as "wrong order"
  /// even though the underlying data isn't.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) return;
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _checkMembership() async {
    final isMember = await _repository.isMember(widget.groupId, _userId);
    if (mounted) setState(() => _isMember = isMember);
  }

  Future<void> _refresh() async {
    setState(() {
      _membersFuture = _repository.fetchMembers(widget.groupId);
      _messagesFuture = _repository.fetchMessages(widget.groupId);
    });
  }

  Future<void> _toggleMembership() async {
    setState(() => _isBusy = true);
    try {
      if (_isMember) {
        await _repository.leave(widget.groupId, _userId);
      } else {
        await _repository.join(widget.groupId, _userId);
      }
      await _checkMembership();
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update membership')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendPreset(String key) async {
    try {
      await _repository.sendPresetMessage(
        groupId: widget.groupId,
        studentId: _userId,
        presetKey: key,
      );
      setState(() {
        _messagesFuture = _repository.fetchMessages(widget.groupId)
          ..then((_) => _scrollToBottom());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — are you a member?')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _groupFuture,
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(group?['name'] as String? ?? 'Group'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Messages'),
                Tab(text: 'Members'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_buildMessagesTab(), _buildMembersTab()],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isBusy
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _toggleMembership,
                      style: _isMember
                          ? OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            )
                          : null,
                      child: Text(_isMember ? 'Leave Group' : 'Join Group'),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data!;
        if (members.isEmpty) {
          return const Center(child: Text('No members yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final name =
                (members[index]['students'] as Map<String, dynamic>?)?['full_name']
                    as String? ??
                'Student';
            return ListTile(
              leading: CircleAvatar(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              ),
              title: Text(name),
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    _isMember
                        ? 'No messages yet — say hi below'
                        : 'Join this group to see and send messages',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                controller: _messagesScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message['student_id'] == _userId;
                  final name =
                      (message['students'] as Map<String, dynamic>?)?['full_name']
                          as String? ??
                      'Student';
                  final text =
                      groupPresetMessages[message['preset_key']] ??
                      message['preset_key'] as String;
                  final time = DateFormat('HH:mm').format(
                    DateTime.parse(message['created_at'] as String).toLocal(),
                  );

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: isMe
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          Text(text),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_isMember)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            // Horizontally scrollable rather than wrapping — with 15
            // preset options, a wrap would flood the screen vertically
            // and push the message feed out of view.
            child: SizedBox(
              height: 76,
              child: Column(
                children: [
                  Expanded(child: _presetRow(0)),
                  const SizedBox(height: 6),
                  Expanded(child: _presetRow(1)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _presetRow(int parity) {
    final entries = groupPresetMessages.entries
        .toList()
        .asMap()
        .entries
        .where((e) => e.key % 2 == parity)
        .map((e) => e.value)
        .toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(entry.value),
                onPressed: () => _sendPreset(entry.key),
              ),
            ),
          )
          .toList(),
    );
  }
}
