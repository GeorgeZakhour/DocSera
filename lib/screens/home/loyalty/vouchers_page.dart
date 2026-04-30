import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_state.dart';
import 'package:docsera/Business_Logic/Loyalty/unread_gifts/unread_gifts_cubit.dart';
import 'package:docsera/models/gift.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'voucher_detail_page.dart';
import 'widgets/voucher_card.dart';
import 'widgets/gift_widgets.dart';

class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<VouchersCubit>().loadVouchers();
    // Page-open acknowledgement — clears the loyalty-banner badge
    // even before the patient taps any specific card. Per-card dots
    // stay correct because is_unread is read per-row in the API.
    context.read<UnreadGiftsCubit>().acknowledgeAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<VouchersCubit, VouchersState>(
          builder: (context, state) {
            return RefreshIndicator(
              color: AppColors.main,
              onRefresh: () async {
                await context.read<VouchersCubit>().loadVouchers();
              },
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 168.h,
                      backgroundColor: const Color(0xFF007E80),
                      systemOverlayStyle: SystemUiOverlayStyle.light,
                      iconTheme: const IconThemeData(color: Colors.white),
                      title: Text(
                        l.myVouchers,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(color: Colors.white),
                      ),
                      flexibleSpace: const FlexibleSpaceBar(
                        background: _HeroHeader(),
                      ),
                      bottom: PreferredSize(
                        preferredSize: Size.fromHeight(54.h),
                        child: _GlassTabBar(
                          controller: _tabController,
                          state: state,
                          l: l,
                        ),
                      ),
                    ),
                  ];
                },
                body: state is VouchersLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.main))
                    : state is VouchersLoaded
                        ? TabBarView(
                            controller: _tabController,
                            children: [
                              _buildList(state.active, _EmptyKind.active),
                              _buildList(state.used, _EmptyKind.used),
                              _buildList(state.expired, _EmptyKind.expired),
                            ],
                          )
                        : const SizedBox(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List vouchers, _EmptyKind kind) {
    // Pull the matching gifts for this tab from state
    final state = context.read<VouchersCubit>().state;
    final List<Gift> tabGifts = state is VouchersLoaded
        ? _giftsForKind(state.gifts, kind)
        : const [];

    if (vouchers.isEmpty && tabGifts.isEmpty) {
      return _EmptyState(kind: kind);
    }

    return ListView(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      children: [
        // ── Doctor gifts section (first, more personal) ──────────────
        if (tabGifts.isNotEmpty) ...[
          _GiftsSectionHeader(),
          ...tabGifts.asMap().entries.map((e) => GiftCard(
                gift: e.value,
                index: e.key,
                onTap: () => _showGiftDetail(context, e.value),
              )),
          if (vouchers.isNotEmpty) SizedBox(height: 6.h),
        ],

        // ── Partner / doctor-promotion vouchers ──────────────────────
        ...vouchers.asMap().entries.map((e) {
          final voucher = e.value;
          return VoucherCard(
            voucher: voucher,
            index: tabGifts.isNotEmpty ? tabGifts.length + e.key : e.key,
            onTap: () => Navigator.push(
                context, fadePageRoute(VoucherDetailPage(voucher: voucher))),
          );
        }),
      ],
    );
  }

  /// Derives the effective display status for a gift, client-side.
  /// A claimed gift whose expires_at has passed is effectively expired —
  /// even if the DB row hasn't been flipped yet by a background job.
  String _resolveGiftStatus(Gift g) {
    if (g.status == 'claimed' &&
        g.expiresAt != null &&
        g.expiresAt!.isBefore(DateTime.now())) {
      return 'expired';
    }
    return g.status;
  }

  List<Gift> _giftsForKind(List<Gift> gifts, _EmptyKind kind) {
    switch (kind) {
      case _EmptyKind.active:
        return gifts
            .where((g) => _resolveGiftStatus(g) == 'claimed')
            .toList();
      case _EmptyKind.used:
        return gifts.where((g) => _resolveGiftStatus(g) == 'used').toList();
      case _EmptyKind.expired:
        return gifts
            .where((g) => _resolveGiftStatus(g) == 'expired')
            .toList();
    }
  }

  void _showGiftDetail(BuildContext context, Gift gift) {
    // Mark this gift as viewed — decrements the bottom-nav badge.
    context.read<UnreadGiftsCubit>().markViewed([gift.claimId]);
    showGiftDetailSheet(context, gift);
  }
}

