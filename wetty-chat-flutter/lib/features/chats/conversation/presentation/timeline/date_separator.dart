import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            style: appOnDarkTextStyle(context, fontSize: AppFontSizes.meta),
          ),
        ),
      ),
    );
  }
}
