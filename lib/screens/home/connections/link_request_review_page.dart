// Review page for an incoming patient↔doctor link request.
//
// Surfaced from a notification deep-link (docsera://link-request/<id>).
// Shows the doctor as a hero card (real photo + specialty + clinic) on a
// soft-mint glass background. Body explains exactly what the doctor will
// see and what stays private. Approve/reject calls into LinkRequestCubit
// → rpc_respond_patient_link, then routes to LinkRequestResultPage with
// an animated success/declined visual.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Connections/link_request_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/home/connections/link_request_result_page.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';

class LinkRequestReviewPage extends StatelessWidget {
  final String requestId;
  const LinkRequestReviewPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LinkRequestCubit()..load(requestId),
      child: const _LinkRequestReviewView(),
    );
  }
}

class _LinkRequestReviewView extends StatelessWidget {
  const _LinkRequestReviewView();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return BlocConsumer<LinkRequestCubit, LinkRequestState>(
      listener: (context, state) {
        if (state is LinkRequestResolved) {
          // Doctor name was stashed on the holder by the action handlers,
          // since the cubit has discarded the request after resolution.
          final doctorName = _ResultDoctorNameHolder.instance.value ?? '';
          _ResultDoctorNameHolder.instance.value = null;
          final kind = !state.approved
              ? LinkRequestResultKind.rejected
              : (state.resolvedStatus == 'merged'
                  ? LinkRequestResultKind.merged
                  : LinkRequestResultKind.approved);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LinkRequestResultPage(
                kind: kind,
                doctorName: doctorName,
              ),
            ),
          );
        } else if (state is LinkRequestFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(local.linkRequestErrorToast),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7FDFC),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.grey.shade800),
          ),
          body: Stack(
            children: [
              const _BackgroundOrbs(),
              SafeArea(
                child: switch (state) {
                  LinkRequestLoading() => const _LoadingView(),
                  LinkRequestNotFound() => const _NotFoundView(),
                  LinkRequestLoaded() => _LoadedView(state: state),
                  LinkRequestSubmitting() =>
                    _LoadedView(state: state, isSubmitting: true),
                  _ => const _LoadingView(),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Background orbs — soft-mint gradient with two radial highlights, matching
// the notifications inbox visual language.
// ---------------------------------------------------------------------------

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE9F8F7), Color(0xFFF7FDFC)],
              ),
            ),
          ),
          Positioned(
            top: -60.h,
            right: -40.w,
            child: Container(
              width: 240.w,
              height: 240.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.main.withValues(alpha: 0.20),
                    AppColors.main.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100.h,
            left: -40.w,
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.main.withValues(alpha: 0.12),
                    AppColors.main.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.main),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: (t - 0.85) / 0.15,
              child: Transform.scale(scale: t, child: child),
            ),
            child: Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                color: Colors.grey.shade500,
                size: 44.sp,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            local.linkRequestNotFoundTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle3(context).copyWith(
              color: AppColors.mainDark,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            local.linkRequestNotFoundBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText1(context).copyWith(
              color: Colors.grey.shade700,
              height: 1.55,
            ),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                local.linkRequestNotFoundCta,
                style: AppTextStyles.getText1(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final LinkRequestState state;
  final bool isSubmitting;
  const _LoadedView({required this.state, this.isSubmitting = false});

  PatientLinkRequest get _request => switch (state) {
        LinkRequestLoaded(:final request) => request,
        LinkRequestSubmitting(:final request) => request,
        _ => throw StateError('unexpected'),
      };

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final req = _request;
    final cubit = context.read<LinkRequestCubit>();

    final kindLabel = req.isMerge
        ? local.linkRequestKindMerge
        : (req.isForRelative
            ? local.linkRequestKindConnectRelative
            : local.linkRequestKindConnect);
    final intro = req.isMerge
        ? local.linkRequestIntroMerge
        : (req.isForRelative
            ? local.linkRequestIntroConnectRelative
            : local.linkRequestIntroConnect);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kind chip
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                kindLabel,
                style: AppTextStyles.getText3(context).copyWith(
                  color: AppColors.main,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 18.h),

          // Hero doctor card — tap to open profile
          _DoctorHeroCard(
            request: req,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorProfilePage(doctorId: req.doctorId),
                ),
              );
            },
          ),
          SizedBox(height: 18.h),

          // Intro line
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              '${req.doctorName} $intro.',
              style: AppTextStyles.getText1(context).copyWith(
                color: Colors.grey.shade800,
                height: 1.55,
              ),
            ),
          ),
          SizedBox(height: 24.h),

          if (req.isMerge)
            _GlassPanel(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.merge_type_rounded,
                        color: AppColors.main, size: 22.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        local.linkRequestMergeBenefits,
                        style: AppTextStyles.getText1(context).copyWith(
                          color: Colors.grey.shade800,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _SectionHeader(
              icon: Icons.visibility_outlined,
              accent: AppColors.main,
              text: local.linkRequestWhatDoctorSeesTitle,
            ),
            SizedBox(height: 8.h),
            _GlassPanel(
              child: Column(
                children: [
                  _AccessRow(
                    icon: Icons.badge_outlined,
                    text: local.linkRequestAccessIdentity,
                    positive: true,
                  ),
                  _AccessRow(
                    icon: Icons.event_available_outlined,
                    text: local.linkRequestAccessAppointments,
                    positive: true,
                  ),
                  _AccessRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: local.linkRequestAccessMessages,
                    positive: true,
                  ),
                  _AccessRow(
                    icon: Icons.folder_shared_outlined,
                    text: local.linkRequestAccessDocuments,
                    positive: true,
                  ),
                  _AccessRow(
                    icon: Icons.favorite_outline_rounded,
                    text: local.linkRequestAccessHealthProfile,
                    positive: true,
                    isLast: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
            _SectionHeader(
              icon: Icons.lock_outline_rounded,
              accent: Colors.grey.shade600,
              text: local.linkRequestNotSharedTitle,
            ),
            SizedBox(height: 8.h),
            _GlassPanel(
              child: Column(
                children: [
                  _AccessRow(
                    icon: Icons.event_busy_outlined,
                    text: local.linkRequestNotSharedAppointments,
                    positive: false,
                  ),
                  _AccessRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: local.linkRequestNotSharedMessages,
                    positive: false,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 22.h),

          // Decline-explainer micro-copy
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.grey.shade500, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  local.linkRequestRejectExplain,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Actions
          Row(
            children: [
              Expanded(
                child: _DeclineButton(
                  onTap: isSubmitting
                      ? null
                      : () {
                          _writeArgs(context, req);
                          cubit.respond(approve: false);
                        },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: _ApproveButton(
                  isSubmitting: isSubmitting,
                  onTap: isSubmitting
                      ? null
                      : () {
                          _writeArgs(context, req);
                          cubit.respond(approve: true);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stash doctor name on a process-scoped holder so the result page
  /// can render it after the cubit transitions to LinkRequestResolved
  /// (the request is no longer in cubit state by then).
  void _writeArgs(BuildContext context, PatientLinkRequest req) {
    _ResultDoctorNameHolder.instance.value = req.doctorName;
  }
}

/// Lightweight holder for the doctor name handed from review → result.
/// Avoids touching ModalRoute internals. Cleared by the result page when
/// it pops.
class _ResultDoctorNameHolder {
  _ResultDoctorNameHolder._();
  static final _ResultDoctorNameHolder instance = _ResultDoctorNameHolder._();
  String? value;
}

// ---------------------------------------------------------------------------
// Hero doctor card — frosted glass, real photo, name + specialty + clinic.
// ---------------------------------------------------------------------------

class _DoctorHeroCard extends StatelessWidget {
  final PatientLinkRequest request;
  final VoidCallback onTap;
  const _DoctorHeroCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
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
              child: Row(
                children: [
                  Hero(
                    tag: 'doctor-${request.doctorId}',
                    child: Container(
                      width: 72.w,
                      height: 72.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.main.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.main.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _DoctorAvatar(request: request),
                    ),
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
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.doctorSpecialty != null &&
                            request.doctorSpecialty!.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            request.doctorSpecialty!,
                            style: AppTextStyles.getText2(context).copyWith(
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
                                  size: 13.sp, color: Colors.grey.shade500),
                              SizedBox(width: 4.w),
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
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward_rounded,
                                size: 14.sp, color: AppColors.main),
                            SizedBox(width: 4.w),
                            Text(
                              local.linkRequestViewProfile,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.main,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the doctor's avatar with the same precedence as the rest of
/// the patient app:
///   1. Their uploaded `doctor_image` if present — fully-qualified URL
///      passes through; a relative storage path (e.g.
///      "<doctor-id>/profile/profile.jpeg") is resolved against the
///      `doctor` storage bucket via `getPublicUrl`
///   2. The gendered bundled asset (male-doc / female-doc / male-phys /
///      female-phys) chosen by `getDoctorImage` when no upload exists
class _DoctorAvatar extends StatelessWidget {
  final PatientLinkRequest request;
  const _DoctorAvatar({required this.request});

  String? _resolveUrl() {
    final raw = request.doctorImage?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('assets/')) return null;
    // Supabase storage path → public URL via the 'doctor' bucket. Mirrors
    // `resolveDoctorImagePathAndWidget` in lib/utils/doctor_image_utils.dart.
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
          size: 32.sp,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frosted-glass panel + section pieces
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;
  const _SectionHeader({
    required this.icon,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 16.sp),
        SizedBox(width: 8.w),
        Text(
          text,
          style: AppTextStyles.getText2(context).copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AccessRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool positive;
  final bool isLast;
  const _AccessRow({
    required this.icon,
    required this.text,
    required this.positive,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = positive ? AppColors.main : Colors.grey.shade500;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: tint, size: 16.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.grey.shade800,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (!isLast)
            Padding(
              padding: EdgeInsets.only(top: 12.h, left: 44.w),
              child: Divider(
                height: 1,
                color: Colors.grey.shade200,
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
      height: 52.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: isSubmitting
            ? SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 18.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    local.linkRequestApprove,
                    style: AppTextStyles.getText1(context).copyWith(
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

class _DeclineButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _DeclineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade800,
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Text(
          local.linkRequestReject,
          style: AppTextStyles.getText1(context).copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
