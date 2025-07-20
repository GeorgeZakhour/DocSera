  import 'dart:async';
  import 'dart:convert';
  import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
  import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
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
    Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
      final bool needsConfirmation = appointment['is_confirmed'] == false && appointment['booked'] == true;

      // ✅ Ensure `timestamp` is a `DateTime` object
      DateTime? appointmentDate;
      if (appointment['timestamp'] is String) {
        appointmentDate = DateTime.tryParse(appointment['timestamp']);
      } else if (appointment['timestamp'] is String) {
        appointmentDate = DateTime.tryParse(appointment['timestamp']);
      } else if (appointment['timestamp'] is DateTime) {
        appointmentDate = appointment['timestamp'];
      }

      // ✅ Ensure `bookingTimestamp` is a `DateTime` object
      DateTime? bookingDate;
      if (appointment['booking_timestamp'] is String) {
        bookingDate = DateTime.tryParse(appointment['booking_timestamp']);
      } else if (appointment['booking_timestamp'] is String) {
        bookingDate = DateTime.tryParse(appointment['booking_timestamp']);
      } else if (appointment['booking_timestamp'] is DateTime) {
        bookingDate = appointment['booking_timestamp'];
      }



      String locale = Localizations.localeOf(context).languageCode; // ✅ Get the current locale

// ✅ Format appointment date & time based on the selected language
      String formattedDate = appointmentDate != null
          ? DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate)
          : AppLocalizations.of(context)!.unknownDate;

      String formattedTime = appointmentDate != null
          ? DateFormat("h:mm a", locale).format(appointmentDate)
          : AppLocalizations.of(context)!.unknownTime;

// ✅ Format booking date
      String formattedBookingDate = bookingDate != null
          ? DateFormat("yyyy-MM-dd  ~  HH:mm", locale).format(bookingDate)
          : AppLocalizations.of(context)!.unknown;

      // ✅ Ensure Patient Name is Retrieved
      String patientName = appointment["patient_name"] ?? "Unknown";

      // ✅ Determine doctor's avatar based on gender & title
      String gender = (appointment['doctor_gender'] ?? '').toLowerCase();
      String title = (appointment['doctor_title'] ?? '').toLowerCase();
      String? doctorImage = appointment['doctor_image'];

      String avatarPath;
      if (doctorImage != null && doctorImage.trim().isNotEmpty) {
        avatarPath = doctorImage; // إذا كانت الصورة موجودة (مسار Asset حقيقي)
      } else {
        avatarPath = (title == "dr.")
            ? (gender == "female" ? 'assets/images/female-doc.png' : 'assets/images/male-doc.png')
            : (gender == "male" ? 'assets/images/male-phys.png' : 'assets/images/female-phys.png');
      }

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8), // ✅ Very thin border
        ),
        color: AppColors.background2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 **Date and Time Bar**
            Container(
              decoration: BoxDecoration(
                color: needsConfirmation ? AppColors.grayMain : AppColors.mainDark,
                borderRadius:  BorderRadius.only(
                  topLeft: Radius.circular(8.r),
                  topRight: Radius.circular(8.r),
                ),
              ),
              padding:  EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 12.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    formattedDate, // ✅ Safe date display
                    style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 12.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    formattedTime, // ✅ Extracted from timestamp
                    style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque, // ✅ Makes blank space clickable
              onTap: () {
                bool isUpcoming = _selectedTab == 0;

                needsConfirmation
                ?
                null
                :
                Navigator.push(
                  context,
                  fadePageRoute(AppointmentDetailsPage(
                    appointment: appointment, // ✅ تمرير كامل البيانات كما هي
                    isUpcoming: isUpcoming,
                  )),
                );
              },
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: needsConfirmation? 8.h : 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // ✅ Doctor Avatar
                            CircleAvatar(
                              radius: needsConfirmation ? 16.r : 20.r,
                              backgroundColor: AppColors.mainDark.withOpacity(0.3),
                              backgroundImage: AssetImage(avatarPath),
                            ),
                            SizedBox(width: 20.w),

                            // ✅ Doctor Name and Specialty
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${appointment["doctor_title"] ?? ""} ${appointment["doctor_name"] ?? "Doctor Unavailable"}".trim(),
                                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  appointment["doctor_specialty"] ?? "General Practice",
                                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.textSubColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                        needsConfirmation
                            ?
                        SizedBox()
                        :
                        Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp)


                      ],
                    ),
                  ),

              Padding(
                padding: EdgeInsets.only(left: 12.w,right: 12.w, bottom: 8.h),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital_outlined,
                        color: needsConfirmation ? AppColors.grayMain : AppColors.main.withOpacity(0.7),
                        size: needsConfirmation ? 12.sp :16.sp),
                    SizedBox(width: 5.w),
                    Text(
                      appointment["reason"] ?? "No reason given",
                      style: AppTextStyles.getText3(context).copyWith(color: AppColors.textSubColor),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),

            /// **🔹 Full-Width Light Gray Divider**
            Divider(color: Colors.grey[200], height: 1.h),

            // 🔹 **Patient Name & Book Again Button**
            Padding(
              padding: needsConfirmation ? EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h)
                  :EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 12.sp, color: AppColors.mainDark),
                          SizedBox(width: 6.w),
                          Text(
                            patientName, // ✅ Show correct patient name
                            style: AppTextStyles.getText3(context).copyWith(color: AppColors.blackText),
                          ),
                        ],
                      ),

                     if (!needsConfirmation) ...[
                      SizedBox(height: 3.h),
                      // ✅ Show Booking Date
                      Row(
                        children: [
                          Icon(Icons.history, size: 10.sp, color: AppColors.grayMain),
                          SizedBox(width: 6.w),
                          Text(
                            AppLocalizations.of(context)!.bookedOn(formattedBookingDate),
                            style: AppTextStyles.getText3(context).copyWith(color: AppColors.grayMain, fontSize: 8 ),
                          ),
                        ],
                      ),
                     ],
                    ],
                  ),
                  needsConfirmation
                      ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.grey),
                      color: Colors.transparent,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.waitingConfirmation,
                      style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                  )
                      :
                  InkWell(
                    onTap: () {
                      // ✅ Navigate to SelectPatientPage to start a new booking for the same doctor
                      Navigator.push(
                        context,
                        fadePageRoute(
                          SelectPatientPage(
                            doctorId: appointment["doctor_id"] ?? "",
                            doctorName: appointment["doctor_name"] ?? "Unknown",
                            doctorTitle: appointment["doctor_title"] ?? "",
                            doctorGender: appointment["doctor_gender"] ?? "",
                            specialty: appointment["doctor_specialty"] ?? "General Practice",
                            image: appointment["doctor_image"] ?? "assets/images/male-doc.png",
                            clinicName: appointment['clinicName'] ?? "Unknown Clinic",
                            clinicAddress: appointment['clinic_address'] ?? {}, // ✅ Pass empty map if null
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.refresh, color: AppColors.main, size: 14.sp),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.bookAgain,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.main,fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }


