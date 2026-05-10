// One pending link-request, rendered as a calm glass card.
//
// Layout (top → bottom):
//   1. Doctor hero — circular avatar (real photo or gendered fallback),
//      name + title, specialty + clinic line. Tap on the doctor opens
//      their public profile in a sub-page.
//   2. Plain-language "what this is" line, kind-aware:
//        connect → "Dr. X is asking to add you as a patient."
//        merge   → "Dr. X has records for you from before you joined Docsera."
//   3. Expandable "What does this mean for me?" panel — opens to show
//      what data flows in either direction. Closed by default; the user
//      doesn't have to read it to decide if they don't want to.
//   4. Two action buttons:
//        Approve (primary teal)  — fires immediately
//        Not now (text)         — opens the gentle decline dialog up in
//                                  the parent page; that dialog explains
//                                  the 30-day grace window and offers
//                                  permanent decline as a separate path.
//
// Inline state:
//   * isActing → the card overlays a soft progress halo, both buttons
//     disabled, so the user can't double-tap during the round-trip.
//   * resolved (just-approved/just-declined) → in-place success or
//     decline animation plays before the parent removes the card.
//   * isFocused → highlight halo when the card was opened from a
//     notification deep-link, so the relevant request is obvious.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Connections/connections_center_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/home/connections/link_request_review_page.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';

