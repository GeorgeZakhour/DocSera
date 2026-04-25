import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/partner_model.dart';
import 'package:docsera/utils/color_utils.dart';

class PartnerBubble extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback onTap;

  const PartnerBubble({super.key, required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final name = partner.getLocalizedName(locale);
    final ringColor = colorFromHex(partner.brandColor, fallback: AppColors.main);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76.w,
        child: Column(
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor.withOpacity(0.6), width: 2),
                color: ringColor.withOpacity(0.06),
              ),
              padding: EdgeInsets.all(3.w),
              child: ClipOval(
                child: partner.logoUrl != null && partner.logoUrl!.isNotEmpty
                    ? Image.network(
                        partner.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initialsFallback(name, ringColor),
                      )
                    : _initialsFallback(name, ringColor),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText3(context).copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsFallback(String name, Color color) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      color: color.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 22.sp,
        ),
      ),
    );
  }
}
