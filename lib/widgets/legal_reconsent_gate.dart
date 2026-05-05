// =============================================================================
// LegalReconsentGate — wraps the post-auth UI and shows a blocking modal when
// the server-side legal documents have a version newer than the user's last
// recorded acceptance. The user must check boxes for every pending document
// (or open and read each first) before they can dismiss the dialog.
//
// Triggers:
//   - mount of this widget (fires once after auth-restored cold start)
//   - app returning to foreground (catches version bumps that happened while
//     the app was backgrounded)
//
// On accept: calls rpc_record_legal_consent for each pending document, clears
// the pending state, and dismisses the dialog.
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/legal/legal_consent_service.dart';
import 'package:docsera/services/legal/legal_versions_checker.dart';

class LegalReconsentGate extends StatefulWidget {
  final Widget child;
  const LegalReconsentGate({super.key, required this.child});

  @override
  State<LegalReconsentGate> createState() => _LegalReconsentGateState();
}

class _LegalReconsentGateState extends State<LegalReconsentGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runCheck();
    }
  }

  Future<void> _runCheck() async {
    if (_checking || _dialogOpen) return;
    _checking = true;
    try {
      final pending = await LegalVersionsChecker.instance.findPending();
      if (!mounted || pending.isEmpty) return;
      _dialogOpen = true;
      await _showReconsentDialog(pending);
    } finally {
      _checking = false;
      _dialogOpen = false;
    }
  }

  Future<void> _showReconsentDialog(PendingReconsent pending) async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierLabel: 'reconsent',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, __) => PopScope(
        canPop: false,
        child: _ReconsentDialog(pending: pending),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * curved.value,
            sigmaY: 10 * curved.value,
          ),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReconsentDialog extends StatefulWidget {
  final PendingReconsent pending;
  const _ReconsentDialog({required this.pending});

  @override
  State<_ReconsentDialog> createState() => _ReconsentDialogState();
}

class _ReconsentDialogState extends State<_ReconsentDialog> {
  late final Map<String, bool> _accepted = {
    for (final d in widget.pending.documents) d.code: false
  };
  bool _submitting = false;

  bool get _allAccepted => _accepted.values.every((v) => v);

  String _docTitle(String docCode, AppLocalizations l) {
    switch (docCode) {
      case LegalDocumentCodes.privacyPolicy:
        return l.personalDataProtectionPolicy;
      case LegalDocumentCodes.termsOfService:
        return l.termsAndConditionsOfUse;
      case LegalDocumentCodes.medicalDisclaimer:
        return l.medicalDisclaimer;
      default:
        return docCode;
    }
  }

  String _consentLabel(String docCode, AppLocalizations l) {
    switch (docCode) {
      case LegalDocumentCodes.privacyPolicy:
        return l.acceptPrivacyPolicy;
      case LegalDocumentCodes.termsOfService:
        return l.acceptTerms;
      case LegalDocumentCodes.medicalDisclaimer:
        return l.acceptMedicalDisclaimer;
      default:
        return docCode;
    }
  }

  Future<void> _open(String docCode) async {
    final locale = Localizations.localeOf(context).languageCode;
    final uri = Uri.parse(LegalConsentService.urlFor(docCode, locale));
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      debugPrint('Could not launch $uri');
    }
  }

  Future<void> _submit() async {
    if (!_allAccepted || _submitting) return;
    setState(() => _submitting = true);
    try {
      await LegalVersionsChecker.instance
          .recordAcceptanceForPending(widget.pending);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 28.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460.w, maxHeight: 0.85.sh),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  // Frosted card: warm neutral with a subtle teal tint at the top
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.main.withOpacity(0.06),
                      Colors.white.withOpacity(0.96),
                    ],
                    stops: const [0.0, 0.35],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.7),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.main.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 22.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heroBadge(),
                      SizedBox(height: 16.h),
                      Text(
                        l.legalDocsUpdatedTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        l.legalDocsUpdatedBody,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: Colors.black.withOpacity(0.62),
                          height: 1.45,
                          fontSize: 11.5.sp,
                        ),
                      ),
                      SizedBox(height: 22.h),
                      ...widget.pending.documents.map((doc) {
                        final checked = _accepted[doc.code] ?? false;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: _DocConsentCard(
                            checked: checked,
                            consentLabel: _consentLabel(doc.code, l),
                            docTitle: _docTitle(doc.code, l),
                            version: doc.version,
                            onToggle: () => setState(
                              () => _accepted[doc.code] = !checked,
                            ),
                            onOpen: () => _open(doc.code),
                          ),
                        );
                      }),
                      SizedBox(height: 12.h),
                      _submitButton(l),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBadge() {
    return Center(
      child: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.main.withOpacity(0.18),
              AppColors.main.withOpacity(0.06),
            ],
          ),
          border: Border.all(
            color: AppColors.main.withOpacity(0.30),
            width: 1.2,
          ),
        ),
        child: Icon(
          Icons.gavel_rounded,
          size: 30.sp,
          color: AppColors.mainDark,
        ),
      ),
    );
  }

  Widget _submitButton(AppLocalizations l) {
    final enabled = _allAccepted && !_submitting;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.main.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _submit : null,
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(vertical: 15.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.main, AppColors.mainDark],
                    )
                  : null,
              color: enabled ? null : Colors.grey.shade300,
            ),
            alignment: Alignment.center,
            child: _submitting
                ? SizedBox(
                    height: 18.h,
                    width: 18.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    l.reviewAndAccept,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: enabled
                          ? Colors.white
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Single document card with custom checkbox, title, version pill, and a
/// tappable "view document" row at the bottom. Tinted teal when checked.
class _DocConsentCard extends StatelessWidget {
  final bool checked;
  final String consentLabel;
  final String docTitle;
  final String version;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _DocConsentCard({
    required this.checked,
    required this.consentLabel,
    required this.docTitle,
    required this.version,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: checked
            ? AppColors.main.withOpacity(0.06)
            : Colors.white.withOpacity(0.55),
        border: Border.all(
          color: checked
              ? AppColors.main.withOpacity(0.45)
              : Colors.black.withOpacity(0.08),
          width: checked ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onToggle,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CustomCheckbox(checked: checked),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        consentLabel,
                        style: AppTextStyles.getText2(context).copyWith(
                          fontSize: 12.5.sp,
                          fontWeight:
                              checked ? FontWeight.w700 : FontWeight.w500,
                          color: checked
                              ? AppColors.mainDark
                              : Colors.black.withOpacity(0.78),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 36.w),
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 4.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 13.sp, color: AppColors.main),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              docTitle,
                              style: AppTextStyles.getText3(context).copyWith(
                                fontSize: 11.sp,
                                color: AppColors.main,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: AppColors.main.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'v$version',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.chevron_right_rounded,
                              size: 14.sp,
                              color: AppColors.main.withOpacity(0.7)),
                        ],
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

class _CustomCheckbox extends StatelessWidget {
  final bool checked;
  const _CustomCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: checked ? AppColors.main : Colors.transparent,
        border: Border.all(
          color: checked ? AppColors.main : Colors.black.withOpacity(0.30),
          width: 1.6,
        ),
        borderRadius: BorderRadius.circular(7.r),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: checked ? 1.0 : 0.0,
        curve: Curves.easeOutBack,
        child: Icon(Icons.check_rounded, size: 15.sp, color: Colors.white),
      ),
    );
  }
}