class ConnectionsRequestCard extends StatefulWidget {
  final PatientLinkRequest request;
  final int index; // 1-based
  final int total;
  final bool isActing;
  final ResolvedRequest? resolved;
  final bool isFocused;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const ConnectionsRequestCard({
    super.key,
    required this.request,
    required this.index,
    required this.total,
    required this.isActing,
    required this.resolved,
    required this.isFocused,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  State<ConnectionsRequestCard> createState() => _ConnectionsRequestCardState();
}

class _ConnectionsRequestCardState extends State<ConnectionsRequestCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _focusHalo;

  @override
  void initState() {
    super.initState();
    _focusHalo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isFocused) {
      _focusHalo.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(ConnectionsRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      _focusHalo.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _focusHalo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final req = widget.request;

    return AnimatedBuilder(
      animation: _focusHalo,
      builder: (_, child) {
        // Focus glow eases in then fades — a soft teal halo that says
        // "this is the one you tapped on", without being distracting.
        final glow = (1 - _focusHalo.value).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: widget.isFocused && glow > 0
                ? [
                    BoxShadow(
                      color:
                          AppColors.main.withValues(alpha: 0.35 * glow),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.main.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Position pill — only visible when there are
                      // multiple cards in the list. Tells the user
                      // exactly where this one sits without needing
                      // the scroll bar.
                      if (widget.total > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: AppColors.main
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                local.connectionsCardPosition(
                                  widget.index,
                                  widget.total,
                                ),
                                style: AppTextStyles.getText3(context)
                                    .copyWith(
                                  color: AppColors.main,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                      ],
                      _DoctorHero(request: req),
                      SizedBox(height: 14.h),
                      _KindChip(kind: req.kind, isForRelative: req.isForRelative),
                      SizedBox(height: 10.h),
                      _ExplanationLine(request: req),
                      SizedBox(height: 12.h),
                      _ExpandableDetails(
                        expanded: _expanded,
                        onToggle: () =>
                            setState(() => _expanded = !_expanded),
                        request: req,
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Expanded(
                            child: _NotNowButton(
                              onTap:
                                  widget.isActing ? null : widget.onDecline,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            flex: 2,
                            child: _ApproveButton(
                              isSubmitting: widget.isActing,
                              onTap:
                                  widget.isActing ? null : widget.onApprove,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Center(
                        child: TextButton(
                          onPressed: widget.isActing
                              ? null
                              : () => _openDetails(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 4.h),
                          ),
                          child: Text(
                            local.connectionsCardSeeFullDetails,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: AppColors.main,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.resolved != null)
                  Positioned.fill(
                    child: _ResolvedOverlay(
                      resolved: widget.resolved!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkRequestReviewPage(requestId: widget.request.id),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor hero (avatar + name + specialty + clinic). Tapping anywhere on
// this row opens the doctor's public profile.
// ---------------------------------------------------------------------------

class _DoctorHero extends StatelessWidget {
  final PatientLinkRequest request;
  const _DoctorHero({required this.request});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DoctorProfilePage(doctorId: request.doctorId),
        ),
      ),
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.main.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _DoctorAvatar(request: request),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.doctorName,
                    style: AppTextStyles.getTitle3(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (request.doctorSpecialty != null &&
                      request.doctorSpecialty!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      request.doctorSpecialty!,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (request.doctorClinic != null &&
                      request.doctorClinic!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12.sp, color: Colors.grey.shade500),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            request.doctorClinic!,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final PatientLinkRequest request;
  const _DoctorAvatar({required this.request});

  String? _resolveUrl() {
    final raw = request.doctorImage?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('assets/')) return null;
    try {
      return Supabase.instance.client.storage.from('doctor').getPublicUrl(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl();
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _GenderedFallback(request: request),
        errorWidget: (_, __, ___) => _GenderedFallback(request: request),
      );
    }
    return _GenderedFallback(request: request);
  }
}

class _GenderedFallback extends StatelessWidget {
  final PatientLinkRequest request;
  const _GenderedFallback({required this.request});

  @override
  Widget build(BuildContext context) {
    final assetPath = getDoctorImage(
      imageUrl: null,
      gender: request.doctorGender,
      title: request.doctorTitle,
    );
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.main.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Icon(
          Icons.medical_services_outlined,
          color: AppColors.main,
          size: 28.sp,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kind chip — visual flag for connect vs merge
// ---------------------------------------------------------------------------

class _KindChip extends StatelessWidget {
  final String kind;
  final bool isForRelative;
  const _KindChip({required this.kind, required this.isForRelative});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final isMerge = kind == 'merge';

    final text = isMerge
        ? local.connectionsCardKindMerge
        : (isForRelative
            ? local.connectionsCardKindConnectRelative
            : local.connectionsCardKindConnect);

    final icon = isMerge
        ? Icons.merge_type_rounded
        : Icons.person_add_alt_1_rounded;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: AppColors.main.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.sp, color: AppColors.main),
            SizedBox(width: 6.w),
            Text(
              text,
              style: AppTextStyles.getText3(context).copyWith(
                color: AppColors.main,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plain-language explanation line — what this request is, in one sentence
// ---------------------------------------------------------------------------

class _ExplanationLine extends StatelessWidget {
  final PatientLinkRequest request;
  const _ExplanationLine({required this.request});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final name = request.nameWithoutTitle;
    final text = request.isMerge
        ? local.connectionsCardExplainMerge(name)
        : (request.isForRelative
            ? local.connectionsCardExplainConnectRelative(name)
            : local.connectionsCardExplainConnect(name));

    return Text(
      text,
      style: AppTextStyles.getText2(context).copyWith(
        color: Colors.grey.shade800,
        height: 1.55,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable details — "what does this mean for me?"
// ---------------------------------------------------------------------------

class _ExpandableDetails extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final PatientLinkRequest request;

  const _ExpandableDetails({
    required this.expanded,
    required this.onToggle,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18.sp,
                  color: AppColors.main,
                ),
                SizedBox(width: 4.w),
                Text(
                  local.connectionsCardWhatThisMeans,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.main,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          child: expanded
              ? Container(
                  margin: EdgeInsets.only(top: 6.h),
                  padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.main.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.main.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: request.isMerge
                      ? const _MergeDetailsBody()
                      : const _ConnectDetailsBody(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MergeDetailsBody extends StatelessWidget {
  const _MergeDetailsBody();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    // Bills are intentionally NOT listed here — the merge does move
    // them on the server side, but exposing "your past bills" on the
    // patient-facing approval card feels financial / out of place when
    // the rest of the framing is medical. The bills simply appear in
    // the patient's account after merge, like any other record.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(icon: Icons.event_available_outlined, text: local.connectionsCardMergeAppointments),
        _DetailRow(icon: Icons.description_outlined, text: local.connectionsCardMergeDocuments),
        _DetailRow(icon: Icons.assignment_outlined, text: local.connectionsCardMergeReports),
        _DetailRow(icon: Icons.favorite_outline_rounded, text: local.connectionsCardMergeMedicalRecords),
        SizedBox(height: 6.h),
        Text(
          local.connectionsCardMergeFootnote,
          style: AppTextStyles.getText3(context).copyWith(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ConnectDetailsBody extends StatelessWidget {
  const _ConnectDetailsBody();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(icon: Icons.chat_bubble_outline_rounded, text: local.connectionsCardConnectMessages),
        _DetailRow(icon: Icons.event_available_outlined, text: local.connectionsCardConnectBooking),
        _DetailRow(icon: Icons.folder_shared_outlined, text: local.connectionsCardConnectShareDocs),
        SizedBox(height: 6.h),
        Text(
          local.connectionsCardConnectFootnote,
          style: AppTextStyles.getText3(context).copyWith(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: AppColors.main),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.getText3(context).copyWith(
                color: Colors.grey.shade800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ApproveButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isSubmitting;
  const _ApproveButton({required this.onTap, required this.isSubmitting});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return SizedBox(
      height: 46.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: isSubmitting
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 16.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    local.connectionsCardApprove,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotNowButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _NotNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return SizedBox(
      height: 46.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade800,
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          local.connectionsCardNotNow,
          style: AppTextStyles.getText2(context).copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resolved overlay — plays in-place after a respond resolves, before the
// parent removes the row from the list. Keeps the action visceral but
// not jarring.
// ---------------------------------------------------------------------------

class _ResolvedOverlay extends StatelessWidget {
  final ResolvedRequest resolved;
  const _ResolvedOverlay({required this.resolved});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final isApproved = resolved.approved;

    final color = isApproved ? AppColors.main : Colors.grey.shade400;
    final icon = isApproved ? Icons.check_rounded : Icons.access_time_rounded;
    final text = isApproved
        ? (resolved.resolvedStatus == 'merged'
            ? local.connectionsCardResolvedMerged(resolved.doctorName)
            : local.connectionsCardResolvedConnected(resolved.doctorName))
        : local.connectionsCardResolvedDeclined(resolved.doctorName);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55 * t),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Opacity(
                opacity: t,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                      child: Icon(icon, color: color, size: 28.sp),
                    ),
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
