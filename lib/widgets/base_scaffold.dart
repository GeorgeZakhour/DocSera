import 'package:flutter/material.dart';
import '../app/const.dart';

class BaseScaffold extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool showBackArrow; // Controls the back arrow visibility
  final Widget title; // Dynamic title
  final int titleAlignment; // 1: Center, 2: Left
  final double height;
  final List<Widget>? actions; // ✅ Add actions for right-side buttons

  const BaseScaffold({
    super.key,
    this.color = AppColors.background3,
    required this.child,
    this.showBackArrow = true, // Default: show the back arrow
    required this.title, // Required title
    this.titleAlignment = 1,
    this.height = 65,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      appBar: AppBar(
        toolbarHeight: height,
        leading: showBackArrow
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back_ios, // Custom back arrow "<"
            color: AppColors.whiteText, // Matches the title color
            size: 16, // Smaller size for the arrow
          ),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null, // Hide the back arrow if showBackArrow is false
        title: title,
        centerTitle: titleAlignment == 1, // Center (1) or Left (2)
        backgroundColor: AppColors.main,
        elevation: 0,
        actions: actions, //
      ),
      body: child, // Body content
    );
  }
}
