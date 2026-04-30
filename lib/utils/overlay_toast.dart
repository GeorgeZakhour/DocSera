import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

/// Visual variant of [showOverlayToast]. Picks the background color and
/// leading icon — success uses the brand teal, info uses an amber tone.
enum OverlayToastVariant { success, info }

/// Shows a floating toast that overlays even on top of modal bottom
/// sheets. The standard ScaffoldMessenger snackbar is hidden under the
/// sheet, so we mount a transient OverlayEntry on the *root* overlay
/// instead. SafeArea keeps it below the notch / Dynamic Island, and it
/// fades in/out on its own.
///
/// Always uses brand teal for success — never tints by feature (e.g.
/// gifts are pink-branded, but their copy/clipboard confirmation still
/// uses teal so the toast reads as a system confirmation, not a
/// gift-specific element).
void showOverlayToast(
  BuildContext context,
  String message, {
  OverlayToastVariant variant = OverlayToastVariant.success,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  final fadeController = ValueNotifier<double>(0.0);

  final isInfo = variant == OverlayToastVariant.info;
  final bgColor = isInfo ? const Color(0xFFE8A838) : AppColors.main;
  final iconData =
      isInfo ? Icons.info_outline_rounded : Icons.check_circle_rounded;

  entry = OverlayEntry(
    builder: (ctx) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: ValueListenableBuilder<double>(
              valueListenable: fadeController,
              builder: (_, v, child) => AnimatedOpacity(
                opacity: v,
                duration: const Duration(milliseconds: 200),
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 280.w),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, color: Colors.white, size: 16.sp),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  // Fade-in → hold → fade-out → remove
  WidgetsBinding.instance
      .addPostFrameCallback((_) => fadeController.value = 1.0);
  Future.delayed(const Duration(milliseconds: 1800), () {
    fadeController.value = 0.0;
  });
  Future.delayed(const Duration(milliseconds: 2100), () {
    if (entry.mounted) entry.remove();
    fadeController.dispose();
  });
}
