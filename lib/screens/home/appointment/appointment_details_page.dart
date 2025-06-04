import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../app/text_styles.dart';


class AppointmentDetailsPage extends StatelessWidget {

  final Map<String, dynamic> appointment;
  final bool isUpcoming; // 🔹 New flag to differentiate


  const AppointmentDetailsPage({
    Key? key,
    required this.appointment,
    required this.isUpcoming, // Defaults to false (for past appointments)
  }) : super(key: key);


  /// 🔹 Open Google Maps with the given address
  void _openMaps(String address) async {
    String encodedAddress = Uri.encodeComponent(address);
    Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  void _addToCalendar(BuildContext context) {
    DateTime startTime = DateTime.parse(appointment['timestamp']);
    DateTime endTime = startTime.add(Duration(minutes: 30)); // Assuming a 30 min appointment

    final Event event = Event(
      title: 'Appointment with ${appointment['doctorTitle'] ?? ''}${appointment['doctorName'] ?? 'Doctor'}',
      description: 'Reason: ${appointment['reason'] ?? 'No reason provided'}',
      location: "${appointment['clinicAddress']['street'] ?? ''}, ${appointment['clinicAddress']['city'] ?? ''}",
      startDate: startTime,
      endDate: endTime,
      allDay: false,
    );

    // 🔍 Debug prints for terminal
    print("🔗 Adding Event to Calendar:");
    print("📅 Title: ${event.title}");
    print("📄 Description: ${event.description}");
    print("📍 Location: ${event.location}");
    print("🕑 Start Time: ${event.startDate}");
    print("🕑 End Time: ${event.endDate}");
    print("📅 All Day Event: ${event.allDay}");


    Add2Calendar.addEvent2Cal(event).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '📅 Appointment added to your calendar!' : '⚠️ Failed to add appointment.'),
        ),
      );
    });
  }

  void _shareAppointmentDetails() {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    String formattedDate = DateFormat("EEEE, d MMMM yyyy").format(appointmentDate);
    String formattedTime = DateFormat("HH:mm").format(appointmentDate);

    String doctorName = "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? 'Doctor'}".trim();
    Map<String, dynamic> clinicAddress = appointment['clinicAddress'] ?? {};

    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}, "
        "${clinicAddress['city'] ?? ''}, ${clinicAddress['country'] ?? ''}";

    String shareText = """
📅 **Appointment Details**:

👨‍⚕️ Doctor: $doctorName
📍 Location: ${appointment['clinicName'] ?? 'Clinic not specified'}
🏡 Address: $formattedAddress
📅 Date: $formattedDate
🕑 Time: $formattedTime
📝 Reason: ${appointment['reason'] ?? 'No reason provided'}

Shared from DocSera App
""";

    Share.share(shareText, subject: "Appointment with $doctorName");
  }

  void _showFullScreenBottomSheet(BuildContext context, String actionType) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    DateTime now = DateTime.now();
    Duration difference = appointmentDate.difference(now);

    if (difference.inHours <= 48) {
      // ✅ Show the full-screen bottom sheet if within 48 hours
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // ✅ Allows full-screen height
        backgroundColor: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height, // ✅ Full screen height
            child: Padding(
              padding: EdgeInsets.all(16.0.w),
              child: Column(
                children: [
                  // Close Icon
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close, size: 28.sp),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Calendar Image with Warning
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/images/empty_calendar.png',
                        height: 70,
                        width: 70,
                      ),
                      Positioned(
                        bottom: -10,
                        right: -10,
                        child: Icon(
                          Icons.warning_rounded,
                          color: AppColors.yellow.withOpacity(0.8),
                          size: 35,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 25.h),

                  // Main Title
                  Text(
                    actionType == "Reschedule"
                        ? AppLocalizations.of(context)!.rescheduleWarningTitle
                        : AppLocalizations.of(context)!.cancelWarningTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),


                  SizedBox(height: 25.h),

                  // Warning Box
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.yellow.withOpacity(0.8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: Colors.brown, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.appointmentShortNoticeWarning,
                                style: TextStyle(color: Colors.brown, fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                actionType == "Reschedule"
                                    ? AppLocalizations.of(context)!.rescheduleRespectNotice
                                    : AppLocalizations.of(context)!.cancelRespectNotice,
                                style: TextStyle(color: Colors.brown, fontSize: 11.sp, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Continue or Cancel Action
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionType == "Reschedule" ? AppColors.main : AppColors.red,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: actionType == "Reschedule" ? AppColors.main.withOpacity(0.8) : AppColors.red.withOpacity(0.8),
                        content: Text(actionType == "Reschedule"
                            ? AppLocalizations.of(context)!.appointmentRescheduled
                            : AppLocalizations.of(context)!.appointmentCancelled),
                      ));
                    },
                    child: Text(
                        actionType == "Reschedule"
                            ? AppLocalizations.of(context)!.continuing.toUpperCase()
                        : AppLocalizations.of(context)!.cancelAppointmentAction.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                  ),

                  // Keep Appointment Option
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.keepAppointment,
                      style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12.sp),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // ✅ If appointment is more than 48 hours away, proceed directly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionType == "Reschedule"
              ? AppLocalizations.of(context)!.appointmentRescheduleNoWarning
              : AppLocalizations.of(context)!.appointmentCancelNoWarning),
        ),
      );

      // Perform your reschedule or cancel logic here directly
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    String locale = Localizations.localeOf(context).languageCode; // ✅ Get the current locale

