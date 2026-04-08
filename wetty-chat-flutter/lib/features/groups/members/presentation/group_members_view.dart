import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/dev_session_store.dart';
import '../application/group_members_view_model.dart';
import '../data/group_member_models.dart';

/// Page to display current group members and admin member actions.
class GroupMembersPage extends ConsumerStatefulWidget {
  const GroupMembersPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends ConsumerState<GroupMembersPage> {
  static const Duration _searchDebounce = Duration(milliseconds: 250);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final viewState = ref.read(groupMembersViewModelProvider(widget.chatId));
    final members = viewState.valueOrNull;
    if (members == null || !members.hasMore || members.isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .updateSearchQuery(value);
    });
  }

  Future<void> _submitSearch(String value) async {
    _searchDebounceTimer?.cancel();
    await ref
        .read(groupMembersViewModelProvider(widget.chatId).notifier)
        .updateSearchQuery(value, mode: GroupMemberSearchMode.submitted);
  }

  void _showToast(String message) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) {
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 80,
        child: _ToastWidget(message: message, onDismiss: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _showErrorDialog(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleRemoveMember(GroupMember member) async {
    final displayName = _displayName(member);
    final confirmed = await _confirmAction(
      title: 'Remove Member',
      message: 'Remove $displayName from this group?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .removeMember(member.uid);
      if (!mounted) {
        return;
      }
      _showToast('Member removed');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showErrorDialog('$error');
    }
  }

  Future<void> _handleToggleRole(GroupMember member) async {
    final nextRole = member.role == 'admin' ? 'member' : 'admin';
    final isPromoting = nextRole == 'admin';
    final displayName = _displayName(member);
    final confirmed = await _confirmAction(
      title: isPromoting ? 'Promote Member' : 'Demote Member',
      message: isPromoting
          ? 'Promote $displayName to admin?'
          : 'Demote $displayName to member?',
      confirmLabel: isPromoting ? 'Promote' : 'Demote',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .updateMemberRole(member.uid, role: nextRole);
      if (!mounted) {
        return;
      }
      _showToast(isPromoting ? 'Member promoted' : 'Member demoted');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showErrorDialog('$error');
    }
  }

  Future<void> _handleMemberTap(
    GroupMember member, {
    required bool canManageMembers,
    required int currentUserId,
  }) async {
    if (!canManageMembers || member.uid == currentUserId) {
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _handleToggleRole(member);
            },
            child: Text(
              member.role == 'admin' ? 'Demote to Member' : 'Promote to Admin',
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _handleRemoveMember(member);
            },
            child: const Text('Remove from Group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _displayName(GroupMember member) {
    final username = member.username?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    return 'User ${member.uid}';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(
      groupMembersViewModelProvider(widget.chatId),
    );
    final currentUserId = ref.watch(authSessionProvider).currentUserId;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Members'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search members',
                onChanged: _onSearchChanged,
                onSubmitted: _submitSearch,
              ),
            ),
            Expanded(
              child: membersAsync.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(error.toString(), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        CupertinoButton.filled(
                          onPressed: () => ref
                              .read(
                                groupMembersViewModelProvider(
                                  widget.chatId,
                                ).notifier,
                              )
                              .reload(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (viewState) => Column(
                  children: [
                    Expanded(
                      child: viewState.members.isEmpty
                          ? _MembersEmptyState(
                              hasSearch: viewState.searchQuery.isNotEmpty,
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                              itemCount:
                                  viewState.members.length +
                                  (viewState.isLoadingMore ? 1 : 0),
                              separatorBuilder: (context, index) =>
                                  const _MemberDivider(),
                              itemBuilder: (context, index) {
                                if (index >= viewState.members.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CupertinoActivityIndicator(),
                                    ),
                                  );
                                }

                                final member = viewState.members[index];
                                final isCurrentUser =
                                    member.uid == currentUserId;
                                return _GroupMemberRow(
                                  member: member,
                                  displayName: _displayName(member),
                                  canManageMembers: viewState.canManageMembers,
                                  isCurrentUser: isCurrentUser,
                                  onTap: () => _handleMemberTap(
                                    member,
                                    canManageMembers:
                                        viewState.canManageMembers,
                                    currentUserId: currentUserId,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMemberRow extends StatelessWidget {
  const _GroupMemberRow({
    required this.member,
    required this.displayName,
    required this.canManageMembers,
    required this.isCurrentUser,
    required this.onTap,
  });

  final GroupMember member;
  final String displayName;
  final bool canManageMembers;
  final bool isCurrentUser;
  final VoidCallback onTap;

  bool get _isInteractive => canManageMembers && !isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isInteractive ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _GroupMemberAvatar(member: member, displayName: displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: labelColor),
              ),
            ),
            const SizedBox(width: 12),
            _RoleChip(role: member.role),
            if (_isInteractive) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: secondaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupMemberAvatar extends StatelessWidget {
  const _GroupMemberAvatar({required this.member, required this.displayName});

  static const double _size = 40;

  final GroupMember member;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: _size,
          height: _size,
          memCacheWidth: 112,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              _FallbackAvatar(displayName: displayName),
        ),
      );
    }

    return _FallbackAvatar(displayName: displayName);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final initial = displayName.isEmpty
        ? '?'
        : displayName.characters.first.toUpperCase();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final fillColor = isAdmin
        ? CupertinoColors.activeBlue
        : CupertinoColors.systemGrey4.resolveFrom(context);
    final textColor = isAdmin
        ? CupertinoColors.white
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          role,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _MembersEmptyState extends StatelessWidget {
  const _MembersEmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasSearch ? 'No matching members found.' : 'No members found.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

class _MemberDivider extends StatelessWidget {
  const _MemberDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 2), widget.onDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.white),
        ),
      ),
    );
  }
}
