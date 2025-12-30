import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageAccessRightsPage extends StatefulWidget {
  final String relativeId;
  final String relativeName;

  const ManageAccessRightsPage({
    Key? key,
    required this.relativeId,
    required this.relativeName,
  }) : super(key: key);

  @override
  State<ManageAccessRightsPage> createState() =>
      _ManageAccessRightsPageState();
}

class _ManageAccessRightsPageState extends State<ManageAccessRightsPage> {
  String _accountHolderName = '';

  @override
  void initState() {
    super.initState();
    _loadAccountHolder();
  }

  Future<void> _loadAccountHolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountHolderName =
          prefs.getString('userName') ??
              AppLocalizations.of(context)!.accountHolder;
    });
  }

  String _getInitials(String name) {
    final trimmed = name.trim();

    // 1️⃣ اسم فارغ كليًا
    if (trimmed.isEmpty) {
      return '؟';
    }

    // 2️⃣ تقسيم مع تنظيف الفراغات
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '؟';
    }

    final first = parts[0];
    final last = parts.length > 1 ? parts.last : null;

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(first);

    // 3️⃣ عربي
    if (isArabic) {
      return first.characters.first;
    }

    // 4️⃣ لاتيني
    final firstChar = first.characters.isNotEmpty
        ? first.characters.first
        : '';

    final lastChar = (last != null && last.characters.isNotEmpty)
        ? last.characters.first
        : '';

    final initials = (firstChar + lastChar).toUpperCase();

    return initials.isEmpty ? '?' : initials;
  }


  void _showRemoveConfirmation() {
    final firstName = widget.relativeName.split(' ').first;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background2, // ✅ خلفية الديالوج
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        title: Text(
          AppLocalizations.of(context)!
              .removeRelativeTitle(firstName),
          textAlign: TextAlign.center,
          style: AppTextStyles.getTitle2(context)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.of(context)!.removeRelativeDesc,
          textAlign: TextAlign.center,
          style: AppTextStyles.getText2(context),
        ),
        actions: [
          Column(
            children: [
              // 🔴 REMOVE
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await context
                        .read<RelativesCubit>()
                        .deactivateRelative(widget.relativeId);

                    if (!mounted) return;
                    Navigator.pop(context); // dialog
                    Navigator.pop(context, true); // page
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.remove.toUpperCase(),
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),

              SizedBox(height: 8.h),

              // ⚫ CANCEL
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black, // ✅ نص أسود
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.cancel.toUpperCase(),
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionItem(String text, String boldText) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(Icons.check, color: AppColors.main, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$text ',
                style: AppTextStyles.getText3(context),
                children: [
                  TextSpan(
                    text: boldText,
                    style: AppTextStyles.getText3(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      color: Color.lerp(
          AppColors.background2, AppColors.mainDark, 0.05) ??
          AppColors.background2,
      title: Text(
        AppLocalizations.of(context)!.manageAccessRights,
        style:
        AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Title (Relative)
            Text(
              AppLocalizations.of(context)!
                  .accessRightsFor(widget.relativeName),
              style: AppTextStyles.getText2(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),

            /// 🔹 Main Card
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  /// Account Holder Card
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15.r,
                          backgroundColor: AppColors.orangeText,
                          child: Text(
                            _getInitials(_accountHolderName),
                            style: AppTextStyles.getText3(context)
                                .copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                (_accountHolderName.isEmpty
                                    ? AppLocalizations.of(context)!.unknown
                                    : _accountHolderName).toUpperCase()
                                ,
                                style: AppTextStyles.getText2(context)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                ' (${AppLocalizations.of(context)!.you})',
                                style: AppTextStyles.getText2(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.of(context)!.thisPersonCan,
                      style: AppTextStyles.getText2(context)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _permissionItem(
                    AppLocalizations.of(context)!
                        .bookRescheduleCancel,
                    AppLocalizations.of(context)!.allAppointments,
                  ),
                  _permissionItem(
                    AppLocalizations.of(context)!.addAndManage,
                    AppLocalizations.of(context)!.allDocuments,
                  ),
                  _permissionItem(
                    AppLocalizations.of(context)!.updateIdentity,
                    AppLocalizations.of(context)!.contactInfo,
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            /// 🔻 Remove Button (Bottom)
            Center(
              child: TextButton.icon(
                onPressed: _showRemoveConfirmation,
                icon: Icon(Icons.delete_forever_outlined,
                    color: AppColors.red),
                label: Text(
                  AppLocalizations.of(context)!
                      .removeThisRelative
                      .toUpperCase(),
                  style: AppTextStyles.getText2(context)
                      .copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
