
  import 'dart:async';
  import 'dart:convert';
  import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
  import 'package:flutter/material.dart';
  import 'package:docsera/app/const.dart';
  import 'package:flutter_screenutil/flutter_screenutil.dart';
  import 'package:share_plus/share_plus.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'package:url_launcher/url_launcher.dart';
  import 'package:docsera/gen_l10n/app_localizations.dart';
  import 'package:docsera/app/text_styles.dart';




  class DoctorProfilePage extends StatefulWidget {
    final String doctorId; // ✅ Make non-nullable
    final Map<String, dynamic>? doctor;

    const DoctorProfilePage({
      Key? key,
      required this.doctorId,
      this.doctor,
    }) : super(key: key);

    @override
    _DoctorProfilePageState createState() => _DoctorProfilePageState();
  }



  class _DoctorProfilePageState extends State<DoctorProfilePage> {
    bool _showAppBar = false;
    bool _isFavorite = false;
    final ScrollController _scrollController = ScrollController();
    RealtimeChannel? _doctorChannel;
    Map<String, dynamic>? _doctorData;



    @override
    void initState() {
      super.initState();
      _scrollController.addListener(_onScroll);
      print("🩺 DoctorProfilePage INIT - doctorId: ${widget.doctorId}");
      // Use passed doctor data if available
      if (widget.doctor != null && widget.doctor!.isNotEmpty) {
        _doctorData = {...widget.doctor!};
      }
      _loadFavoriteStatus(); // ✅ Load favorite status from Firestore
      _loadDoctorProfile();
    }


    @override
    void dispose() {
      _doctorChannel?.unsubscribe(); // ✅ إلغاء الاشتراك
      _scrollController.dispose();
      super.dispose();
    }


    Future<void> _loadDoctorProfile() async {
      if (widget.doctorId.isEmpty) {
        print("❌ Error: Doctor ID is missing in DoctorProfilePage.");
        return;
      }

      print("✅ Loading Doctor Profile for ID: ${widget.doctorId}");
      final prefs = await SharedPreferences.getInstance();
      final String doctorId = widget.doctorId.trim();

      // ✅ Use passed doctor data if available
      if (widget.doctor != null && widget.doctor!.isNotEmpty) {
        print("⚡ Using Passed Doctor Data for ID: $doctorId (FIRST CASE)");
        setState(() {
          _doctorData = Map<String, dynamic>.from(widget.doctor!);
        });
      } else {
        // ✅ Check for cached doctor data
        String? cachedData = prefs.getString('doctor_$doctorId');
        if (cachedData != null) {
          Map<String, dynamic> cachedDoctor = json.decode(cachedData);
          print("⚡ Loaded Cached Doctor Data: ${cachedDoctor['first_name']} ${cachedDoctor['last_name']} (SECOND CASE)");

          setState(() {
            _doctorData = {...cachedDoctor};
          });
        }
      }


      try {
        // ✅ Fetch fresh doctor data from Supabase
        final response = await Supabase.instance.client
            .from('doctors')
            .select()
            .eq('id', doctorId)
            .maybeSingle();

        if (response != null) {
          print("📥 Loaded Fresh Doctor from Supabase: ${response['first_name']} ${response['last_name']} (THIRD CASE)");

          // ✅ Cache it
          await prefs.setString('doctor_$doctorId', json.encode(response));

          // ✅ Update UI
          setState(() {
            _doctorData = {...response};
          });
        } else {
          print("❌ Doctor not found in Supabase.");
        }

        // ✅ Setup realtime updates from Supabase
        final client = Supabase.instance.client;

        _doctorChannel = client
            .channel('public:doctors:profile')
            .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'doctors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.doctorId,
          ),
          callback: (payload) async {
            final updatedDoctor = payload.newRecord;
            print("📡 Supabase Realtime Update: $updatedDoctor");

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('doctor_${widget.doctorId}', json.encode(updatedDoctor));

            if (mounted) {
              setState(() {
                _doctorData = updatedDoctor;
              });
            }
          },
        )
            .subscribe();

      } catch (e) {
        print("❌ Error loading doctor from Supabase: $e");
      }
    }

    // // ✅ Function to Convert Firestore Timestamps to Milliseconds
    // void convertTimestamps(dynamic data) {
    //   if (data is Map<String, dynamic>) {
    //     data.forEach((key, value) {
    //       if (value is Timestamp) {
    //         data[key] = value.millisecondsSinceEpoch;
    //         print("✅ Converted $key Timestamp to milliseconds: ${data[key]}");
    //       } else if (value is Map<String, dynamic> || value is List) {
    //         convertTimestamps(value); // Recursive call for nested fields
    //       }
    //     });
    //   } else if (data is List) {
    //     for (int i = 0; i < data.length; i++) {
    //       if (data[i] is Timestamp) {
    //         data[i] = (data[i] as Timestamp).millisecondsSinceEpoch;
    //         print("✅ Converted List Timestamp to milliseconds: ${data[i]}");
    //       } else if (data[i] is Map<String, dynamic> || data[i] is List) {
    //         convertTimestamps(data[i]); // Recursive call for nested fields
    //       }
    //     }
    //   }
    // }

  // ✅ Share Doctor Profile Function
    void _shareDoctorProfile() {
      bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

      String doctorName = "${_doctorData?['first_name']} ${_doctorData?['last_name']}";
      String specialty = _doctorData?['specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty;
      String clinic = _doctorData?['clinic'] ?? AppLocalizations.of(context)!.clinicNotAvailable;
      Map<String, dynamic>? address = _doctorData?['address'];
      String fullAddress = address != null
          ? "${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['country'] ?? ''}"
          : AppLocalizations.of(context)!.addressNotEntered;

      // ✅ اختيار النص بناءً على اللغة
      String shareText = isArabic
          ? """
  👨‍⚕️ الطبيب: $doctorName
  💼 التخصص: $specialty
  🏥 العيادة: $clinic
  📍 العنوان: $fullAddress
  📞 الاتصال: ${_doctorData?['phone_number'] ?? AppLocalizations.of(context)!.notProvided}
  
  اكتشف هذا الطبيب على تطبيق DocSera!
  """
          : """
  👨‍⚕️ Doctor: $doctorName
  💼 Specialty: $specialty
  🏥 Clinic: $clinic
  📍 Address: $fullAddress
  📞 Contact: ${_doctorData?['phone_number'] ?? AppLocalizations.of(context)!.notProvided}
  
  Check out this doctor on the DocSera App!
  """;

      Share.share(shareText, subject: isArabic ? "ملف الطبيب - $doctorName" : "Doctor Profile - $doctorName");

      print("📤 Shared Doctor Profile as Text in ${isArabic ? "Arabic" : "English"}");
    }


    void _onScroll() {
      double offset = _scrollController.offset;
      double triggerOffset = MediaQuery.of(context).size.height * 0.25 - kToolbarHeight; // Adjust based on height

      if (offset >= triggerOffset && !_showAppBar) {
        setState(() => _showAppBar = true);
      } else if (offset < triggerOffset && _showAppBar) {
        setState(() => _showAppBar = false);
      }
    }
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
    /// 🔹 Open phone dialer when clicking the phone number
    void _makePhoneCall(String phoneNumber) async {
      final Uri phoneUri = Uri.parse("tel:$phoneNumber");
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }

    void _showLocationDetails(String? clinic, String? street, String? buildingNr, String? city, String? country, String? details) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Title
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.location,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 16.h),

                // ✅ Clinic Name
                if (clinic != null)
                  Text(
                    clinic,
                    style: AppTextStyles.getTitle1(context),
                  ),

                // ✅ Address Lines
                if (street != null)
                  Text(buildingNr != null ? "$street, $buildingNr" : street,
                    style: AppTextStyles.getText2(context),
                  ),
                if (city != null && country != null)
                  Text("$city, $country",
                    style: AppTextStyles.getText2(context),
                  ),

                SizedBox(height: 12.h),

                // ✅ Static Map (Tap to Open Google Maps)
                GestureDetector(
                  onTap: () => _openMaps("$street, $buildingNr, $city, $country"),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.mainDark, width: 2),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/static_map.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map, color: AppColors.mainDark, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(AppLocalizations.of(context)!.openInMaps,
                                style: AppTextStyles.getText2(context),
          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ✅ Additional Information Section
                if (details != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        AppLocalizations.of(context)!.additionalInformation,
                        style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6.h),

                      // Information Box
                      Container(
                        padding:  EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.background3,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppColors.main.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp), // Changed color
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                details,
                                style: AppTextStyles.getText2(context).copyWith( color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    void _showProfileDetails(String? profileDescription, List<String>? specialties, String? website) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background2,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Fixed Title (Removed the line below)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.profile,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                    ),
                  ),
                ),

                // ✅ Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h), // Increased horizontal margin
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Full Profile Description
                        if (profileDescription != null && profileDescription.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Text(
                              profileDescription,
                              style: AppTextStyles.getText1(context),
                            ),
                          ),

                        SizedBox(height: 16.h),

                        // ✅ Specialties & Procedures (All inside bottom sheet)
                        if (specialties != null && specialties.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.specialtiesProcedures,
                                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold, color: AppColors.mainDark),
                              ),
                              SizedBox(height: 15.h),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: specialties.map((specialty) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.main.withOpacity(0.2), // Background color
                                      borderRadius: BorderRadius.circular(20.r), // Increased border radius
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    child: Text(
                                      specialty,
                                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                              ),



                            ],
                          ),

                        SizedBox(height: 16.h),

                        // ✅ Website Link
                        if (website != null && website.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.website,
                                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _openWebsite(website),
                                child: Text(
                                  AppLocalizations.of(context)!.openWebsite,
                                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp, color: AppColors.main, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    /// 🔹 Open Website in Browser
    void _openWebsite(String url) async {
      Uri websiteUri = Uri.parse(url);
      if (await canLaunchUrl(websiteUri)) {
        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    }

    Widget _buildLocationSection(String? street, String? buildingNr, String? city, String? country, String? addressDetails,Map<String, dynamic>? address, String? clinic) {
      return Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8), // ✅ Very thin border
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Title Row with "View More" Text and Arrow
              GestureDetector(
                onTap: () => _showLocationDetails(clinic, street, buildingNr, city, country, addressDetails),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, color: AppColors.mainDark, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          AppLocalizations.of(context)!.location,
                          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                    if (address != null)
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.viewMore,
                            style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                          ),
                          Icon(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? Icons.keyboard_arrow_left  // عند اختيار العربية، يظهر السهم إلى اليسار
                                : Icons.keyboard_arrow_right, // عند اختيار الإنجليزية، يظهر السهم إلى اليمين
                            color: AppColors.main,
                            size: 18.sp,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // ✅ Exact Address (Without Icon)
              // ✅ Clinic Name (Bold)
              if (clinic != null && clinic.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 2.h, right: 4.w, left: 4.w),
                  child: Text(
                    clinic,
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),

  // ✅ Address Line 1 (Street + Building Number)
              if (street != null)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    buildingNr != null ? "$street, $buildingNr" : street,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                  ),
                ),

  // ✅ Address Line 2 (City, Country)
              if (city != null && country != null)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    "$city, $country",
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget _buildProfileSection(String? profileDescription, List<String>? specialties, String? website) {
      List<String> visibleSpecialties = [];
      String moreSpecialties = '';

      if (specialties != null && specialties.isNotEmpty) {
        if (specialties.length > 3) {
          visibleSpecialties = specialties.take(3).toList();
          moreSpecialties = "+${specialties.length - 3}";
        } else {
          visibleSpecialties = specialties;
        }
      }

      return Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8), // ✅ Very thin border
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Title with View More
              GestureDetector(
                onTap: () => _showProfileDetails(profileDescription, specialties, website),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: AppColors.mainDark, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          AppLocalizations.of(context)!.profile,
                          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                    if (profileDescription != null && profileDescription.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.viewMore,
                            style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                          ),
                          Icon(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? Icons.keyboard_arrow_left  // عند اختيار العربية، يظهر السهم إلى اليسار
                                : Icons.keyboard_arrow_right, // عند اختيار الإنجليزية، يظهر السهم إلى اليمين
                            color: AppColors.main,
                            size: 18.sp,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // ✅ Profile Short Description
              if (profileDescription != null && profileDescription.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h,right: 4.w, left: 4.w),
                  child: Text(
                    profileDescription.length > 100 ? "${profileDescription.substring(0, 100)}..." : profileDescription,
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.black87),
                  ),
                ),

              SizedBox(height: 8.h),

              // ✅ Specialties Preview (Max 3 + More Indicator)
              if (specialties != null && specialties.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ...visibleSpecialties.map((specialty) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.main.withOpacity(0.2), // Background color
                          borderRadius: BorderRadius.circular(20.r), // Increased border radius
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        child: Text(
                          specialty,
                            style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w500),
                        ),
                      );
                    }),
                    if (moreSpecialties.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.main.withOpacity(0.2), // Subtle background
                          borderRadius: BorderRadius.circular(20.r), // Increased border radius
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        child: Text(
                          moreSpecialties,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),

            ],
          ),
        ),
      );
    }

    /// **🔹 Combined Card for Contact Info, Opening Hours & Languages**
    Widget _buildInfoSection(String? phoneNumber, Map<String, dynamic> openingHours, List<dynamic> languages) {
      return Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8), // ✅ Very thin border
        ),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// **🔹 Contact Information Section**
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.w, 12.w, 0),
              child: GestureDetector(
                onTap: () => _showContactDetails(phoneNumber),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, color: AppColors.mainDark, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          AppLocalizations.of(context)!.contactInformation,
                          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.viewMore,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? Icons.keyboard_arrow_left  // عند اختيار العربية، يظهر السهم إلى اليسار
                              : Icons.keyboard_arrow_right, // عند اختيار الإنجليزية، يظهر السهم إلى اليمين
                          color: AppColors.main,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// **🔹 Full-Width Light Gray Divider**
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5.h),
              child: Divider(color: Colors.grey[200], thickness: 1),
            ),

            /// **🔹 Opening Hours Section**
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 0),
              child: GestureDetector(
                onTap: () => _showOpeningHoursDetails(openingHours),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: AppColors.mainDark, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          AppLocalizations.of(context)!.openingHours,
                          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.viewMore,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? Icons.keyboard_arrow_left  // عند اختيار العربية، يظهر السهم إلى اليسار
                              : Icons.keyboard_arrow_right, // عند اختيار الإنجليزية، يظهر السهم إلى اليمين
                          color: AppColors.main,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// **🔹 Full-Width Light Gray Divider**
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5.h),
              child: Divider(color: Colors.grey[200], thickness: 1),
            ),

            /// **🔹 Languages Section**
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12),
              child: GestureDetector(
                onTap: () => _showLanguagesDetails(languages),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.language, color: AppColors.mainDark, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          AppLocalizations.of(context)!.languagesSpoken,
                          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.viewMore,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? Icons.keyboard_arrow_left  // عند اختيار العربية، يظهر السهم إلى اليسار
                              : Icons.keyboard_arrow_right, // عند اختيار الإنجليزية، يظهر السهم إلى اليمين
                          color: AppColors.main,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    /// **🔹 Show Contact Information in a Bottom Sheet**
    void _showContactDetails(String? phoneNumber) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Title
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.contactInformation,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 25.h),

                // ✅ Phone Number
                if (phoneNumber != null)
                  GestureDetector(
                    onTap: () => _makePhoneCall(phoneNumber),
                    child: Row(
                      children: [
                        Icon(Icons.call, color: AppColors.main, size: 16.sp),
                        SizedBox(width: 10.w),
                        Text(
                          phoneNumber,
                            style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 25.h),
              ],
            ),
          );
        },
      );
    }
    /// **Displays opening hours in a neat format inside the bottom sheet**
    void _showOpeningHoursDetails(Map<String, dynamic> openingHours) {
      // ✅ تحديد اللغة الحالية
      bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

      // ✅ خريطة تحتوي على أسماء الأيام باللغتين
      Map<String, String> daysMap = {
        "Monday": isArabic ? "الإثنين" : "Monday",
        "Tuesday": isArabic ? "الثلاثاء" : "Tuesday",
        "Wednesday": isArabic ? "الأربعاء" : "Wednesday",
        "Thursday": isArabic ? "الخميس" : "Thursday",
        "Friday": isArabic ? "الجمعة" : "Friday",
        "Saturday": isArabic ? "السبت" : "Saturday",
        "Sunday": isArabic ? "الأحد" : "Sunday",
      };

      List<String> days = daysMap.keys.toList();
      String currentDay = days[DateTime.now().weekday - 1]; // ✅ تحديد اليوم الحالي

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ العنوان
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.openingHours,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 25.h),

                // ✅ قائمة ساعات العمل
                Column(
                  children: days.map((day) {
                    List<dynamic>? slots = openingHours[day] as List<dynamic>?;
                    String formattedHours = (slots != null && slots.isNotEmpty)
                        ? _formatOpeningHours(slots)
                        : AppLocalizations.of(context)!.closed;

                    bool isToday = (day == currentDay); // ✅ هل اليوم هو اليوم الحالي؟

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ اسم اليوم
                          Text(
                            daysMap[day] ?? day, // ✅ عرض الاسم باللغتين
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? AppColors.main : Colors.black87,
                            ),
                          ),

                          // ✅ توقيت العمل
                          Text(
                            formattedHours,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isToday ? AppColors.main : Colors.black87,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 25.h),
              ],
            ),
          );
        },
      );
    }

    /// **Formats opening hours correctly in 24-hour format**
    String _formatOpeningHours(List<dynamic> slots) {
      if (slots.isEmpty) return "Closed";

      // Convert each slot into a properly formatted string
      List<String> sortedSlots = slots.map((slot) {
        Map<String, dynamic> slotMap = slot as Map<String, dynamic>; // Ensure it's a Map
        String fromTime = _convertTo24Hour(slotMap["from"]!);
        String toTime = _convertTo24Hour(slotMap["to"]!);
        return "$fromTime - $toTime";
      }).toList();

      // Sort the slots based on "from" time
      sortedSlots.sort((a, b) {
        int fromA = int.parse(a.split(" - ")[0].replaceAll(":", ""));
        int fromB = int.parse(b.split(" - ")[0].replaceAll(":", ""));
        return fromA.compareTo(fromB);
      });

      return sortedSlots.join(", ");
    }
    /// **Converts 12-hour format (AM/PM) to 24-hour format**
    String _convertTo24Hour(String time) {
      try {
        List<String> parts = time.split(" ");
        List<String> timeParts = parts[0].split(":");
        int hour = int.parse(timeParts[0]);
        String minutes = timeParts[1];

        if (parts[1] == "PM" && hour != 12) {
          hour += 12;
        } else if (parts[1] == "AM" && hour == 12) {
          hour = 0;
        }

        return "${hour.toString().padLeft(2, '0')}:$minutes"; // Ensures "08:00" instead of "8:00"
      } catch (e) {
        print("Error converting time: $e");
        return time; // Return original if conversion fails
      }
    }
    /// **Formats the languages correctly**
    void _showLanguagesDetails(List<dynamic> languages) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.languagesSpoken,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: languages.map((language) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      child: Text(
                        language,
                          style: AppTextStyles.getText2(context).copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 15.h),
              ],
            ),
          );
        },
      );
    }

    Future<String?> _getCurrentUserId() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      print("🔥 Retrieved User ID in Doctor Profile: $userId"); // Debug print
      return userId;
    }

    void _loadFavoriteStatus() async {
      final String? userId = await _getCurrentUserId();
      final String? doctorId = widget.doctorId.toString();

      print("🔹 Checking Favorite Status");
      print("👤 User ID: $userId");
      print("🩺 Doctor ID: $doctorId");

      if (userId == null || userId.isEmpty || doctorId == null || doctorId.isEmpty) {
        print("❌ Error: Doctor ID or User ID is missing! Cannot check favorites.");
        return;
      }

      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('favorites')
            .eq('id', userId)
            .maybeSingle();

        List<dynamic> favorites = response?['favorites'] ?? [];

        setState(() {
          _isFavorite = favorites.contains(doctorId);
        });

        print("✅ Favorite status loaded: $_isFavorite");

      } catch (e) {
        print("❌ Error loading favorite status: $e");
      }
    }

    void _toggleFavoriteStatus() async {
      final String? userId = await _getCurrentUserId();
      final String? doctorId = _doctorData?['id']?.toString();

      print("🔹 Toggling Favorite");
      print("👤 User ID: $userId");
      print("🩺 Doctor ID: $doctorId");

      if (userId == null || userId.isEmpty || doctorId == null || doctorId.isEmpty) {
        print("❌ Error: Doctor ID or User ID is missing!");
        return;
      }

      try {
        final supabase = Supabase.instance.client;


        // ✅ Fetch current favorites
        final response = await supabase
            .from('users')
            .select('favorites')
            .eq('id', userId)
            .maybeSingle();

        if (response == null) {
          print("❌ User not found in Supabase.");
          return;
        }

        List<dynamic> favorites = response['favorites'] ?? [];

        if (favorites.contains(doctorId)) {
          // ✅ REMOVE doctor from favorites
          favorites.remove(doctorId);
          await supabase
              .from('users')
              .update({'favorites': favorites})
              .eq('id', userId);

          setState(() => _isFavorite = false);
          print("❌ Doctor removed from favorites");
        } else {
          // ✅ ADD doctor to favorites
          favorites.add(doctorId);
          await supabase
              .from('users')
              .update({'favorites': favorites})
              .eq('id', userId);

          setState(() => _isFavorite = true);
          print("⭐ Doctor added to favorites");
        }

        // ✅ Flag refresh for main screen
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('refreshFavorites', true);
      } catch (e) {
        print("❌ Error updating favorites: $e");
      }
    }





    @override
    Widget build(BuildContext context) {
      final doctor = _doctorData ?? {};
      String gender = doctor['gender']?.toLowerCase() ?? 'male';
      String title = doctor['title']?.toLowerCase() ?? '';
      Map<String, dynamic>? address = doctor['address']; // Now a Map
      String? street = address?['street'];
      String? buildingNr = address?['buildingNr']?.toString();
      String? city = address?['city'];
      String? country = address?['country'];
      String? addressDetails = address?['details'];
      String? clinic = doctor['clinic']; // Added Clinic


      // ✅ Determine avatar based on gender & title
      String? imageUrl = doctor['profile_image'];
      String avatarPath = getDoctorImage(
        imageUrl: imageUrl,
        gender: gender,
        title: title,
      );

      final String? profileDescription = doctor['profile_description'];
      final List<String>? specialties = (doctor['specialties'] as List<dynamic>?)?.cast<String>();
      final String? website = doctor['website'];
  // ✅ Get screen width dynamically
      double screenWidth = MediaQuery.of(context).size.width;
      double expandedHeight = screenWidth * 0.60; // Responsive height

      // ✅ Check for null doctorId before using it


      if (widget.doctorId.isEmpty) {
        print("❌ ERROR: doctorId is unexpectedly empty inside DoctorProfilePage");
        return Scaffold(
          appBar: AppBar(title: Text("Error")),
          body: Center(child: Text("Doctor ID is missing. Cannot load profile.")),
        );
      }

      return Scaffold(
        extendBody: true,

        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Text("Doctor ID: ${widget.doctorId ?? 'No ID'}"),

        (_doctorData == null || _doctorData!.isEmpty)
            ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(// Show loading until doctor is loaded
              controller: _scrollController,
              slivers: [
                // ✅ AppBar (Collapsible)
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 0.28,
                  pinned: true,
                  floating: false,
                  elevation: 0,
                  backgroundColor: AppColors.main,
                  leading: IconButton(
                    icon:  Icon(Icons.arrow_back_ios_new, color: AppColors.whiteText, size: 16.sp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.star : Icons.star_border,
                        color: AppColors.whiteText,
                      ),
                      onPressed: _toggleFavoriteStatus,
                    ),
                    IconButton(
                      icon:  Icon(Icons.share, color: AppColors.whiteText, size: 18.sp),
                      onPressed: _shareDoctorProfile
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Opacity(
                      opacity: _showAppBar ? 1.0 : 0.0,
                      child: Text(
                        "${_doctorData?['title'] ?? ''} ${_doctorData?['first_name'] ?? ''} ${_doctorData?['last_name'] ?? ''}".trim(),
                        style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.whiteText)
                      ),
                    ),
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.background2.withOpacity(0.2),
                          radius: 40.r,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.asset(
                              avatarPath,
                              width: 100.w,
                              height: 100.h,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          "${_doctorData?['title'] ?? ''} ${_doctorData?['first_name'] ?? ''} ${_doctorData?['last_name'] ?? ''}".trim(),
                            style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.whiteText)
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          _doctorData?['specialty'] ?? "Specialty not provided",
                          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500,color: Colors.white70),
                        ),
                        SizedBox(height: 15.h),
                      ],
                    ),
                  ),
                ),

                // ✅ Book Appointment Button
                SliverPersistentHeader(
                  pinned: false,
                  floating: false,
                  delegate: _ButtonHeaderDelegate(
                    MediaQuery.of(context).size.height * 0.05,
                    widget.doctorId ?? 'No ID',
                    _doctorData?['title'] ?? '',
                    _doctorData?['gender'] ?? '',
                    _doctorData?['first_name'] ?? '',
                    _doctorData?['last_name'] ?? '',
                    _doctorData?['specialty'] ?? '',
                    avatarPath,
                    _doctorData?['clinic'] ?? '',
                    _doctorData?['address'] ?? {},
                  ),
                ),

                // ✅ Scrollable Content
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding:  EdgeInsets.all(16.w),
                      child: Column(
                        children: [
                          if (street != null || city != null || country != null)
                            _buildLocationSection(street, buildingNr, city, country, addressDetails, address, _doctorData?['clinic']),
                          SizedBox(height: 10.h),
                          if (profileDescription != null || (specialties != null && specialties.isNotEmpty))
                            _buildProfileSection(profileDescription, specialties, website),
                          SizedBox(height: 20.h),
                          if (_doctorData?['opening_hours'] != null || _doctorData?['languages'] != null || _doctorData?['phone_number'] != null)
                            _buildInfoSection(
                              _doctorData?['phone_number']?.toString(),
                              _doctorData?['opening_hours'] ?? {},
                              _doctorData?['languages'] ?? [],
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ],
        ),
      );

    }
  }
  class _ButtonHeaderDelegate extends SliverPersistentHeaderDelegate {
    final double appBarHeight;
    final String doctorId; // ✅ Add doctorId parameter
    final String doctorTitle;
    final String doctorGender;
    final String doctorFirstName;
    final String doctorLastName;
    final String doctorSpecialty;
    final String avatarPath;
    final String clinicName; // ✅ إضافة اسم العيادة
    final Map<String, dynamic> clinicAddress;// ✅ إضافة عنوان العيادة

    _ButtonHeaderDelegate(
        this.appBarHeight,
        this.doctorId,
        this.doctorTitle,
        this.doctorGender,
        this.doctorFirstName,
        this.doctorLastName,
        this.doctorSpecialty,
        this.avatarPath,
        this.clinicName,
        this.clinicAddress); // ✅ Receive doctorId

    @override
    double get minExtent => 20;
    @override
    double get maxExtent => appBarHeight / 2 + 30;

    @override
    Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
      return Container(
        alignment: Alignment.center,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectPatientPage(
                  doctorId: doctorId,
                  doctorName: "$doctorFirstName $doctorLastName",
                  doctorGender: doctorGender,
                    doctorTitle: doctorTitle,
                    specialty: doctorSpecialty,
                  image: avatarPath,
                  clinicName: clinicName, // ✅ تمرير اسم العيادة
                  clinicAddress: clinicAddress, // ✅ تمرير عنوان العيادة
                ), // ✅ Navigate to new flow
              ),
            );
          },
          icon:  Icon(Icons.calendar_today, color: AppColors.mainDark, size: 16.sp,),
          label: Text(
            AppLocalizations.of(context)!.bookAppointment,
            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.mainDark),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mainDark.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            minimumSize: const Size(double.infinity, 50),
            elevation: 0,
          ),
        ),
      );
    }

    @override
    bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
  }

