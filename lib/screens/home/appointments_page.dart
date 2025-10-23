  import 'dart:async';
  import 'dart:convert';
import 'dart:ui';
  import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
  import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/time_utils.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
  import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
  import 'package:docsera/screens/home/appointment/appointment_details_page.dart';
  import 'package:docsera/screens/search_page.dart';
  import 'package:docsera/utils/page_transitions.dart';
  import 'package:docsera/utils/shared_prefs_service.dart';
  import 'package:flutter/material.dart';
  import 'package:docsera/app/const.dart';
  import 'package:intl/intl.dart';
  import 'package:flutter_screenutil/flutter_screenutil.dart';
  import 'package:docsera/app/text_styles.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:docsera/screens/auth/identification_page.dart';

  class AppointmentsPage extends StatefulWidget {
    const AppointmentsPage({Key? key}) : super(key: key);

    @override
    _AppointmentsPageState createState() => _AppointmentsPageState();
  }

  class _AppointmentsPageState extends State<AppointmentsPage> {
    int? _selectedTab; // ✅ Nullable until loaded
    int visibleAppointmentsCount = 5; // ✅ Initially show 5 appointments
    bool _isLoading = true; // ✅ Prevent flickering issue



    @override
    void initState() {
      super.initState();
      _loadLastSelectedTab(); // ✅ Load the last selected tab from SharedPreferences
      // _checkLoginStatus();
      context.read<AppointmentsCubit>().loadAppointments(context);
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
    }

    @override
    void dispose() {
      super.dispose();
    }

    /// ✅ **Load last selected tab from SharedPreferences**
    void _loadLastSelectedTab() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int lastTab = prefs.getInt('selectedAppointmentsTab') ?? 0;
      setState(() {
        _selectedTab = lastTab;
        _isLoading = false; // ✅ Prevent flickering by waiting until the tab is set
      });
    }

    /// ✅ **Save last selected tab**
    Future<void> _saveLastSelectedTab(int tabIndex) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedAppointmentsTab', tabIndex);
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background3,
        body: Column(
          children: [
            // ✅ Always visible top bar with tab selection
            Container(
              color: AppColors.main,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton(AppLocalizations.of(context)!.upcomingAppointments, 0),
                  _buildTabButton(AppLocalizations.of(context)!.pastAppointments, 1),
                ],
              ),
            ),

            // ✅ BlocListener to prevent flickering when switching tabs
            BlocListener<AppointmentsCubit, AppointmentsState>(
              listener: (context, state) {
                if (state is AppointmentsLoaded) {
                  // ✅ Only update if the selected tab has changed
                  if (_selectedTab != state.selectedTab) {
                    setState(() {
                      _selectedTab = state.selectedTab;
                    });
                  }
                }
              },
              child: Expanded(
                child: BlocBuilder<AppointmentsCubit, AppointmentsState>(
                  buildWhen: (previous, current) => current is! AppointmentsLoading,
                  builder: (context, state) {
                    if (_isLoading) return _buildShimmerLoading(); // ✅ Prevent flickering

                    else if (state is NotLoggedIn) {
                      return _buildLoginPrompt(context);
                    } else if (state is AppointmentsLoading) {
                      return _buildShimmerLoading();
                    } else if (state is AppointmentsLoaded) {
                      return _buildAppointmentsView(context, state);
                    } else if (state is AppointmentsError) {
                      return Center(
                        child: Text("Error: ${state.message}", style: TextStyle(color: Colors.red)),
                      );
                    }
                    return const Center(child: Text("Unexpected error"));
                  },
                ),
              ),
            ),
          ],
        ),

        // ✅ Floating Action Button
        floatingActionButton: BlocBuilder<AppointmentsCubit, AppointmentsState>(
          builder: (context, state) {
            if (state is! NotLoggedIn) {
              return FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    fadePageRoute(const SearchPage(mode: "search",)),
                  );
                },
                icon: Icon(Icons.calendar_today, color: AppColors.whiteText, size: 16.sp),
                label: Text(
                  AppLocalizations.of(context)!.bookAppointment,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText, fontWeight: FontWeight.bold),
                ),
                elevation: 0,
                backgroundColor: AppColors.main,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.r),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      );
    }

    Widget _buildShimmerLoading() {
      return ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.w,horizontal: 16.w),
        itemCount: 5, // ✅ Display 3 shimmer placeholders
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: ShimmerWidget(
              width: double.infinity,
              height: 140.h, // ✅ Adjust size to match the appointment cards
              radius: 12.r,
            ),
          );
        },
      );
    }

    /// 🔹 **Appointments View with Load More Feature**
    Widget _buildAppointmentsView(BuildContext context, AppointmentsLoaded state) {
      final appointments = _selectedTab == 0 ? state.upcomingAppointments : state.pastAppointments;
      int maxVisible = visibleAppointmentsCount.clamp(0, appointments.length);

      return Column(
        children: [
          Expanded(
            child: appointments.isNotEmpty
                ? ListView.builder(
              padding: EdgeInsets.only(top: 8.w, left: 16.w, right: 16.w, bottom: 75.h),
              itemCount: maxVisible + 1,
              itemBuilder: (context, index) {
                if (index < maxVisible) {
                  return _buildAppointmentCard(appointments[index]);
                } else {
                  return _buildLoadMoreButton(appointments.length);
                }
              },
            )
                : _buildEmptyState(),
          ),
        ],
      );
    }

    /// **🔹 Load More Button**
    Widget _buildLoadMoreButton(int totalAppointments) {
      if (visibleAppointmentsCount >= totalAppointments) return const SizedBox(); // ✅ Hide if all are shown

      return Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              visibleAppointmentsCount += 3; // ✅ Load 3 more each time
            });
          },
          child: Text(
            AppLocalizations.of(context)!.loadMoreAppointments,
            style: AppTextStyles.getText3(context).copyWith(
              color: AppColors.main,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    /// 🔹 **Login Prompt (Fixed)**
    Widget _buildLoginPrompt(BuildContext context) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/empty_calendar.png", height: 100.h),
            SizedBox(height: 20.h),
            Text(
              AppLocalizations.of(context)!.planAppointments,
              style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark),
            ),
            SizedBox(height: 8.h),
            Text(
              AppLocalizations.of(context)!.planAppointmentsDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, fadePageRoute(const IdentificationPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
              ),
              child: Text(
                AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getText1(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    /// 🔹 **Empty State when no appointments**
    Widget _buildEmptyState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/empty_calendar.png", height: 100),
            SizedBox(height: 20.h),
            Text(
              _selectedTab == 0
                  ? AppLocalizations.of(context)!.noUpcomingAppointments
                  : AppLocalizations.of(context)!.noPastAppointments,
              style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.grayMain),
            ),
            SizedBox(height: 8.h),
            Text(
                AppLocalizations.of(context)!.noAppointmentsDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    /// 🔹 **Tab Button with Immediate Selection**
    Widget _buildTabButton(String title, int index) {
      bool isSelected = _selectedTab == index;
      return Expanded(
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTab = index;
              visibleAppointmentsCount = 5;
            });
            _saveLastSelectedTab(index);
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  title,
                  style: AppTextStyles.getTitle1(context).copyWith(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: 4.h),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 60.w : 0,
                  height: isSelected ? 3.h : 0,
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      );
    }

    /// 🔹 **Appointment Card**
    Widget _buildAppointmentCard(Map<String, dynamic> appt) {
      final bool needsConfirmation = appt['is_confirmed'] == false && appt['booked'] == true;
      final bool isRejected = (appt['is_confirmed'] == true && appt['booked'] == false && appt['status']?.toString() == 'rejected');

      final tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();
      final bookingTs = appt['booking_timestamp'] != null
          ? DateTime.tryParse(appt['booking_timestamp'].toString())?.toUtc()
          : null;

// ✅ التاريخ والوقت في توقيت دمشق
      final formattedDate = TimezoneUtils.formatBusinessDate(context, appt);
      final formattedTime = TimezoneUtils.format12hLocalized(context, tsUtc);

      final locale = Localizations.localeOf(context).toString();
      final formattedBookingDate = bookingTs != null
          ? DateFormat("yyyy-MM-dd  ~  HH:mm", locale)
          .format(TimezoneUtils.toDamascus(bookingTs))
          : AppLocalizations.of(context)!.unknown;


      // ✅ Patient name (camel + snake)
      final patientName = (appt["patientName"] ?? appt["patient_name"] ?? "").toString();

      // ✅ Doctor info
      final doctorName = "${(appt["doctor_title"] ?? appt["doctorTitle"] ?? "")} ${(appt["doctor_name"] ?? appt["doctorName"] ?? "Doctor")}".trim();
      final specialty = (appt["specialty"] ?? appt["doctor_specialty"] ?? AppLocalizations.of(context)!.unknownSpecialty).toString();

      DoctorImageResult imageResult = resolveDoctorImagePathAndWidget(
        doctor: {
          "doctor_image": appt['doctor_image'] ?? appt['doctorImage'],
          "gender": appt['doctor_gender'] ?? appt['doctorGender'],
          "title": appt['doctor_title'] ?? appt['doctorTitle'],
        },
        width: needsConfirmation || isRejected ? 32 : 40,
        height: needsConfirmation || isRejected ? 32 : 40,
      );

      print("🖼️ AppointmentCard RAW doctor_image = ${appt['doctor_image'] ?? appt['doctorImage']}");
      print("🖼️ Resolved avatarPath = ${imageResult.avatarPath}");


      final imageProvider = imageResult.imageProvider;

      return Container(
        margin: EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25.r),
          child: Stack(
            children: [
              // ✨ 1️⃣ tinted background layer (below glass)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isRejected
                        ? AppColors.red.withOpacity(0.09)
                        : (needsConfirmation
                        ? AppColors.grayMain.withOpacity(0.12)
                        : AppColors.main.withOpacity(0.12)),
                  ),
                ),
              ),

              // 🧊 2️⃣ frosted glass layer
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45), // frosted white blend
                    borderRadius: BorderRadius.circular(25.r),
                    border: Border.all(
                      color: isRejected
                          ? AppColors.red.withOpacity(0.4)
                          : (needsConfirmation
                          ? AppColors.grayMain.withOpacity(0.4)
                          : AppColors.main.withOpacity(0.45)),
                      width: 1.3,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: (needsConfirmation || isRejected) ? 10.h : 16.h,
                  ),

                  // 🩺 Card content
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🕓 Date & Time Row
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13.sp,
                            color: isRejected
                                ? AppColors.red
                                : (needsConfirmation
                                ? AppColors.grayMain
                                : AppColors.mainDark),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            formattedDate,
                            style: AppTextStyles.getText3(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: isRejected
                                  ? AppColors.red
                                  : (needsConfirmation
                                  ? AppColors.grayMain
                                  : AppColors.mainDark),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time_rounded,
                            size: 13.sp,
                            color: isRejected
                                ? AppColors.red
                                : (needsConfirmation
                                ? AppColors.grayMain
                                : AppColors.mainDark),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            formattedTime,
                            style: AppTextStyles.getText3(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: isRejected
                                  ? AppColors.red
                                  : (needsConfirmation
                                  ? AppColors.grayMain
                                  : AppColors.mainDark),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: (needsConfirmation || isRejected) ? 8.h : 14.h),

                      // 👨‍⚕️ Doctor Info
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!needsConfirmation && !isRejected) {
                            Navigator.push(
                              context,
                              fadePageRoute(AppointmentDetailsPage(
                                appointment: appt,
                                isUpcoming: _selectedTab == 0,
                              )),
                            );
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: (needsConfirmation || isRejected) ? 18.r : 22.r,
                              backgroundColor: Colors.white.withOpacity(0.6),
                              backgroundImage: imageProvider,
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doctorName,
                                    style: AppTextStyles.getText2(context).copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isRejected
                                          ? Colors.grey.shade700
                                          : AppColors.mainDark,
                                    ),
                                  ),
                                  Text(
                                    specialty,
                                    style: AppTextStyles.getText3(context).copyWith(
                                      color: AppColors.textSubColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!needsConfirmation && !isRejected)
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.grey.shade400, size: 15.sp),
                          ],
                        ),
                      ),

                      SizedBox(height: (needsConfirmation || isRejected) ? 6.h : 12.h),

                      // 🏥 Reason
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            color: isRejected
                                ? AppColors.red
                                : (needsConfirmation
                                ? AppColors.grayMain
                                : AppColors.main.withOpacity(0.8)),
                            size: (needsConfirmation || isRejected) ? 13.sp : 15.sp,
                          ),
                          SizedBox(width: 5.w),
                          Flexible(
                            child: Text(
                              appt["reason"]?.toString() ??
                                  AppLocalizations.of(context)!.notSpecified,
                              style: AppTextStyles.getText3(context)
                                  .copyWith(color: AppColors.textSubColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      Divider(
                        color: Colors.grey.withOpacity(0.22),
                        height: (needsConfirmation || isRejected) ? 14.h : 20.h,
                      ),

                      // 👤 Patient + Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Patient info
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person,
                                      size: 12.sp, color: AppColors.mainDark),
                                  SizedBox(width: 6.w),
                                  Text(
                                    patientName,
                                    style: AppTextStyles.getText3(context).copyWith(
                                      color: isRejected
                                          ? Colors.grey.shade700
                                          : AppColors.mainDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (!needsConfirmation && !isRejected)
                                Padding(
                                  padding: EdgeInsets.only(top: 3.h),
                                  child: Row(
                                    children: [
                                      Icon(Icons.history,
                                          size: 10.sp, color: AppColors.grayMain),
                                      SizedBox(width: 5.w),
                                      Text(
                                        AppLocalizations.of(context)!
                                            .bookedOn(formattedBookingDate),
                                        style: AppTextStyles.getText3(context)
                                            .copyWith(
                                            color: AppColors.grayMain,
                                            fontSize: 8),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          // 🏷️ Status Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical:
                              (needsConfirmation || isRejected) ? 4.h : 6.h,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isRejected
                                    ? AppColors.red.withOpacity(0.7)
                                    : (needsConfirmation
                                    ? AppColors.grayMain.withOpacity(0.7)
                                    : AppColors.main.withOpacity(0.7)),
                                width: 1,
                              ),
                              color: isRejected
                                  ? AppColors.red.withOpacity(0.06)
                                  : (needsConfirmation
                                  ? AppColors.grayMain.withOpacity(0.06)
                                  : AppColors.main.withOpacity(0.08)),
                            ),
                            child: Text(
                              isRejected
                                  ? AppLocalizations.of(context)!.statusRejected
                                  : (needsConfirmation
                                  ? AppLocalizations.of(context)!
                                  .waitingConfirmation
                                  : AppLocalizations.of(context)!
                                  .appointmentConfirmed),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: isRejected
                                    ? AppColors.red
                                    : (needsConfirmation
                                    ? AppColors.grayMain
                                    : AppColors.mainDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
  }


