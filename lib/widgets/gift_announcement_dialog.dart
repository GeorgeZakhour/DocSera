import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/gift.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'package:docsera/screens/home/loyalty/vouchers_page.dart';
import 'package:docsera/utils/page_transitions.dart';

const String _kAnnouncedGiftClaimsKey = 'announced_gift_claim_ids';

/// Checks for active gifts the patient hasn't been celebrated about yet
/// and, if any are found, shows the [_GiftAnnouncementDialog]. Compares
/// the current set of active (status == 'claimed') gift claim ids to the
/// last-announced set in SharedPreferences and only shows the dialog
/// when there's a delta.
///
/// Safe to call multiple times — early-returns if nothing is new. Should
/// be called once after the first frame on the home screen, after the
/// user has authenticated.
Future<void> maybeShowGiftAnnouncement(BuildContext context) async {
  try {
    final gifts = await LoyaltyService().getMyGifts();
    if (!context.mounted) return;

    // Active gifts only. Used / expired ones don't get celebrated again
    // — the popup is a "you got a new gift" signal, not a recap.
    final activeGifts = gifts.where((g) => g.status == 'claimed').toList();
    if (activeGifts.isEmpty) return;

    final activeClaimIds = activeGifts.map((g) => g.claimId).toSet();

    final prefs = await SharedPreferences.getInstance();
    final announced =
        (prefs.getStringList(_kAnnouncedGiftClaimsKey) ?? const []).toSet();

    final newClaimIds = activeClaimIds.difference(announced);
    if (newClaimIds.isEmpty) return;

    if (!context.mounted) return;

    final newGifts =
        activeGifts.where((g) => newClaimIds.contains(g.claimId)).toList();

    final tappedView = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _GiftAnnouncementDialog(gifts: newGifts),
    );

    // Save the *current* set of active claim ids — used/expired gifts
    // age out of the set naturally, keeping it bounded.
    await prefs.setStringList(
      _kAnnouncedGiftClaimsKey,
      activeClaimIds.toList(),
    );

    if (tappedView == true && context.mounted) {
      Navigator.push(context, fadePageRoute(const VouchersPage()));
    }
  } catch (_) {
    // Non-critical: if anything fails (offline, RPC errored), silently
    // skip — the badge on the bottom nav still surfaces unread gifts.
  }
}

class _GiftAnnouncementDialog extends StatelessWidget {
  final List<Gift> gifts;

  const _GiftAnnouncementDialog({required this.gifts});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final count = gifts.length;
    final isSingle = count == 1;

    final firstGift = gifts.first;
    final firstDoctorName = firstGift.doctorName;

    final title = isSingle
        ? l.giftAnnouncementTitleSingle
        : l.giftAnnouncementTitleMulti(count);
    final body = isSingle
        ? l.giftAnnouncementBodySingle(firstDoctorName)
        : l.giftAnnouncementBodyMulti;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Container(
        decoration: BoxDecoration(
          // Same pale-rose surface used in the wallet's gift card —
          // keeps the gift channel visually consistent.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFF6EC)],
          ),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: AppColors.giftAccent.withValues(alpha: 0.18),
            width: 0.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pink gradient gift chip
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.giftAccentLight, AppColors.giftAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.giftAccent.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 26.sp,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                title,
                style: AppTextStyles.getTitle1(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                body,
                style: AppTextStyles.getText2(context).copyWith(
                  color: AppColors.mainDark.withValues(alpha: 0.72),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              // Single-gift extra: show the offer title in a soft chip.
              if (isSingle) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.giftAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.giftAccent.withValues(alpha: 0.25),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    isAr
                        ? (firstGift.customTitleAr ??
                            firstGift.customTitle ??
                            firstGift.offerType)
                        : (firstGift.customTitle ?? firstGift.offerType),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.giftAccent,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        l.giftAnnouncementLaterButton,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: AppColors.mainDark.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.giftAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        l.giftAnnouncementViewButton,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
