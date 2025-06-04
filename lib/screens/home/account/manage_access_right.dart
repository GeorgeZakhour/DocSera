import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ManageAccessRightsPage extends StatefulWidget {
  final String relativeId;
  final String relativeName;

  const ManageAccessRightsPage({
    Key? key,
    required this.relativeId,
    required this.relativeName,
  }) : super(key: key);

  @override
  _ManageAccessRightsPageState createState() => _ManageAccessRightsPageState();
}


class _ManageAccessRightsPageState extends State<ManageAccessRightsPage> {
  String userId = "";
  String userName = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? "";
    userName = prefs.getString('userName') ?? AppLocalizations.of(context)!.accountHolder;// جلب اسم المستخدم
    setState(() {});
  }

  /// ✅ حذف القريب من Firestore
  void _removeRelative() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('relatives')
          .doc(widget.relativeId) // Delete based on passed ID
          .delete();

      Navigator.pop(context); // Close confirmation dialog
      Navigator.pop(context); // Return to MyRelativesPage

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.relativeRemoved(widget.relativeName)),
          backgroundColor: AppColors.main.withOpacity(0.9),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.relativeRemoveFailed(widget.relativeName, e.toString())),
          backgroundColor: AppColors.yellow.withOpacity(0.9),
        ),
      );
    }
  }


  /// ✅ إظهار نافذة التأكيد عند حذف القريب
  void _showRemoveConfirmationDialog() {
    String firstName = widget.relativeName.split(' ')[0]; // Extract only first name

    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Ensure white background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        title: Text(
          AppLocalizations.of(context)!.removeRelativeTitle(firstName),
          textAlign: TextAlign.center,
          style: AppTextStyles.getTitle2(context).copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,)
         ),
        content: Text(
          AppLocalizations.of(context)!.removeRelativeDesc,
          textAlign: TextAlign.center,
          style: AppTextStyles.getText2(context).copyWith(
            color: Colors.black87),
          ),
        actions: [
          Column(
            children: [
              // ✅ REMOVE Button (Red, on top)
              SizedBox(
                width: double.infinity, // Full width button
                child: TextButton(
                  onPressed: _removeRelative,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.red, // Red background
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),

                  ),
                  child: Text(AppLocalizations.of(context)!.remove.toUpperCase(),
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),

              SizedBox(height: 8.h),

              // ✅ CANCEL Button (Black, below)
              SizedBox(
                width: double.infinity, // Full width button
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white, // White background
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(AppLocalizations.of(context)!.cancel.toUpperCase(),
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Function to get initials from the full name
  String _getInitials(String name) {
    List<String> words = name.trim().split(' '); // Split by spaces
    if (words.isEmpty) return "A"; // Default if empty
    String firstInitial = words[0].isNotEmpty ? words[0][0].toUpperCase() : ""; // First letter of first word
    String lastInitial = words.length > 1 && words.last.isNotEmpty ? words.last[0].toUpperCase() : ""; // First letter of last word

    return (firstInitial + lastInitial).isNotEmpty ? (firstInitial + lastInitial) : "A"; // Ensure fallback
  }


  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.05) ?? AppColors.background2, // ✅ Fallback color
      title: Text(
        AppLocalizations.of(context)!.manageAccessRights,
        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.accessRightsFor(widget.relativeName),
              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15.r,
                          backgroundColor: AppColors.main.withOpacity(0.5),
                          child: Text(
                            _getInitials(userName),
                            style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Row(
                            children: [
                              Text(userName.toUpperCase(), style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                              Text(" (${AppLocalizations.of(context)!.you})", style: AppTextStyles.getText2(context)),

                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                  SizedBox(height: 25.h),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(AppLocalizations.of(context)!.thisPersonCan, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 8.h),
                  _buildPermissionItem(AppLocalizations.of(context)!.bookRescheduleCancel, AppLocalizations.of(context)!.allAppointments),
                  _buildPermissionItem(AppLocalizations.of(context)!.addAndManage, AppLocalizations.of(context)!.allDocuments),
                  _buildPermissionItem(AppLocalizations.of(context)!.updateIdentity, AppLocalizations.of(context)!.contactInfo),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
            SizedBox(height: 10.h),

            Center(
              child: TextButton(
                onPressed: _showRemoveConfirmationDialog,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_outlined, color: AppColors.red, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      AppLocalizations.of(context)!.removeThisRelative.toUpperCase(),
                      style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(String text, String boldText) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(Icons.check, color: AppColors.main, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: "$text ",
                style: AppTextStyles.getText3(context),
                children: [
                  TextSpan(
                    text: boldText,
                    style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
