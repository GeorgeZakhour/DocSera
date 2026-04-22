import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart';

class VoucherDetailPage extends StatefulWidget {
  final VoucherModel voucher;

  const VoucherDetailPage({super.key, required this.voucher});

  @override
  State<VoucherDetailPage> createState() => _VoucherDetailPageState();
}

class _VoucherDetailPageState extends State<VoucherDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.7, curve: Curves.elasticOut)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    String expiresFormatted;
    try {
      expiresFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(widget.voucher.expiresAt).toLocal());
    } catch (_) {
      expiresFormatted = '—';
    }

    final statusColor = widget.voucher.isActive
        ? AppColors.main
        : widget.voucher.isUsed
            ? const Color(0xFF4CAF50)
            : Colors.grey;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF007E80),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            AppLocalizations.of(context)!.voucherDetails,
            style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              // QR Code Card
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(28.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: statusColor.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.voucher.isActive
                                  ? Icons.check_circle_rounded
                                  : widget.voucher.isUsed
                                      ? Icons.task_alt_rounded
                                      : Icons.cancel_rounded,
                              size: 14.sp,
                              color: statusColor,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              _statusText(context),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Text(
                        widget.voucher.getLocalizedTitle(locale),
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),

                      // QR Code
                      if (widget.voucher.isActive)
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.main.withOpacity(0.1), width: 2),
                          ),
                          child: QrImageView(
                            data: widget.voucher.code,
                            version: QrVersions.auto,
                            size: 180.w,
                            foregroundColor: AppColors.mainDark,
                          ),
                        ),

                      SizedBox(height: 20.h),

                      // Code display
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.voucher.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.codeCopied),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              backgroundColor: AppColors.main,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: AppColors.main.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.main.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.voucher.code,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.main,
                                  letterSpacing: 3,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Icon(Icons.copy_rounded, size: 18.sp, color: AppColors.main),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        AppLocalizations.of(context)!.tapToCopy,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Details card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (widget.voucher.getLocalizedPartnerName(locale).isNotEmpty)
                      _infoRow(context, Icons.store_rounded, AppLocalizations.of(context)!.partner, widget.voucher.getLocalizedPartnerName(locale), AppColors.main),
                    if (widget.voucher.getLocalizedPartnerAddress(locale).isNotEmpty)
                      _infoRow(context, Icons.location_on_rounded, AppLocalizations.of(context)!.address, widget.voucher.getLocalizedPartnerAddress(locale), const Color(0xFF4CAF50)),
                    _infoRow(context, Icons.calendar_today_rounded, AppLocalizations.of(context)!.expiresAt, expiresFormatted, const Color(0xFFFF9800)),
                    if (widget.voucher.discountValue != null)
                      _infoRow(
                        context,
                        Icons.discount_rounded,
                        AppLocalizations.of(context)!.discount,
                        widget.voucher.discountType == 'percentage'
                            ? '${widget.voucher.discountValue!.toInt()}%'
                            : '${widget.voucher.discountValue!.toInt()} ${AppLocalizations.of(context)!.currency}',
                        const Color(0xFFE91E63),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Instructions
              if (widget.voucher.isActive)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.main.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18.sp, color: AppColors.main),
                          SizedBox(width: 8.w),
                          Text(
                            AppLocalizations.of(context)!.howToUse,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mainDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        AppLocalizations.of(context)!.voucherInstructions,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.voucher.isActive && widget.voucher.offerCategory == 'doctor_promotion')
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: 12.h),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.main.withOpacity(0.12)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16.sp, color: AppColors.main),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.promotionShowCodeAtPayment,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: AppColors.main,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(BuildContext context) {
    if (widget.voucher.isActive) return AppLocalizations.of(context)!.active;
    if (widget.voucher.isUsed) return AppLocalizations.of(context)!.used;
    return AppLocalizations.of(context)!.expired;
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 16.sp, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
