import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_state.dart';
import 'package:docsera/models/gift.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'voucher_detail_page.dart';
import 'widgets/voucher_card.dart';

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

                    // Glass summary strip
                    if (state is VouchersLoaded)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: _VoucherStatChip(
                                  icon: Icons.confirmation_number_rounded,
                                  label: l.active,
                                  count: state.active.length,
                                  color: AppColors.main,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _VoucherStatChip(
                                  icon: Icons.check_circle_rounded,
                                  label: l.used,
                                  count: state.used.length,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _VoucherStatChip(
                                  icon: Icons.timer_off_rounded,
                                  label: l.expired,
                                  count: state.expired.length,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
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
          ...tabGifts.asMap().entries.map((e) => _GiftCard(
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

  List<Gift> _giftsForKind(List<Gift> gifts, _EmptyKind kind) {
    switch (kind) {
      case _EmptyKind.active:
        return gifts.where((g) => g.status == 'claimed').toList();
      case _EmptyKind.used:
        return gifts.where((g) => g.status == 'used').toList();
      case _EmptyKind.expired:
        return gifts.where((g) => g.status == 'expired').toList();
    }
  }

  void _showGiftDetail(BuildContext context, Gift gift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GiftDetailSheet(gift: gift),
    );
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
          _buildTab(l.active),
          _buildTab(l.used),
          _buildTab(l.expired),
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    // Counts intentionally omitted — the stat cards below already
    // surface them prominently, so duplicating them in the segment
    // bar would be visual noise.
    return Tab(
      height: 38.h,
      child: Center(
        child: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ─── Stat chip (glass mini card with count) ──────────────────────────────

class _VoucherStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _VoucherStatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.shrink(),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: color.withValues(alpha: 0.20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 13.sp, color: color),
                    SizedBox(width: 4.w),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.sp,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.mainDark.withValues(alpha: 0.65),
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
                colors: [Color(0xFFFF6B9D), Color(0xFFE91E8C)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.30),
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

// ─── Gift card ────────────────────────────────────────────────────────────

class _GiftCard extends StatelessWidget {
  final Gift gift;
  final int index;
  final VoidCallback onTap;

  const _GiftCard({
    required this.gift,
    required this.index,
    required this.onTap,
  });

  Color get _statusColor {
    switch (gift.status) {
      case 'used':
        return const Color(0xFF4CAF50);
      case 'expired':
        return Colors.grey;
      default:
        return const Color(0xFFE91E8C);
    }
  }

  IconData get _statusIcon {
    switch (gift.status) {
      case 'used':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  String _statusLabel(AppLocalizations l) {
    switch (gift.status) {
      case 'used':
        return l.voucherPageGiftStatusUsed;
      case 'expired':
        return l.voucherPageGiftStatusExpired;
      default:
        return l.voucherPageGiftStatusClaimed;
    }
  }

  String _discountText(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (gift.discountValue == null) return '';
    if (gift.discountType == 'percentage') {
      return '${gift.discountValue!.toInt()}%';
    }
    return '${gift.discountValue!.toInt()} ${l.currency}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = _statusColor;
    final isMuted = gift.status != 'claimed';
    final title = locale == 'ar'
        ? (gift.customTitleAr ?? gift.customTitle ?? gift.offerType)
        : (gift.customTitle ?? gift.offerType);
    final sentDate =
        DateFormat('dd/MM/yyyy').format(gift.sentAt.toLocal());
    final discount = _discountText(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 460 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: color.withValues(alpha: isMuted ? 0.15 : 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isMuted ? 0.06 : 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft orb backdrop
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: CustomPaint(
                      painter:
                          _GiftOrbsPainter(color: color, muted: isMuted),
                    ),
                  ),
                ),
                // Glass blur
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Accent rail
                PositionedDirectional(
                  start: 0,
                  top: 14.h,
                  bottom: 14.h,
                  child: Container(
                    width: 4.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color,
                          Color.lerp(color, Colors.white, 0.4) ?? color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DoctorAvatar(
                        imageUrl: gift.doctorImage,
                        color: color,
                        icon: _statusIcon,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.getText1(context)
                                        .copyWith(
                                      color: AppColors.mainDark,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (discount.isNotEmpty) ...[
                                  SizedBox(width: 8.w),
                                  _GiftDiscountBadge(
                                      value: discount, color: color),
                                ],
                              ],
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              l.voucherPageGiftSentBy(gift.doctorName),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.mainDark
                                    .withValues(alpha: 0.65),
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              l.voucherPageGiftSentOn(sentDate),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.grey[500],
                                fontSize: 9.5.sp,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                _GiftStatusPill(
                                  label: _statusLabel(l),
                                  icon: _statusIcon,
                                  color: color,
                                ),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: _GiftCodeChip(
                                    code: gift.voucherCode,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                            start: 6.w, top: 2.h),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18.sp,
                          color: color.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),

                // Muted diagonal stamp
                if (isMuted)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.18,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: color.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                _statusLabel(l),
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.sp,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Doctor avatar ────────────────────────────────────────────────────────

class _DoctorAvatar extends StatelessWidget {
  final String? imageUrl;
  final Color color;
  final IconData icon;

  const _DoctorAvatar({
    required this.imageUrl,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final size = 46.w;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(size, color, icon),
        ),
      );
    }
    return _placeholder(size, color, icon);
  }

  Widget _placeholder(double size, Color color, IconData icon) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Icon(icon, size: 22.sp, color: color),
    );
  }
}

// ─── Gift status pill ─────────────────────────────────────────────────────

class _GiftStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _GiftStatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gift code chip ───────────────────────────────────────────────────────

class _GiftCodeChip extends StatelessWidget {
  final String code;
  final Color color;

  const _GiftCodeChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 10.sp, color: color),
          SizedBox(width: 3.w),
          Flexible(
            child: Text(
              code,
              style: TextStyle(
                fontSize: 9.5.sp,
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gift discount badge ──────────────────────────────────────────────────

class _GiftDiscountBadge extends StatelessWidget {
  final String value;
  final Color color;

  const _GiftDiscountBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.mainDark],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Gift orbs painter ────────────────────────────────────────────────────

class _GiftOrbsPainter extends CustomPainter {
  final Color color;
  final bool muted;

  _GiftOrbsPainter({required this.color, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color c) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c, c.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    orb(
      Offset(size.width * 0.08, size.height * 0.5),
      size.width * 0.22,
      color.withValues(alpha: muted ? 0.08 : 0.22),
    );
    orb(
      Offset(size.width * 0.88, size.height * 0.2),
      size.width * 0.20,
      AppColors.background4.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _GiftOrbsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.muted != muted;
}

// ─── Gift detail bottom sheet ─────────────────────────────────────────────

class _GiftDetailSheet extends StatelessWidget {
  final Gift gift;

  const _GiftDetailSheet({required this.gift});

  Color get _statusColor {
    switch (gift.status) {
      case 'used':
        return const Color(0xFF4CAF50);
      case 'expired':
        return Colors.grey;
      default:
        return const Color(0xFFE91E8C);
    }
  }

  String _statusLabel(AppLocalizations l) {
    switch (gift.status) {
      case 'used':
        return l.voucherPageGiftStatusUsed;
      case 'expired':
        return l.voucherPageGiftStatusExpired;
      default:
        return l.voucherPageGiftStatusClaimed;
    }
  }

  IconData get _statusIcon {
    switch (gift.status) {
      case 'used':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  void _copyCode(BuildContext context) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: gift.voucherCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.personalGiftCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
        backgroundColor: const Color(0xFFE91E8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = _statusColor;
    final isActive = gift.status == 'claimed';

    final title = locale == 'ar'
        ? (gift.customTitleAr ?? gift.customTitle ?? gift.offerType)
        : (gift.customTitle ?? gift.offerType);

    final description = locale == 'ar'
        ? (gift.descriptionAr ?? gift.description)
        : (gift.description ?? gift.descriptionAr);

    final expiryText = gift.expiresAt != null
        ? DateFormat('dd/MM/yyyy').format(gift.expiresAt!.toLocal())
        : l.personalGiftNoExpiry;

    String discountText = '';
    if (gift.discountValue != null) {
      discountText = gift.discountType == 'percentage'
          ? '${gift.discountValue!.toInt()}%'
          : '${gift.discountValue!.toInt()} ${l.currency}';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: Stack(
            children: [
              // Glass backdrop
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.96),
                          color.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Drag handle
                    SizedBox(height: 12.h),
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Doctor avatar + name
                    _DoctorAvatar(
                      imageUrl: gift.doctorImage,
                      color: color,
                      icon: _statusIcon,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      l.voucherPageGiftSentBy(gift.doctorName),
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.mainDark.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l.voucherPageGiftDetailTitle,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 14.h),

                    // Status pill
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: color.withValues(alpha: 0.30), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 13.sp, color: color),
                          SizedBox(width: 6.w),
                          Text(
                            _statusLabel(l),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Offer title + discount
                          Center(
                            child: Text(
                              title,
                              style: AppTextStyles.getTitle2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (discountText.isNotEmpty) ...[
                            SizedBox(height: 10.h),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 18.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, AppColors.mainDark],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_offer_rounded,
                                        size: 14.sp, color: Colors.white),
                                    SizedBox(width: 6.w),
                                    Text(
                                      discountText,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Doctor's personal message
                          if (gift.message != null &&
                              gift.message!.isNotEmpty) ...[
                            SizedBox(height: 20.h),
                            Text(
                              l.voucherPageGiftDoctorMessageHeading,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border(
                                  left: BorderSide(color: color, width: 3.5),
                                ),
                              ),
                              child: Text(
                                gift.message!,
                                style: AppTextStyles.getText2(context).copyWith(
                                  color: AppColors.mainDark
                                      .withValues(alpha: 0.82),
                                  height: 1.55,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],

                          // Description
                          if (description != null &&
                              description.isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            Text(
                              description,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.mainDark
                                    .withValues(alpha: 0.70),
                                height: 1.5,
                              ),
                            ),
                          ],

                          SizedBox(height: 20.h),

                          // QR + code (active gifts only)
                          if (isActive) ...[
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.20),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: gift.voucherCode,
                                  version: QrVersions.auto,
                                  size: 160.w,
                                  gapless: true,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.mainDark,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppColors.mainDark,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            GestureDetector(
                              onTap: () => _copyCode(context),
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 22.w, vertical: 14.h),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        color.withValues(alpha: 0.10),
                                        AppColors.background4,
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(14.r),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        gift.voucherCode,
                                        style: TextStyle(
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.mainDark,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Container(
                                        width: 26.w,
                                        height: 26.w,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.copy_rounded,
                                            size: 12.sp,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Center(
                              child: Text(
                                l.personalGiftTapToCopy,
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: AppColors.mainDark
                                      .withValues(alpha: 0.50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: 14.h),

                          // Expiry info row
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFFF9800)
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 14.sp,
                                    color: const Color(0xFFE07000)),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    l.personalGiftValidUntil(expiryText),
                                    style: AppTextStyles.getText2(context)
                                        .copyWith(
                                      color: const Color(0xFFB85400),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 28.h),

                          // Close button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    EdgeInsets.symmetric(vertical: 14.h),
                                backgroundColor: AppColors.mainDark
                                    .withValues(alpha: 0.07),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14.r),
                                ),
                              ),
                              child: Text(
                                l.voucherPageGiftClose,
                                style: AppTextStyles.getText1(context)
                                    .copyWith(
                                  color: AppColors.mainDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
