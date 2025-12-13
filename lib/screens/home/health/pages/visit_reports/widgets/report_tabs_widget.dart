import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';

class ReportTabsWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const ReportTabsWidget({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = ["Main Info"]; // Tab واحدة فقط

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.main.withOpacity(0.28),
              ),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == selectedIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.main.withOpacity(0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          tabs[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                            active ? FontWeight.bold : FontWeight.w500,
                            color: active
                                ? AppColors.mainDark
                                : AppColors.mainDark.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
