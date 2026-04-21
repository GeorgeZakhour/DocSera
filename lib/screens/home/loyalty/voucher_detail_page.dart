import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart';

class VoucherDetailPage extends StatelessWidget {
  final VoucherModel voucher;

  const VoucherDetailPage({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    String expiresFormatted;
    try {
      expiresFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(voucher.expiresAt).toLocal());
    } catch (_) {
      expiresFormatted = '—';
    }

    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6)],
              ),
              child: Column(
                children: [
                  Text(
                    voucher.getLocalizedTitle(locale),
                    style: AppTextStyles.getTitle1(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),

                  // QR Code
                  if (voucher.isActive)
                    QrImageView(
                      data: voucher.code,
                      version: QrVersions.auto,
                      size: 180.w,
                      foregroundColor: AppColors.mainDark,
                    ),

                  SizedBox(height: 16.h),

                  // Code display
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: voucher.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.codeCopied)),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            voucher.code,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.main,
                              letterSpacing: 3,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Icon(Icons.copy, size: 18.sp, color: AppColors.main),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 8.h),
                  Text(
                    AppLocalizations.of(context)!.tapToCopy,
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Details card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                children: [
                  _infoRow(context, AppLocalizations.of(context)!.status, _statusText(context)),
                  if (voucher.getLocalizedPartnerName(locale).isNotEmpty)
                    _infoRow(context, AppLocalizations.of(context)!.partner, voucher.getLocalizedPartnerName(locale)),
                  if (voucher.getLocalizedPartnerAddress(locale).isNotEmpty)
                    _infoRow(context, AppLocalizations.of(context)!.address, voucher.getLocalizedPartnerAddress(locale)),
                  _infoRow(context, AppLocalizations.of(context)!.expiresAt, expiresFormatted),
                  if (voucher.discountValue != null)
                    _infoRow(
                      context,
                      AppLocalizations.of(context)!.discount,
                      voucher.discountType == 'percentage'
                          ? '${voucher.discountValue!.toInt()}%'
                          : '${voucher.discountValue!.toInt()} SYP',
                    ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Instructions
            if (voucher.isActive)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.howToUse,
                      style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      AppLocalizations.of(context)!.voucherInstructions,
                      style: AppTextStyles.getText3(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusText(BuildContext context) {
    if (voucher.isActive) return AppLocalizations.of(context)!.active;
    if (voucher.isUsed) return AppLocalizations.of(context)!.used;
    return AppLocalizations.of(context)!.expired;
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Text('$label:', style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: AppTextStyles.getText2(context))),
        ],
      ),
    );
  }
}
