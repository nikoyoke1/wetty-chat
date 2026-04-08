import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../metadata/application/group_metadata_view_model.dart';
import '../../../../shared/presentation/app_divider.dart';

/// Group Settings page: edit group name, description, and save.
class GroupSettingsPage extends ConsumerStatefulWidget {
  const GroupSettingsPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ScrollController _descScrollController = ScrollController();
  bool _didHydrateInitialValues = false;
  bool _isSaving = false;

  TextStyle _inputStyle(BuildContext context) {
    return TextStyle(color: CupertinoColors.label.resolveFrom(context));
  }

  TextStyle _placeholderStyle(BuildContext context) {
    return TextStyle(
      color: CupertinoColors.placeholderText.resolveFrom(context),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _descScrollController.dispose();
    super.dispose();
  }

  void _hydrateInitialValues(String name, String? description) {
    if (_didHydrateInitialValues) {
      return;
    }
    _didHydrateInitialValues = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _nameController.text = name;
      _descriptionController.text = description ?? '';
    });
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    if (_isSaving) {
      return;
    }

    final metadata = ref
        .read(groupMetadataViewModelProvider(widget.chatId))
        .valueOrNull;
    if (metadata == null) {
      return;
    }

    final nextName = _nameController.text.trim();
    final nextDescription = _descriptionController.text.trim();
    final normalizedDescription = nextDescription.isEmpty
        ? null
        : nextDescription;
    final hasChanged =
        nextName != metadata.name ||
        normalizedDescription != metadata.description;
    if (!hasChanged) {
      context.pop();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(groupMetadataViewModelProvider(widget.chatId).notifier)
          .updateMetadata(name: nextName, description: normalizedDescription);
      if (!mounted) {
        return;
      }
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorDialog('$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(
      groupMetadataViewModelProvider(widget.chatId),
    );
    final metadata = metadataAsync.valueOrNull;
    if (metadata != null) {
      _hydrateInitialValues(metadata.name, metadata.description);
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Settings'),
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: metadataAsync.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    CupertinoButton.filled(
                      onPressed: () => ref
                          .read(
                            groupMetadataViewModelProvider(
                              widget.chatId,
                            ).notifier,
                          )
                          .reload(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Group name',
                    enabled: !_isSaving,
                    style: _inputStyle(context),
                    placeholderStyle: _placeholderStyle(context),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: null,
                  ),
                  const AppDivider(height: 1),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  CupertinoScrollbar(
                    controller: _descScrollController,
                    child: CupertinoTextField(
                      controller: _descriptionController,
                      scrollController: _descScrollController,
                      placeholder: 'Enter group description',
                      enabled: !_isSaving,
                      style: _inputStyle(context),
                      placeholderStyle: _placeholderStyle(context),
                      maxLines: 4,
                      minLines: 2,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: null,
                    ),
                  ),
                  const AppDivider(height: 1),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: !_isSaving ? _onSave : null,
                      child: _isSaving
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text('Save Settings'),
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
}
