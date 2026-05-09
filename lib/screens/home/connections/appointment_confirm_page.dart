// First-booking confirm / dispute page.
//
// Triggered by deep_link `docsera://appointment-confirm/<id>` when a
// doctor books an appointment for a not-yet-connected patient. Shares
// the visual language of LinkRequestReviewPage: soft-mint orb
// background, frosted glass panels, hero doctor card.
//
// On confirm → rpc_confirm_first_appointment → routes to the link
// result page in "approved" mode (connection settled).
// On dispute → rpc_dispute_first_appointment → routes to the link
// result page in "rejected" mode (appt cancelled, link disputed).

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Connections/appointment_confirmation_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/home/connections/link_request_result_page.dart';
import 'package:docsera/services/supabase/appointment_confirmation_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';

class AppointmentConfirmPage extends StatelessWidget {
  final String appointmentId;
  const AppointmentConfirmPage({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppointmentConfirmationCubit()..load(appointmentId),
      child: const _AppointmentConfirmView(),
    );
  }
}

class _AppointmentConfirmView extends StatelessWidget {
  const _AppointmentConfirmView();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return BlocConsumer<AppointmentConfirmationCubit, AppointmentConfirmationState>(
      listener: (context, state) {
        if (state is AppointmentConfirmationResolved) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LinkRequestResultPage(
                kind: state.confirmed
                    ? LinkRequestResultKind.approved
                    : LinkRequestResultKind.rejected,
                doctorName: state.doctorName,
              ),
            ),
          );
        } else if (state is AppointmentConfirmationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(local.apptConfirmErrorToast),
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
                  AppointmentConfirmationLoading() => const _LoadingView(),
                  AppointmentConfirmationNotFound() => const _NotFoundView(),
                  AppointmentConfirmationLoaded() => _LoadedView(state: state),
                  AppointmentConfirmationSubmitting() =>
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
// Background orbs — visual continuity with the link-review page.
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
    return const Center(child: CircularProgressIndicator(color: AppColors.main));
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
          Container(
            width: 96.w,
            height: 96.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(
              Icons.event_busy_outlined,
              color: Colors.grey.shade500,
              size: 44.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            local.apptConfirmNotFoundTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle3(context).copyWith(color: AppColors.mainDark),
          ),
          SizedBox(height: 12.h),
          Text(
            local.apptConfirmNotFoundBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText1(context)
                .copyWith(color: Colors.grey.shade700, height: 1.55),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
  final AppointmentConfirmationState state;
  final bool isSubmitting;
  const _LoadedView({required this.state, this.isSubmitting = false});

  FirstBookingAppointment get _appointment => switch (state) {
        AppointmentConfirmationLoaded(:final appointment) => appointment,
        AppointmentConfirmationSubmitting(:final appointment) => appointment,
        _ => throw StateError('unexpected'),
      };

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final appt = _appointment;
    final cubit = context.read<AppointmentConfirmationCubit>();

    // Already confirmed / cancelled / done — show "already settled" state
    // so the patient doesn't waste a tap on a closed appointment.
    if (!appt.isActionable) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.grey.shade500,
                size: 44.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              local.apptConfirmActionedTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.getTitle3(context).copyWith(color: AppColors.mainDark),
            ),
            SizedBox(height: 12.h),
            Text(
              local.apptConfirmActionedBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText1(context)
                  .copyWith(color: Colors.grey.shade700, height: 1.55),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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

    final intro = appt.isForRelative
        ? local.apptConfirmIntroRelative(appt.doctorName)
        : local.apptConfirmIntro(appt.doctorName);

    final localeCode = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMMMMd(localeCode).add_jm().format(appt.appointmentDateTime);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                local.apptConfirmKind,
                style: AppTextStyles.getText3(context).copyWith(
                  color: AppColors.main,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          _DoctorHeroCard(
            appt: appt,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorProfilePage(doctorId: appt.doctorId),
                ),
              );
            },
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              intro,
              style: AppTextStyles.getText1(context)
                  .copyWith(color: Colors.grey.shade800, height: 1.55),
            ),
          ),
          SizedBox(height: 18.h),

          _GlassPanel(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: local.apptConfirmDateLabel,
                  value: dateFmt,
                ),
                if (appt.reason != null && appt.reason!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.medical_information_outlined,
                    label: local.apptConfirmReasonLabel,
                    value: appt.reason!,
                  ),
                if (appt.clinic != null && appt.clinic!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: local.apptConfirmClinicLabel,
                    value: [appt.clinic, appt.clinicAddressLine]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' — '),
                    isLast: true,
                  ),
              ],
            ),
          ),
          SizedBox(height: 18.h),

          // Why-we-ask explainer
          _GlassPanel(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline_rounded,
                      color: AppColors.main, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          local.apptConfirmWhyTitle,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: AppColors.main,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          local.apptConfirmWhyBody,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 22.h),

          // Dispute-explainer micro-copy
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.grey.shade500, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  local.apptConfirmDisputeNote,
                  style: AppTextStyles.getText3(context)
                      .copyWith(color: Colors.grey.shade600, height: 1.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Actions: confirm primary, dispute secondary
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : () => cubit.respond(confirm: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
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
                          local.apptConfirmCta,
                          style: AppTextStyles.getText1(context).copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 48.h,
            child: OutlinedButton(
              onPressed: isSubmitting ? null : () => cubit.respond(confirm: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
              child: Text(
                local.apptConfirmDisputeCta,
                style: AppTextStyles.getText1(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable sub-components
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.main.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.main, size: 16.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast)
            Padding(
              padding: EdgeInsets.only(top: 12.h, left: 44.w),
              child: Divider(height: 1, color: Colors.grey.shade200),
            ),
        ],
      ),
    );
  }
}

class _DoctorHeroCard extends StatelessWidget {
  final FirstBookingAppointment appt;
  final VoidCallback onTap;
  const _DoctorHeroCard({required this.appt, required this.onTap});

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
                    tag: 'doctor-${appt.doctorId}',
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
                      child: _DoctorAvatar(appt: appt),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.doctorName,
                          style: AppTextStyles.getTitle3(context).copyWith(
                            color: AppColors.mainDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (appt.doctorSpecialty != null &&
                            appt.doctorSpecialty!.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            appt.doctorSpecialty!,
                            style: AppTextStyles.getText2(context).copyWith(
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

class _DoctorAvatar extends StatelessWidget {
  final FirstBookingAppointment appt;
  const _DoctorAvatar({required this.appt});

  String? _resolveUrl() {
    final raw = appt.doctorImage?.trim();
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
        placeholder: (_, __) => _GenderedFallback(appt: appt),
        errorWidget: (_, __, ___) => _GenderedFallback(appt: appt),
      );
    }
    return _GenderedFallback(appt: appt);
  }
}

class _GenderedFallback extends StatelessWidget {
  final FirstBookingAppointment appt;
  const _GenderedFallback({required this.appt});

  @override
  Widget build(BuildContext context) {
    final assetPath = getDoctorImage(
      imageUrl: null,
      gender: appt.doctorGender,
      title: appt.doctorTitle,
    );
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.main.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Icon(Icons.medical_services_outlined,
            color: AppColors.main, size: 32.sp),
      ),
    );
  }
}
