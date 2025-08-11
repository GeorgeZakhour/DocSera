import 'package:flutter/material.dart';
import '../app/const.dart';

class BaseScaffold extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool showBackArrow;
  final Widget title;
  final int titleAlignment;
  final double height;
  final List<Widget>? actions;
  final bool resizeToAvoidBottomInset; // ✅ أضفناه هنا

  const BaseScaffold({
    super.key,
    this.color = AppColors.background3,
    required this.child,
    this.showBackArrow = true,
    required this.title,
    this.titleAlignment = 1,
    this.height = 65,
    this.actions,
    this.resizeToAvoidBottomInset = true, // ✅ القيمة الافتراضية
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset, // ✅ هنا أضفناه
      backgroundColor: color,
      appBar: AppBar(
        toolbarHeight: height,
        leading: showBackArrow
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.whiteText,
            size: 16,
          ),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null,
        title: title,
        centerTitle: titleAlignment == 1,
        backgroundColor: AppColors.main,
        elevation: 0,
        actions: actions,
      ),
      body: child,
    );
  }
}
