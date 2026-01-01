import 'dart:async';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_cubit.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_state.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/doctors/auth/doctor_identification_page.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/widgets/main_screen_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/sign_up_info.dart';
import '../auth/sign_up/WelcomePage.dart';


class MainScreen extends StatefulWidget {
   const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ Keeps state alive when switching tabs

  static bool _bannersLoadedOnce = false; // ✅ يبقى محفوظ بعد التنقل
  bool _bannerColorsReady = false;

  StreamSubscription? _favoritesListener; // ✅ إضافة متغير لحفظ `listener`
  bool _isFirstLoad = true; // ✅ يظهر `Shimmer` فقط عند تشغيل التطبيق لأول مرة
  final bool _didLoadFavoritesOnce = false;




  @override
  void initState() {
    super.initState();
    debugPrint("📌 MainScreen: initState() -> Checking login status...");
    _bannerColorsReady = _bannersLoadedOnce; // ✅ إذا كانت محمّلة سابقًا، لا تعيد تحميلها
    context.read<MainScreenCubit>().loadMainScreen(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    if (_favoritesListener != null) {
      _favoritesListener!.cancel();
      _favoritesListener = null; // Prevent memory leaks
    }
    super.dispose();
  }



  /// **🔹 "My Practitioners" Section (Responsive)**
  Widget _buildMyPractitionersSection(bool isLoggedIn, List<Map<String, dynamic>> favoriteDoctors) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;

        // ✅ Dynamically adjust number of doctors per row based on screen width
        int crossAxisCount = (screenWidth ~/ 120).clamp(3, 6);

        // ✅ Minimized spacing for a tighter layout
        double spacing = 3.w; // Less horizontal space
        double verticalSpacing = 20.h; // Even less vertical space

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:  EdgeInsets.symmetric(horizontal: 25.w),
              child: Text(
                AppLocalizations.of(context)!.myPractitioners,
                style: AppTextStyles.getTitle1(context),
              ),
            ),
             SizedBox(height: 20.h),
            favoriteDoctors.isEmpty
                ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                AppLocalizations.of(context)!.noPractitionersAdded,
                style: AppTextStyles.getText1(context).copyWith(color: Colors.black54),
              ),
            )
                : Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w), // ✅ Balanced left/right padding
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: verticalSpacing, // ✅ Minimal vertical spacing
                  childAspectRatio: 1.00,
                ),
                itemCount: favoriteDoctors.length,
                itemBuilder: (context, index) {
                  return _buildDoctorCard(favoriteDoctors[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// **🔹 Doctor Card Widget**
  Widget _buildDoctorCard(Map<String, dynamic> doctor) {


    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final doctorImageProvider = imageResult.imageProvider;


    return GestureDetector(
      onTap: () {
        _showDoctorOptions(doctor);
      },
      child: Container(
        width: 100,
        margin: EdgeInsets.only(left: 12.w, right: 14.w),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.main.withOpacity(0.2),
              backgroundImage: doctorImageProvider,
            ),
            SizedBox(height: 6.h),
            Text(
              "${doctor['title']} ${doctor['first_name']} ${doctor['last_name']}".trim(),
              textAlign: TextAlign.center,
              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              doctor['specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText3(context).copyWith(color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDoctorOptions(Map<String, dynamic> doctor) {
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final imageProvider = imageResult.imageProvider;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape:  RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.0.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.main.withOpacity(0.1),
                  backgroundImage: imageProvider,
                ),

                title: Text(
                  "${doctor['title']} ${doctor['first_name']} ${doctor['last_name']}".trim(),
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(doctor['specialty'] ?? "", style: AppTextStyles.getText2(context) ,),
              ),
              const Divider(),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric( horizontal: 16.w), // ✅ تقليل التباعد العلوي والسفلي
                leading: Icon(Icons.calendar_today, color: AppColors.main, size: 20.sp),
                title: Text(AppLocalizations.of(context)!.bookAppointment, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context); // إغلاق الـ Bottom Sheet
                  debugPrint("🧭 [MainScreen] doctor map = $doctor");
                  debugPrint("🧭 [MainScreen] location candidate = ${doctor['location'] ?? doctor['clinicLocation'] ?? doctor['address']?['location']}");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectPatientPage(
                        doctorId: doctor['id'],
                        doctorName: "${doctor['first_name']} ${doctor['last_name']}",
                        doctorGender: doctor['gender'],
                        doctorTitle: doctor['title'],
                        specialty: doctor['specialty'],
                        image: imageResult.avatarPath,
                        clinicName: doctor['clinic'],
                        clinicAddress: doctor['address'],
                        clinicLocation: doctor['location'] ?? {},
                      ),
                    ),
                  );
                },
              ),
              Divider(color: Colors.grey[100], height: 1.h, thickness: 1.h),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w), // ✅ تقليل التباعد العلوي والسفلي
                leading:  Icon(Icons.person, color: AppColors.main, size: 20.sp),
                  title: Text( AppLocalizations.of(context)!.viewProfile, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500)),
                  onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Navigator.push(
                    context,
                    fadePageRoute(DoctorProfilePage(doctor: {
                      "id": doctor["id"] ?? "",
                      "title": doctor["title"] ?? "",
                      "first_name": doctor["firstName"] ?? "",
                      "last_name": doctor["last_name"] ?? "",
                      "specialty": doctor["specialty"] ?? "",
                      "profile_description": doctor["profile_description"] ?? "",
                      "clinic": doctor["clinic"] ?? "",
                      "address": doctor["address"] ?? "",
                      "phone_number": doctor["phoneNumber"] ?? "",
                      "languages": doctor["languages"] ?? [],
                      "email": doctor["email"] ?? "",
                      "doctor_image": (doctor["doctor_image"] != null && doctor["doctor_image"] != "null")
                          ? doctor["doctor_image"]
                          : "assets/images/male-doc.png",
                    }, doctorId: doctor["id"],)),
                  );

                  },
                  ),
               Divider(color: Colors.grey[100], height: 1.h, thickness: 1.h),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric( horizontal: 16.w), // ✅ تقليل التباعد العلوي والسفلي
                leading:  Icon(Icons.remove_circle, color: AppColors.red, size: 20.sp),
                title: Text(
                  AppLocalizations.of(context)!.removeFromFavorites,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500, color: AppColors.red)
                ),
                onTap: () async {
                  context
                      .read<MainScreenCubit>()
                      .removeFromFavorites(context, doctor['id']);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Important to call super.build when using AutomaticKeepAliveClientMixin

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildShimmerLoading(); // ✅ `Shimmer` يظهر فقط عند فتح التطبيق لأول مرة
        }

        return BlocProvider.value(
          value: BlocProvider.of<MainScreenCubit>(context),
          child: BlocBuilder<MainScreenCubit, MainScreenState>(
            builder: (context, state) {
              if (state is MainScreenLoading && _isFirstLoad) {
                return _buildShimmerLoading();
              } else if (state is MainScreenLoaded) {
                _isFirstLoad = false;

                final bool isLoggedIn = state.isLoggedIn;

                return _buildMainScreenContent(context, isLoggedIn, state.favoriteDoctors);
              }
               else if (state is MainScreenError) {
                return Center(child: Text(state.message, style: const TextStyle(color: AppColors.red)));
              }
              return const Center(child: Text("Unexpected error"));
            },
          ),
        );

      },
    );
  }


  Widget _buildShimmerLoading() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // ✅ الخلفية الأساسية بلون `background2`
        Container(
          height: screenHeight,
          width: double.infinity,
          color: AppColors.background2,
        ),

        // ✅ الجزء العلوي بلون أخضر مع حافة دائرية
        ClipPath(
          clipper: CustomTopBarClipper(),
          child: Container(
            height: screenHeight * 0.3,
            color: AppColors.main,
          ),
        ),

        // ✅ زر البحث كـ Shimmer
        Positioned(
          top: screenHeight * 0.17,
          left: (screenWidth - 150) / 2,
          child: ShimmerWidget(
            width: 150,
            height: 40,
            radius: 20.r,
          ),
        ),

        // ✅ البانرات كـ Shimmer (تعديل الإزاحة)
        Positioned(
          top: screenHeight * 0.3, // ✅ نفس `top` الخاص بـ `BannersSection`
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, -screenHeight * 0.055), // ✅ التوافق مع `BannersSection`
            child: SizedBox(
              height: screenWidth * 0.32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                    child: ShimmerWidget(
                      width: screenWidth * 0.75,
                      height: screenWidth * 0.32,
                      radius: 18.r,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        Positioned(
          top: screenHeight * 0.44,
          left: (screenWidth * 0.1) / 2,
          child: ShimmerWidget(
            width: screenWidth * 0.9,
            height: screenHeight * 0.03,
            radius: 12.r,
          ),
        ),

        Positioned(
          top: screenHeight * 0.49,
          left: (screenWidth * 0.1) / 2,
          child: ShimmerWidget(
            width: screenWidth * 0.9,
            height: screenHeight * 0.1,
            radius: 12.r,
          ),
        ),

        Positioned(
          top: screenHeight * 0.62,
          left: (screenWidth * 0.7) / 2,
          child: ShimmerWidget(
            width: screenWidth * 0.3,
            height: screenHeight * 0.05,
            radius: 10.r,
          ),
        ),

        Positioned(
          top: screenHeight * 0.70,
          left: (screenWidth * 0.1) / 2,
          child: ShimmerWidget(
            width: screenWidth * 0.9,
            height: screenHeight * 0.5,
            radius: 20.r,
          ),
        ),
      ],
    );
  }


  Widget _buildMainScreenContent(BuildContext context, bool isLoggedIn, List<Map<String, dynamic>> favoriteDoctors) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final ScrollController scrollController = ScrollController();


    // ✅ Define bannerData list to pass to `BannersSection`
    final List<Map<String, dynamic>> bannerData = [
      {
        "title": AppLocalizations.of(context)!.bannerTitle1,
        "text": AppLocalizations.of(context)!.bannerText1,
        "imagePath": "assets/images/worker.webp",
        "logoPath": "assets/images/docsera_white.svg",
        "isSponsored": true,
        "logoContainerColor": AppColors.main.withOpacity(0.5), // ✅ Now the container has the correct color
      },
      {
        "title": AppLocalizations.of(context)!.bannerTitle2,
        "text": AppLocalizations.of(context)!.bannerText2,
        "imagePath": "assets/images/professional.jpg",
        "isSponsored": false,
      },
      {
        "text": AppLocalizations.of(context)!.bannerText3,
        "imagePath": "assets/images/worker.webp",
        "isSponsored": true,
      },
    ];

    return  Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(color: AppColors.main),
              ),
              Expanded(
                flex: 1,
                child: Container(color: AppColors.background2),
              ),
            ],
          ),
        ),

        SingleChildScrollView(
          controller: scrollController,
          child: Container(
            color: AppColors.background2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const TopSection(), // ✅ Contains only the header & background

                // ✅ Pass the banners list to `BannersSection`
                // ✅ Use optimized BannersSection
                // ✅ Pass banners and ensure instant display
                Transform.translate(
                  offset: Offset(0, -screenHeight * 0.055),
                  child: AnimatedOpacity(
                    opacity: _bannerColorsReady ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: BannersSection(
                      banners: bannerData,
                      onColorsLoaded: () {
                        debugPrint("🎉 onColorsLoaded called from BannersSection");
                        if (!_bannerColorsReady && mounted) {
                          setState(() {
                            debugPrint("✅ Setting _bannerColorsReady = true");
                            _bannerColorsReady = true;
                            _bannersLoadedOnce = true; // ✅ حفظ دائم بعد أول تحميل
                          });
                        }
                      },
                    ),
                  ),
                ),




                // ✅ **"My Practitioners" يظهر فقط إذا كان المستخدم مسجّل الدخول**
                isLoggedIn && favoriteDoctors.isNotEmpty ? _buildMyPractitionersSection(isLoggedIn, favoriteDoctors) : const SizedBox(),
                isLoggedIn && favoriteDoctors.isNotEmpty ? SizedBox(height: 20.h) : const SizedBox(),
                _buildScrollButton(scrollController), // ✅ Button now properly below banners
                SizedBox(height: 40.h),
                const FeaturesSection(),
                SizedBox(height: 30.h),


                DecorativeImageCard(
                  title:  AppLocalizations.of(context)!.weAreHiring,
                  description:  AppLocalizations.of(context)!.workWithUs,
                  buttonText:  AppLocalizations.of(context)!.learnMore,
                  onButtonPressed: () {
                    Navigator.push(
                      context,
                      fadePageRoute(WelcomePage(
                        signUpInfo: SignUpInfo(firstName: "User"), // أو أي اسم تجريبي
                      )),
                    );
                  },

                  backgroundColor: Colors.grey.shade400,
                  buttonColor: Colors.grey.withOpacity(0.9),
                  shapeNumber: 10,
                  imageShapeNumber: 4,
                  secondShapeNumber: 9,
                  shapeColor: Colors.yellow.withOpacity(0.3),
                  imagePath: 'assets/images/worker.webp',
                  showSecondShape: true,
                ),

                // ✅ Decorative Cards Section
                DecorativeImageCard(
                  title: AppLocalizations.of(context)!.areYouAHealthProfessional,
                  description: AppLocalizations.of(context)!.improveDailyLife,
                  buttonText:  AppLocalizations.of(context)!.registerAsDoctor,
                  onButtonPressed: () {
                    Navigator.push(
                      context,
                      fadePageRoute(const DoctorIdentificationPage()),
                    );
                  },
                  backgroundColor: AppColors.main,
                  buttonColor: Colors.white.withOpacity(0.4),
                  shapeNumber: 1,
                  imageShapeNumber: 2,
                  secondShapeNumber: 5, // ✅ استخدم الشكل 7 كشكل إضافي
                  shapeColor: Colors.white.withOpacity(0.3),
                  secondShapeColor: AppColors.mainDark.withOpacity(0.8),
                  imagePath: 'assets/images/professional.jpg',
                  showSecondShape: true,
                ),

                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    Supabase.instance.client.auth.signOut(); // ⛔ اختياري فقط
                    // أعد تشغيل التطبيق أو انتقل لشاشة البداية
                  },
                  child: const Text('🧹 Reset Session'),
                ),



              ],
            ),
          ),

        ),
      ],
    );
  }


    /// **🔹 Scroll Button (Now Below Banners)**
  Widget _buildScrollButton(ScrollController controller) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.mainDark,
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.areYouAHealthProfessional,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
