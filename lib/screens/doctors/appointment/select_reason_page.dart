import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/doctor_appointments_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utils/full_page_loader.dart';

class SelectReasonPage extends StatefulWidget {
  final PatientProfile patientProfile;
  final AppointmentDetails appointmentDetails;

  const SelectReasonPage({
    Key? key,
    required this.patientProfile,
    required this.appointmentDetails,
  }) : super(key: key);

  @override
  _SelectReasonPageState createState() => _SelectReasonPageState();
}

class _SelectReasonPageState extends State<SelectReasonPage> {
  List<Map<String, dynamic>> reasons = [];
  bool isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  Future<void> _loadReasons() async {
    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('appointment_reasons')
          .select('id,label,created_at')
          .eq('doctor_id', widget.appointmentDetails.doctorId)
          .order('created_at', ascending: true);

      reasons = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      _error = 'load_failed';
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Text(
        l.selectReasonTitle,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.selectReason,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 15.h),

            if (isLoading)
              Center(child: FullPageLoader())
            else if (_error != null)
              Text(l.somethingWentWrong, style: AppTextStyles.getText2(context))
            else if (reasons.isEmpty)
                Text(l.noReasonsFound, style: AppTextStyles.getText2(context))
              else
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(color: Colors.grey.shade200, width: 0.8),
                  ),
                  elevation: 0,
                  child: Column(
                    children: List.generate(reasons.length, (index) {
                      final reason = reasons[index];
                      final isLast = index == reasons.length - 1;

                      return Column(
                        children: [
                          _buildReasonRow(
                            context: context,
                            reasonId: (reason['id'] ?? '') as String,
                            label: (reason['label'] ?? '').toString(),
                          ),
                          if (!isLast)
                            Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
                        ],
                      );
                    }),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonRow({
    required BuildContext context,
    required String reasonId,
    required String label,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            DoctorAppointmentsPage(
              patientProfile: widget.patientProfile.copyWith(reason: label),
              appointmentDetails: widget.appointmentDetails.copyWith(
                reason: label,
                reasonId: reasonId,
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        width: double.infinity,
        child: Text(
          label,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.blackText,
          ),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}
