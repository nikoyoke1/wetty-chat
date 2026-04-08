import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/dev_session_store.dart';

class AuthBootstrapPage extends ConsumerStatefulWidget {
  const AuthBootstrapPage({super.key});

  @override
  ConsumerState<AuthBootstrapPage> createState() => _AuthBootstrapPageState();
}

class _AuthBootstrapPageState extends ConsumerState<AuthBootstrapPage> {
  bool _didStart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStart) {
      return;
    }
    _didStart = true;
    Future<void>.microtask(() {
      ref.read(authSessionProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 16),
              Text('Checking session...'),
            ],
          ),
        ),
      ),
    );
  }
}
