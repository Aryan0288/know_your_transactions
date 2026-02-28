import 'package:flutter/material.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';

class CommonScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final bool?resizeToAvoidBottomInset;
  final Widget body;
  final bool? canPop;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final void Function()? onBackPress;

  const CommonScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.onBackPress,
    this.canPop,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // backgroundColor: Colors.white,
      backgroundColor:backgroundColor ?? scaffoldColor,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}



AppBar appBarWithoutProgress(BuildContext context,
    {void Function()? onPressed, Widget? icon, String? appBarTitle, TextStyle? appBarTitleStyle, Color? appBarColor}) {
  return AppBar(
    backgroundColor: appBarColor ?? scaffoldColor,
    leading: InkWell(
        onTap: () {
          onPressed == null ? Navigator.pop(context) : onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: icon ?? Icon(Icons.arrow_back)),
          ),
        )),
    centerTitle: true,
    title: Text(appBarTitle ?? "", style: appBarTitleStyle ?? appBarTitleTextStyle),
  );
}