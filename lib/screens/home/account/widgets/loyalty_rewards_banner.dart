import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/Business_Logic/Loyalty/unread_gifts/unread_gifts_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class LoyaltyRewardsBanner extends StatefulWidget {
  final int points;
  final VoidCallback onPointsTap;
  final VoidCallback onOffersTap;
  final VoidCallback onVouchersTap;
  final VoidCallback onReferralTap;

  const LoyaltyRewardsBanner({
    super.key,
    required this.points,
    required this.onPointsTap,
    required this.onOffersTap,
    required this.onVouchersTap,
    required this.onReferralTap,
  });

  @override
  State<LoyaltyRewardsBanner> createState() => _LoyaltyRewardsBannerState();
}

class _LoyaltyRewardsBannerState extends State<LoyaltyRewardsBanner>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pointsCountController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _pointsCount;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _pointsCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pointsCount = Tween<double>(begin: 0, end: widget.points.toDouble()).animate(
      CurvedAnimation(
        parent: _pointsCountController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pointsCountController.forward();
    });
  }

  @override
  void didUpdateWidget(LoyaltyRewardsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _pointsCount = Tween<double>(
        begin: oldWidget.points.toDouble(),
        end: widget.points.toDouble(),
      ).animate(CurvedAnimation(
        parent: _pointsCountController,
        curve: Curves.easeOutCubic,
      ));
      _pointsCountController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pointsCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideUp.value),
          child: Opacity(
            opacity: _fadeIn.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 14.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Points display
              _buildPointsHeader(l),
              SizedBox(height: 14.h),

              // 4 glassmorphism tiles
              Row(
                children: [
                  Expanded(
                    child: _GlassTile(
                      icon: Icons.stars_rounded,
                      label: l.myPoints,
                      onTap: widget.onPointsTap,
                      delay: 0,
                      entryController: _entryController,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _GlassTile(
                      icon: Icons.local_offer_rounded,
                      label: l.offers,
                      onTap: widget.onOffersTap,
                      delay: 1,
                      entryController: _entryController,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: BlocBuilder<UnreadGiftsCubit, int>(
                      builder: (ctx, unreadCount) {
                        final tile = _GlassTile(
                          icon: Icons.confirmation_number_rounded,
                          label: l.myVouchers,
                          onTap: widget.onVouchersTap,
                          delay: 2,
                          entryController: _entryController,
                        );
                        if (unreadCount <= 0) return tile;
                        // Overlay the badge bubble in a non-clipping
                        // Stack OUTSIDE the tile. `StackFit.passthrough`
                        // keeps the tight horizontal constraint from
                        // the surrounding Expanded — without it the
                        // Stack would default to loose, and the tile
                        // would shrink to its intrinsic content width
                        // (visibly smaller than its siblings).
                        return Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.passthrough,
                          children: [
                            tile,
                            PositionedDirectional(
                              top: -5.h,
                              end: -5.w,
                              child: _CountBubble(count: unreadCount),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _GlassTile(
                      icon: Icons.card_giftcard_rounded,
                      label: l.referFriends,
                      onTap: widget.onReferralTap,
                      delay: 3,
                      entryController: _entryController,
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

  Widget _buildPointsHeader(AppLocalizations l) {
    return GestureDetector(
      onTap: widget.onPointsTap,
      child: Row(
        children: [
          // Trophy icon in branded circle
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppColors.main.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.main,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          // Title + points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.loyaltyRewards,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedBuilder(
                  animation: _pointsCountController,
                  builder: (context, _) {
                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${_pointsCount.value.toInt()}',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mainDark,
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l.points}',
                            style: AppTextStyles.getText2(context).copyWith(
                              color: AppColors.main.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Arrow
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.grey[400],
            size: 12.sp,
          ),
        ],
      ),
    );
  }
}

/// Glassmorphism tile with branded teal colors, blur effect, and tap animation
class _GlassTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int delay;
  final AnimationController entryController;

  const _GlassTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.delay,
    required this.entryController,
  });

  @override
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final startInterval = 0.3 + (widget.delay * 0.1);
    final endInterval = (startInterval + 0.4).clamp(0.0, 1.0);

    final tileAnimation = CurvedAnimation(
      parent: widget.entryController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: tileAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: tileAnimation.value,
          child: Opacity(
            opacity: tileAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPressed
                        ? [
                            AppColors.main.withValues(alpha: 0.15),
                            AppColors.main.withValues(alpha: 0.08),
                          ]
                        : [
                            AppColors.main.withValues(alpha: 0.08),
                            AppColors.main.withValues(alpha: 0.04),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.main.withValues(alpha: _isPressed ? 0.25 : 0.12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: AppColors.main,
                      size: 22.sp,
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      widget.label,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.sp,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small orange-glass count chip used as a badge overlay on the
/// vouchers tile. Caps display at "+9" so the chip stays compact.
class _CountBubble extends StatelessWidget {
  final int count;
  const _CountBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '+9' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: 16.r, minHeight: 16.r),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2A65A), Color(0xFFE07A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A1F).withValues(alpha: 0.40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
