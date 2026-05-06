// Review page for an incoming patient↔doctor link request.
//
// Surfaced from a notification deep-link (docsera://link-request/<id>).
// Shows the doctor + the request kind, explains what approving does, and
// calls rpc_respond_patient_link via LinkRequestCubit.
//
// Three terminal flows:
//   approve a 'connect' → status='connected'  → green toast
//   approve a 'merge'   → status='merged'     → green toast (merge ran)
//   reject anything     → status='rejected'   → neutral toast

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Connections/link_request_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';

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
          final msg = !state.approved
              ? local.linkRequestRejectedToast
              : (state.resolvedStatus == 'merged'
                  ? local.linkRequestMergedToast
                  : local.linkRequestApprovedToast);
          final color = state.approved ? AppColors.main : Colors.grey.shade700;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
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
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.mainDark),
            title: Text(
              local.linkRequestTitle,
              style: AppTextStyles.getTitle2(context),
            ),
          ),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: switch (state) {
              LinkRequestLoading() => const _LoadingView(),
              LinkRequestNotFound() => const _NotFoundView(),
              LinkRequestLoaded() => _LoadedView(state: state),
              LinkRequestSubmitting() => _LoadedView(state: state, isSubmitting: true),
              _ => const _LoadingView(),
            },
          ),
        );
      },
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
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 56.sp, color: Colors.grey.shade400),
          SizedBox(height: 16.h),
          Text(
            local.linkRequestNotFoundTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle2(context),
          ),
          SizedBox(height: 8.h),
          Text(
            local.linkRequestNotFoundBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.grey.shade600),
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

    final title = req.isMerge ? local.linkRequestMergeTitle : local.linkRequestTitle;
    final body = req.isMerge
        ? local.linkRequestMergeBody(req.doctorName)
        : (req.isForRelative
            ? local.linkRequestConnectRelativeBody(req.doctorName)
            : local.linkRequestConnectBody(req.doctorName));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Doctor identity card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.background3,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.main.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: AppColors.main.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    req.isMerge ? Icons.merge_type_rounded : Icons.medical_services_outlined,
                    color: AppColors.main,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.getTitle3(context),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        req.doctorName,
                        style: AppTextStyles.getText1(context).copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Body explanation
          Text(
            body,
            style: AppTextStyles.getText1(context).copyWith(
              height: 1.55,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          // Trust note
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18.sp, color: Colors.grey.shade600),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    local.linkRequestTrustNote,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : () => cubit.respond(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text(
                    local.linkRequestReject,
                    style: AppTextStyles.getText1(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () => cubit.respond(approve: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
                      : Text(
                          local.linkRequestApprove,
                          style: AppTextStyles.getText1(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}
