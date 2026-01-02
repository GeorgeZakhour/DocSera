import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class OfflineBanner extends StatefulWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showBackOnline = false;

  @override
  void didUpdateWidget(covariant OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition from Offline -> Online
    if (oldWidget.isOffline && !widget.isOffline) {
      _triggerBackOnline();
    }
  }

  void _triggerBackOnline() {
    setState(() => _showBackOnline = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showBackOnline = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showRed = widget.isOffline;
    final showGreen = !widget.isOffline && _showBackOnline;

    final isVisible = showRed || showGreen;
    final color = showRed ? Colors.redAccent.shade700 : Colors.green;
    final icon = showRed ? Icons.wifi_off_rounded : Icons.wifi_rounded;
    final text = showRed
        ? (AppLocalizations.of(context)?.noInternetConnection ?? " لا يوجد اتصال بالإنترنت")
        : (AppLocalizations.of(context)?.internetRestored ?? "تم استعادة الاتصال بالإنترنت");

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: EdgeInsets.only(
          top: 4.h,
          bottom: MediaQuery.paddingOf(context).bottom > 0
              ? MediaQuery.paddingOf(context).bottom + 4.h
              : 12.h,
          left: 16.w,
          right: 16.w
        ),
        decoration: BoxDecoration(
          color: color,
        ),
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16.sp),
            SizedBox(width: 8.w),
            DefaultTextStyle(
              style: AppTextStyles.getText3(context).copyWith(color: Colors.white),
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}
