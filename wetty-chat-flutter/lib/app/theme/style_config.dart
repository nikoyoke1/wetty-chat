import 'package:flutter/cupertino.dart';

const miSansBaseTextStyle = TextStyle(
  fontFamily: 'MiSans',
  fontWeight: FontWeight.w200,
);

const miSansCupertinoTheme = CupertinoThemeData(
  brightness: Brightness.light,
  textTheme: CupertinoTextThemeData(
    textStyle: miSansBaseTextStyle,
    actionTextStyle: miSansBaseTextStyle,
    tabLabelTextStyle: miSansBaseTextStyle,
    navTitleTextStyle: miSansBaseTextStyle,
    navLargeTitleTextStyle: miSansBaseTextStyle,
    navActionTextStyle: miSansBaseTextStyle,
    pickerTextStyle: miSansBaseTextStyle,
    dateTimePickerTextStyle: miSansBaseTextStyle,
  ),
);

TextStyle appTextStyle(BuildContext context) {
  return miSansBaseTextStyle.copyWith(
    color: CupertinoColors.label.resolveFrom(context),
  );
}