// ─── Hero header (gradient + floating orbs + voucher motif) ──────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF007E80), Color(0xFF00B4B6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Soft floating circles
        Positioned(
          top: -40.r,
          right: -30.r,
          child: _orb(140.r, Colors.white.withValues(alpha: 0.07)),
        ),
        Positioned(
          bottom: -30.r,
          left: -20.r,
          child: _orb(100.r, Colors.white.withValues(alpha: 0.05)),
        ),
        Positioned(
          top: 30.h,
          left: 80.w,
          child: _orb(50.r, Colors.white.withValues(alpha: 0.04)),
        ),
        // Floating voucher motifs — a curated cluster of glassy ticket
        // bubbles in varying sizes, rotations and opacities. The big one
        // anchors the bottom-right; smaller ones float around it for a
        // confetti-like vibe without becoming busy. All sit clear of the
        // segment bar at the bottom and the AppBar title at the top.
        Positioned(
          bottom: 78.h,
          right: 24.w,
          // Badge mirrors the bottom-nav badge — same UnreadGiftsCubit source.
          // NOTE: v1 only counts unread gifts; partner vouchers don't track
          // an "unread" timestamp yet. Broaden the count source in v2.
          child: BlocBuilder<UnreadGiftsCubit, int>(
            builder: (ctx, unreadCount) => Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red,
              offset: const Offset(4, -4),
              child: _TicketBubble(
                width: 76.r,
                height: 54.r,
                rotation: -0.18,
                iconSize: 26.sp,
                fillOpacity: 0.12,
                borderOpacity: 0.22,
                iconOpacity: 0.90,
                withShadow: true,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8.h,
          left: 36.w,
          child: _TicketBubble(
            width: 46.r,
            height: 32.r,
            rotation: 0.22,
            iconSize: 16.sp,
            fillOpacity: 0.08,
            borderOpacity: 0.18,
            iconOpacity: 0.55,
          ),
        ),
        Positioned(
          bottom: 92.h,
          left: 16.w,
          child: _TicketBubble(
            width: 32.r,
            height: 22.r,
            rotation: -0.30,
            iconSize: 11.sp,
            fillOpacity: 0.06,
            borderOpacity: 0.14,
            iconOpacity: 0.40,
          ),
        ),
        Positioned(
          top: 30.h,
          right: 130.w,
          child: _TicketBubble(
            width: 26.r,
            height: 18.r,
            rotation: 0.12,
            iconSize: 9.sp,
            fillOpacity: 0.05,
            borderOpacity: 0.16,
            iconOpacity: 0.35,
          ),
        ),
        // Small bubble floating beside the title — placed at title altitude
        // and offset to the left so it sits near the centered "قسائمي"
        // text without crowding it (the back button occupies the right
        // edge in RTL). Slightly higher opacity than the atmospheric
        // bubbles so the eye picks it up without it looking out of place.
        Positioned(
          top: 56.h,
          left: 64.w,
          child: _TicketBubble(
            width: 28.r,
            height: 20.r,
            rotation: 0.20,
            iconSize: 10.sp,
            fillOpacity: 0.11,
            borderOpacity: 0.22,
            iconOpacity: 0.55,
          ),
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Glassy tinted ticket bubble used as decorative confetti in the header.
/// All decorative defaults are tuned to keep the cluster atmospheric, not
/// loud — bump opacities only when the bubble is meant to anchor the eye.
class _TicketBubble extends StatelessWidget {
  final double width;
  final double height;
  final double rotation;
  final double iconSize;
  final double fillOpacity;
  final double borderOpacity;
  final double iconOpacity;
  final bool withShadow;

  const _TicketBubble({
    required this.width,
    required this.height,
    required this.rotation,
    required this.iconSize,
    required this.fillOpacity,
    required this.borderOpacity,
    required this.iconOpacity,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: fillOpacity),
          borderRadius: BorderRadius.circular(width * 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity),
          ),
          boxShadow: withShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.confirmation_number_rounded,
          color: Colors.white.withValues(alpha: iconOpacity),
          size: iconSize,
        ),
      ),
    );
  }
}

