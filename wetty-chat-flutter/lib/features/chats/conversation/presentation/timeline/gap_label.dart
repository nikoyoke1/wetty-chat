import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';

class GapLabel extends StatelessWidget {
  const GapLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          style: appSecondaryTextStyle(context, fontSize: AppFontSizes.meta),
        ),
      ),
    );
  }
}
