import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../../../shared/presentation/app_divider.dart';

class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Unread Messages',
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
        ],
      ),
    );
  }
}