// ─── Glass tab bar (custom rounded pill indicator) ───────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  final VouchersState state;
  final AppLocalizations l;

  const _GlassTabBar({
    required this.controller,
    required this.state,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    // Fold gifts into each count so the segment-bar totals reflect
    // both partner/promo vouchers AND doctor gifts in one unified
    // view. Mirrors the mutually-exclusive priority used by
    // VoucherModel (used > expired > active).
    int activeCount = 0;
    int usedCount = 0;
    int expiredCount = 0;
    if (state is VouchersLoaded) {
      final s = state as VouchersLoaded;
      final now = DateTime.now();
      final giftActive = s.gifts
          .where((g) =>
              g.status == 'claimed' &&
              (g.expiresAt == null || g.expiresAt!.isAfter(now)))
          .length;
      final giftUsed = s.gifts.where((g) => g.status == 'used').length;
      final giftExpired = s.gifts
          .where((g) =>
              g.status == 'expired' ||
              (g.expiresAt != null &&
                  g.expiresAt!.isBefore(now) &&
                  g.status == 'claimed'))
          .length;
      activeCount = s.active.length + giftActive;
      usedCount = s.used.length + giftUsed;
      expiredCount = s.expired.length + giftExpired;
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.all(3.r),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.mainDark,
        unselectedLabelColor: Colors.white,
        labelStyle: AppTextStyles.getText2(context)
            .copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: AppTextStyles.getText2(context).copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85)),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor:
            const WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          _buildTab(l.active, activeCount),
          _buildTab(l.used, usedCount),
          _buildTab(l.expired, expiredCount),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      height: 38.h,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              constraints: BoxConstraints(minWidth: 18.w),
              height: 18.w,
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mainDark.withValues(alpha: 0.65),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(99),
              ),
              // FittedBox centers the rendered glyph regardless of
              // font ascent/descent metrics — `Text + height: 1`
              // alone leaves digits sitting near the top of the
              // line box, not the visual centre of the pill.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────

enum _EmptyKind { active, used, expired }

class _EmptyState extends StatefulWidget {
  final _EmptyKind kind;
  const _EmptyState({required this.kind});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  ({IconData icon, Color color, String message}) _config(
      AppLocalizations l) {
    switch (widget.kind) {
      case _EmptyKind.active:
        return (
          icon: Icons.confirmation_number_rounded,
          color: AppColors.main,
          message: l.noVouchers,
        );
      case _EmptyKind.used:
        return (
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF4CAF50),
          message: l.noVouchers,
        );
      case _EmptyKind.expired:
        return (
          icon: Icons.timer_off_rounded,
          color: Colors.grey.shade500,
          message: l.noVouchers,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cfg = _config(l);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: 60.h),
        Center(
          child: AnimatedBuilder(
            animation: _float,
            builder: (_, __) {
              final t = _float.value;
              return Transform.translate(
                offset: Offset(0, -6 * t),
                child: Container(
                  width: 110.w,
                  height: 110.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cfg.color.withValues(alpha: 0.18 + 0.10 * t),
                        cfg.color.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Container(
                    width: 78.w,
                    height: 78.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cfg.color.withValues(alpha: 0.20),
                          cfg.color.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: cfg.color.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Icon(cfg.icon,
                        size: 38.sp, color: cfg.color),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 18.h),
        Center(
          child: Text(
            cfg.message,
            style: AppTextStyles.getText1(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Gifts section header ─────────────────────────────────────────────────

class _GiftsSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.giftAccentLight, AppColors.giftAccent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.giftAccent.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.card_giftcard_rounded,
                size: 15.sp, color: Colors.white),
          ),
          SizedBox(width: 10.w),
          Text(
            l.voucherPageGiftsSection,
            style: AppTextStyles.getText1(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
