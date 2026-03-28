import 'package:flutter/cupertino.dart';

import '../application/group_members_viewmodel.dart';

/// Page to display current group members and an "Add Member" button.
class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({super.key, required this.chatId});

  final String chatId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  late final GroupMembersViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = GroupMembersViewModel(chatId: widget.chatId)
      ..addListener(_onViewModelChanged)
      ..loadMembers();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Members'),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_viewModel.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_viewModel.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _viewModel.loadMembers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _viewModel.members.isEmpty
              ? const Center(child: Text('No members'))
              : ListView.builder(
                  itemCount: _viewModel.members.length,
                  itemBuilder: (context, index) {
                    final member = _viewModel.members[index];
                    final name = member.username ?? 'User ${member.uid}';
                    final initial = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?';
                    final isAdmin = member.role.toLowerCase() == 'admin';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemGrey4,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
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
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  member.role,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isAdmin
                                        ? CupertinoColors.activeBlue
                                        : CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                    fontWeight: isAdmin
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () {
                // TODO: implement add member
              },
              child: const Text('Add Member'),
            ),
          ),
        ),
      ],
    );
  }
}