// ✅ Format date normally
    String formattedDate = DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate);

// ✅ Ensure 12-hour format with AM/PM
    String formattedTime = DateFormat("h:mm a", locale).format(appointmentDate);


    Map<String, dynamic> clinicAddress = appointment['clinicAddress'] ?? {};

    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}\n"
        "${clinicAddress['city'] ?? ''}\n"
        "${clinicAddress['country'] ?? ''}\n"
        "${clinicAddress['details'] ?? ''}";

    // Create the doctorName variable (handles empty title)
    String doctorName = "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}".trim();
    print("🚀🚀🚀🚀🚀🚀🚀 TEST TEST TEST: '$appointment['doctorId']'");




    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.appointmentDetails,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText, fontSize: 13.sp),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, color: Colors.white,size: 20.sp,),
          onPressed: () {
            _shareAppointmentDetails(); // ✅ Trigger the share
          },
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06), // ✅ يزيد قتامة بنسبة 20%
        ),
        child: SafeArea(
          child: Stack(
            children:[
              Padding(
                padding: EdgeInsets.only(top: 40.h), // Add top padding for sticky header
                child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Information
                    Container(
                      decoration: const BoxDecoration(color: AppColors.background2),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w , vertical: 15.h),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque, // ✅ Makes blank space clickable
                              onTap: () {
                                final doctorId = appointment['doctorId']?.toString() ?? '';

                                print("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");
                                print("💡 Full appointment object: $appointment");

                                if (doctorId.isEmpty) {
                                  print("❌ ERROR: doctorId is missing or empty.");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    fadePageRoute(
                                      DoctorProfilePage(doctorId: doctorId),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.main.withOpacity(0.3),
                                    radius: 20.sp,
                                    backgroundImage: AssetImage(appointment['doctorImage'] ?? 'assets/images/male-doc.png'),
                                  ),
                                  SizedBox(width: 20.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctorName.isNotEmpty ? doctorName : '',
                                      style: AppTextStyles.getText2(context).copyWith(fontSize: 13.sp,fontWeight: FontWeight.bold),
                                      ),

                                      Text(
                                        appointment['specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty,
                                          style: AppTextStyles.getText2(context).copyWith( color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                                ],
                              ),
                            ),
                          ),

                          Divider(color: Colors.grey[200],height: 2.h), // 🔹 Set a fixed height for the divider,

                          // Reason for visit
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 15.h),
                            child: Row(
                              children:  [
                                Icon(Icons.local_hospital_outlined, color: AppColors.main, size: 16.sp),
                                SizedBox(width: 15.w),
                                Expanded(child: Text(appointment['reason'] ?? AppLocalizations.of(context)!.notSpecified,
                                     style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp))),
                              ],
                            ),
                          ),
                          Divider(color: Colors.grey[200],height: 2),

                          // 🔹 Reschedule & Cancel Buttons
                          if (isUpcoming) // Show only for upcoming appointments
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // ✅ Reschedule Button
                                  TextButton.icon(
                                    onPressed: () => _showFullScreenBottomSheet(context, "Reschedule"),
                                    icon: Icon(Icons.edit_calendar_outlined, color: AppColors.main, size: 14.sp,),
                                    label: Text(
                                      AppLocalizations.of(context)!.reschedule,
                                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                                    ),
                                    style: ButtonStyle(
                                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                            (Set<MaterialState> states) {
                                          return Colors.transparent; // ✅ No overlay color on press
                                        },
                                      ),
                                      splashFactory: NoSplash.splashFactory, // ✅ No ripple effect
                                    ),
                                  ),

                                  // ✅ Cancel Appointment Button
                                  TextButton.icon(
                                    onPressed: () => _showFullScreenBottomSheet(context, "Cancel"),

                                    icon: Icon(Icons.cancel_outlined, color: AppColors.red, size: 14.sp,),
                                    label: Text(
                                      AppLocalizations.of(context)!.cancelAppointment,
                                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.red, fontWeight: FontWeight.bold),
                                    ),
                                    style: ButtonStyle(
                                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                            (Set<MaterialState> states) {
                                          return Colors.transparent; // ✅ No overlay color on press
                                        },
                                      ),
                                      splashFactory: NoSplash.splashFactory, // ✅ No ripple effect
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        ],
                      ),
                    ),
                    SizedBox  (height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0.w),
                      child: Column(
                        children: [
                          if (isUpcoming)
                          Card(
                            color: AppColors.background2, // ✅ Light background like in the design
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow to match the UI
                            child: InkWell(
                              onTap: () {
                                // ✅ Navigate to booking screen
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 18.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.file_open_outlined, color: AppColors.main, size: 16.sp),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(context)!.sendDocuments,
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 4.h), // ✅ Adds slight spacing between lines
                                          Text(
                                            AppLocalizations.of(context)!.sendDocumentsSubtitle,
                                            style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.w400, color: Colors.black54),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (isUpcoming) SizedBox  (height: 8.h),

                          Card(
                            color: AppColors.background2, // ✅ Light background like in the design
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow to match the UI
                            child: InkWell(
                              onTap: () {
                                // ✅ Navigate to booking screen
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding:  EdgeInsets.symmetric(vertical: 14.h, horizontal: 18.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Icons.refresh, color: AppColors.main, size: 16.sp),
                                    SizedBox(width: 10.w),
                                    Text(
                                      AppLocalizations.of(context)!.bookAgain,
                                      style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox  (height: 8.h),

                          // Patient Information
                          Card(
                            color: AppColors.background2, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Title "Patient"
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 5),
                                  child: Text(
                                    AppLocalizations.of(context)!.patient,
                                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // 🔹 Patient Name
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: AppColors.main, size: 18.sp),
                                      SizedBox(width: 12.w),
                                      Text(
                                        (appointment['patientName'] ?? "Unknown").toUpperCase(), // ✅ Convert to uppercase
                                          style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🔹 Full-width Divider
                                Divider(height: 1.h,  color: Colors.grey[300]),

                                // 🔹 Share Appointment Button
                                InkWell(
                                  onTap: () {
                                    _shareAppointmentDetails(); // ✅ Trigger the share
                                  },
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12.r),
                                    bottomRight: Radius.circular(12.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, color: AppColors.main, size: 14),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(context)!.shareAppointmentDetails,
                                          style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),                                ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),


                          // Clinic Details
                          SizedBox(height: 8.h),
                          Card(
                            color: AppColors.background2, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Title "Details of the healthcare facility"
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 20, right: 16, bottom: 10),
                                  child: Text(
                                    AppLocalizations.of(context)!.clinicDetails,
                                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // 🔹 Clinic Name & Address
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on, color: AppColors.main, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appointment['clinicName'] ?? AppLocalizations.of(context)!.clinicNotAvailable,
                                              style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              formattedAddress.isNotEmpty ? formattedAddress : AppLocalizations.of(context)!.addressNotEntered,
                                              style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: Colors.black54, fontWeight: FontWeight.w500),
                                            ),

                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🔹 Open Map Button
                                InkWell(
                                  onTap: () => _openMaps("${clinicAddress['street'] ?? ''}, ${clinicAddress['buildingNr'] ?? ''}, ${clinicAddress['city'] ?? ''}, ${clinicAddress['country'] ?? ''}"),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12.r),
                                    bottomRight: Radius.circular(12.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 40.w, right: 40.w, bottom: 20.h),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on, color: AppColors.main, size: 14.sp),
                                        SizedBox(width: 5.w),
                                        Text(
                                            AppLocalizations.of(context)!.openMap,
                                          style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.w600),

                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8.h),

                          // Back to Doctor Profile
                          Card(
                            color: Colors.white, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () => _addToCalendar(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_month_outlined, color: AppColors.main, size: 16.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.addToCalendar,
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.bold),

                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                                Divider(color: Colors.grey[200],height: 2.h), // 🔹 Set a fixed height for the divider
                                InkWell(
                                  // In AppointmentDetailsPage (onTap for navigation)
                                  onTap: () {
                                    final doctorId = appointment['doctorId']?.toString() ?? '';

                                    print("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");

                                    if (doctorId.isEmpty) {
                                      print("❌ ERROR: doctorId is missing or empty.");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        fadePageRoute(
                                          DoctorProfilePage(doctorId: doctorId),
                                        ),
                                      );
                                    }
                                  },

                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.account_box_outlined, color: AppColors.main, size: 16.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.backToDoctorProfile(doctorName),
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.bold),
                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),



                        ],
                      ),
                    ),
                  ],
                ),
                            ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                color: Color.lerp(AppColors.mainDark, Colors.black, 0.3), // ✅ يزيد قتامة بنسبة 20%
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // ✅ Center content
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 14.sp),
                    SizedBox(width: 12.w),
                    Text(
                      formattedDate,
                        style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    SizedBox(width: 25.w),
                    Icon(Icons.access_time, color: Colors.white, size: 14.sp),
                    SizedBox(width: 8.w),
                    Text(
                      formattedTime,
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white),
                    ),

                  ],
                ),
              ),]
          ),
        ),
      ),
    );
  }
}
