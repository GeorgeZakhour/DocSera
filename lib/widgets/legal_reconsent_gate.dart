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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: _ReconsentDialog(pending: pending),
      ),
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

  String _labelFor(String docCode, AppLocalizations l) {
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

  String _consentLabelFor(String docCode, AppLocalizations l) {
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.85.sh),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Icon(Icons.gavel_outlined,
                      size: 36.sp, color: AppColors.main),
                ),
                SizedBox(height: 12.h),
                Text(
                  l.legalDocsUpdatedTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getTitle1(context),
                ),
                SizedBox(height: 10.h),
                Text(
                  l.legalDocsUpdatedBody,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText2(context)
                      .copyWith(color: Colors.black87),
                ),
                SizedBox(height: 18.h),
                ...widget.pending.documents.map((doc) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          dense: true,
                          activeColor: AppColors.main,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(_consentLabelFor(doc.code, l),
                              style: AppTextStyles.getText2(context)),
                          value: _accepted[doc.code] ?? false,
                          onChanged: (v) =>
                              setState(() => _accepted[doc.code] = v ?? false),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                              left: 16.w, right: 16.w, bottom: 10.h),
                          child: GestureDetector(
                            onTap: () => _open(doc.code),
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new,
                                    size: 12.sp, color: AppColors.main),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    '${_labelFor(doc.code, l)} (v${doc.version})',
                                    style: AppTextStyles.getText3(context)
                                        .copyWith(
                                      color: AppColors.main,
                                      decoration: TextDecoration.underline,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 8.h),
                ElevatedButton(
                  onPressed: (_allAccepted && !_submitting) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor:
                        _allAccepted ? AppColors.main : Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: _submitting
                          ? SizedBox(
                              height: 18.h,
                              width: 18.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : Text(
                              l.reviewAndAccept,
                              style: AppTextStyles.getText2(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
