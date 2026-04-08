import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';

class TokenLoginPage extends ConsumerStatefulWidget {
  const TokenLoginPage({super.key});

  @override
  ConsumerState<TokenLoginPage> createState() => _TokenLoginPageState();
}

class _TokenLoginPageState extends ConsumerState<TokenLoginPage> {
  late final TextEditingController _tokenController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorText = 'Enter a JWT token.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authSessionProvider.notifier).loginWithJwt(token);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('JWT Login')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Paste a JWT token to start a temporary authenticated session.',
              style: appSecondaryTextStyle(
                context,
                fontSize: AppFontSizes.body,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _tokenController,
              maxLines: 6,
              minLines: 4,
              placeholder: 'Enter JWT token',
              padding: const EdgeInsets.all(14),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.bodySmall,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
