import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/home/messages/write_message_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utils/full_page_loader.dart';

class SelectMessageReasonPage extends StatefulWidget {
  final String doctorId; // ✅ نضيف doctorId لنعمل query
  final String doctorName;
  final ImageProvider doctorImage;
  final String doctorImageUrl;
  final String doctorSpecialty;
  final PatientProfile patientProfile;
  final UserDocument? attachedDocument;

  const SelectMessageReasonPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorImage,
    required this.doctorImageUrl,
    required this.doctorSpecialty,
    required this.patientProfile,
    this.attachedDocument,
  });

  @override
  State<SelectMessageReasonPage> createState() => _SelectMessageReasonPageState();
}

class _SelectMessageReasonPageState extends State<SelectMessageReasonPage> {
  List<Map<String, dynamic>> _reasons = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctorReasons();
  }

  Future<void> _fetchDoctorReasons() async {
    try {
      final response = await Supabase.instance.client
          .from('message_reasons')
          .select('id, label')
          .eq('doctor_id', widget.doctorId)
          .order('order_index', ascending: true);

      setState(() {
        _reasons = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Failed to fetch reasons: $e");
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image(
                image: widget.doctorImage,
                width: 40.w,
                height: 40.h,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                local.sendMessage,
                style: AppTextStyles.getText2(context)
                    .copyWith(fontSize: 12.sp, color: AppColors.whiteText),
              ),
              Text(
                widget.doctorName,
                style: AppTextStyles.getTitle2(context)
                    .copyWith(fontSize: 14.sp, color: AppColors.whiteText),
              ),
            ],
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                local.selectMessageReason,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                local.noEmergencySupport,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp),
              ),
              SizedBox(height: 20.h),
              _isLoading
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40.h),
                  child: const FullPageLoader(),
                ),
              )
                  : _hasError
                  ? _buildErrorWidget(local)
                  : _reasons.isEmpty
                  ? _buildEmptyWidget(local)
                  : _buildReasonsList(context, local),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(AppLocalizations local) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          local.failedToLoadReasons,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(AppLocalizations local) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          local.noReasonsAddedByDoctor,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildReasonsList(BuildContext context, AppLocalizations local) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      child: Column(
        children: List.generate(_reasons.length, (index) {
          final reason = _reasons[index];
          final label = reason['label'] ?? '';
          final reasonId = reason['id'] ?? '';

          return Column(
            children: [
              if (index > 0)
                Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
              _buildReasonTile(context, label, reasonId),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildReasonTile(BuildContext context, String label, String reasonId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            WriteMessagePage(
              doctorName: widget.doctorName,
              doctorImage: widget.doctorImage,
              doctorImageUrl: widget.doctorImageUrl,
              doctorSpecialty: widget.doctorSpecialty,
              selectedReason: label,
              patientProfile: widget.patientProfile.copyWith(reason: label),
              attachedDocument: widget.attachedDocument,
            ),
          ),
        );
        print("✅ Selected reason: $label (ID: $reasonId)");
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        width: double.infinity,
        child: Text(
          label,
          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
