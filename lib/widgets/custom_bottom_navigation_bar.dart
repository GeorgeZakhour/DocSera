import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/screens/home/appointments_page.dart';
import 'package:docsera/screens/home/documents_page.dart';
import 'package:docsera/screens/home/messages_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:docsera/screens/auth/identification_page.dart';
import 'package:docsera/screens/home/account_page.dart';
import 'package:docsera/screens/home/main_screen.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/main.dart';


class CustomBottomNavigationBar extends StatefulWidget {
  @override
  _CustomBottomNavigationBarState createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin  {
  @override
  bool get wantKeepAlive => true; // ✅ يمنع إعادة تحميل الصفحة عند التنقل

  bool isLoaded = false;
  // bool isLoggedIn = false;
  int _currentIndex = 0;
  late bool isLoggedIn;
  late List<Widget> _pages;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // _checkLoginStatus();

    // ✅ تفعيل الاستماع مباشرة في البداية
    Future.microtask(() {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        context.read<MessagesCubit>().loadMessages(context);
      }
    });

    _pages = [
      MainScreen(),
      AppointmentsPage(),
      DocumentsPage(),
      MessagesPage(),
      AccountScreen(onLogout: () => _logout(context)),
    ];


    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMainScreen() async {
    await Future.delayed(const Duration(seconds: 2)); // ✅ محاكاة تحميل البيانات
    if (mounted) {
      setState(() {
        _pages[0] = MainScreen(); // ✅ استبدال شاشة التحميل بـ MainScreen بعد تحميلها
        isLoaded = true;
      });
    }
  }

  // Future<void> _checkLoginStatus() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  //   });
  // }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      setState(() {
        isLoggedIn = false;
        _currentIndex = 0;
      });
      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(CustomBottomNavigationBar()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      _animation = Tween<double>(
        begin: _currentIndex.toDouble(),
        end: index.toDouble(),
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );

      _animationController.forward(from: 0);

      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _showLanguageSelectionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setState) {
            String currentLocale = Localizations.localeOf(innerContext).languageCode;
            bool isArabic = currentLocale == 'ar';

            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Title
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        AppLocalizations.of(innerContext)!.chooseLanguage,
                        style: TextStyle(
                          fontSize: isArabic ? 13 : 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: isArabic ? 'Cairo' : 'Montserrat',
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Divider(),

                    // ✅ Arabic Option
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 16.w),
                      leading: const Icon(Icons.language, color: AppColors.main),
                      title: const Text(
                        "العربية",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      trailing: currentLocale == 'ar'
                          ? const Icon(Icons.check, color: AppColors.main) // ✅ Show checkmark if selected
                          : null,
                      onTap: () {
                        _changeLanguage("ar");
                        setState(() {}); // ✅ Update UI instantly
                      },
                    ),
                    Divider(color: Colors.grey[300]),

                    // ✅ English Option
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 16.w),
                      leading: const Icon(Icons.language, color: AppColors.main),
                      title: const Text(
                        "English",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      trailing: currentLocale == 'en'
                          ? const Icon(Icons.check, color: AppColors.main) // ✅ Show checkmark if selected
                          : null,
                      onTap: () {
                        _changeLanguage("en");
                        setState(() {}); // ✅ Update UI instantly
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ تغيير اللغة بناءً على اختيار المستخدم
  void _changeLanguage(String languageCode) {
    final myAppState = MyApp.of(context);
    if (myAppState != null) {
      myAppState.changeLanguage(languageCode);
    }

    setState(() {}); // ✅ Refresh UI
    Navigator.pop(context); // ✅ Close the Bottom Sheet
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin to work properly

    final authState = context.watch<AuthCubit>().state;
    final bool isLoggedIn = authState is AuthAuthenticated;

    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth / 5;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent, // 🚀 إلغاء تأثير النقر
        highlightColor: Colors.transparent, // 🔥 إلغاء تأثير التوهج
      ),
      child: Scaffold(
        backgroundColor: AppColors.main,// يجب أن يكون نفس لون الـ AppBar
        appBar: AppBar(
          backgroundColor: AppColors.main.withOpacity(1), // تأكد من أن الشفافية 100%
          surfaceTintColor: Colors.transparent, // يمنع تأثير الظل الغامق الذي يظهر عند التمرير
          shadowColor: Colors.transparent, // 🔹 إزالة الظل تمامًا
          elevation: 0,
          centerTitle: true,

          title: Row(
            children: [
              // ✅ الجزء الأول: زر تغيير اللغة (يظهر فقط في الصفحة الرئيسية)
              if (_currentIndex == 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4), // 🔹 تقليل المسافة أكثر
                  child: TextButton(
                    onPressed: _showLanguageSelectionSheet,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(40, 40), // ✅ جعل الزر صغيرًا لكنه قابل للنقر بسهولة
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded, color: AppColors.whiteText, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          Localizations.localeOf(context).languageCode.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.whiteText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(width: 40), // ✅ تعويض المساحة عند إخفاء الزر

              // ✅ الجزء الثاني: الشعار في المنتصف دائمًا
              Expanded(
                child: Center(
                  child: _currentIndex == 0
                      ? SvgPicture.asset(
                    'assets/images/docsera_white.svg',
                    height: 18,
                  )
                      : Text(
                    _getTitle(_currentIndex), // ✅ العنوان من arb files
                    style: const TextStyle(
                      color: AppColors.whiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // ✅ الجزء الثالث: زر تسجيل الدخول (يظهر فقط إذا لم يكن المستخدم مسجلًا الدخول)
              if (_currentIndex == 0 && !isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(right: 0), // 🔹 تقليل المسافة أكثر
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        fadePageRoute(const IdentificationPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(50, 50),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.logInAppbar,
                      style:  TextStyle(color: AppColors.whiteText,
                        fontSize: Localizations.localeOf(context).languageCode == 'ar' ? 11 : 12, // ✅ تصغير الخط في العربية
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 50), // ✅ تعويض المساحة عند إخفاء الزر
            ],
          ),
        ),



        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            _pages[_currentIndex],


      // ✅ **PERFECTLY CENTERED Animated Indicator**
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                bool isRtl = Directionality.of(context) == TextDirection.rtl;

                return Positioned(
                  bottom: 0,
                  left: isRtl
                      ? ((4 - _animation.value) * buttonWidth) + (buttonWidth * 0.05) // 🔹 عكس الحساب عند RTL
                      : (_animation.value * buttonWidth) + (buttonWidth * 0.05), // الوضع الطبيعي
                  child: Container(
                    width: buttonWidth * 0.9,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.main,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),

          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: AppColors.background2,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.main,
          unselectedItemColor: Colors.black,
          selectedFontSize: 10,
          unselectedFontSize: 9,
          selectedLabelStyle: TextStyle(
            fontFamily: Localizations.localeOf(context).languageCode == 'ar' ? 'Cairo' : 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: Localizations.localeOf(context).languageCode == 'ar' ? 'Cairo' : 'Montserrat',
            fontWeight: FontWeight.w400,
          ),
          enableFeedback: false,
          mouseCursor: SystemMouseCursors.basic,
          items: [
            _buildNavItem('assets/icons/home.svg', 'assets/icons/home-on_.svg', AppLocalizations.of(context)!.home, 0, 18.h),
            _buildNavItem('assets/icons/appointment.svg', 'assets/icons/appointment-on.svg', AppLocalizations.of(context)!.appointments, 1, 22.h),
            _buildNavItem('assets/icons/document.svg', 'assets/icons/document-on.svg', AppLocalizations.of(context)!.documents, 2, 18.h),
            _buildMessagesNavItem(context),
            _buildNavItem(
              isLoggedIn ? 'assets/icons/account.svg' : 'assets/icons/login.svg',
              isLoggedIn ? 'assets/icons/account-on.svg' : 'assets/icons/login-on.svg',
              isLoggedIn ? AppLocalizations.of(context)!.account : AppLocalizations.of(context)!.logIn,
              4,
              22.h,
            ),
          ],
        ),


      ),
    );
  }

  BottomNavigationBarItem _buildMessagesNavItem(BuildContext context) {
    final state = context.watch<MessagesCubit>().state;
    int unreadCount = 0;

    if (state is MessagesLoaded) {
      unreadCount = state.unreadConversationsCount;
    }

    final isSelected = _currentIndex == 3;

    return BottomNavigationBarItem(
      icon: SizedBox(
        height: 22.h,
        width: 22.h,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ✅ الأيقونة
            SvgPicture.asset(
              isSelected
                  ? 'assets/icons/conversation-on.svg'
                  : 'assets/icons/conversation.svg',
              color: isSelected ? AppColors.main : Colors.black,
              height: 18.h,
            ),

            // ✅ الدائرة الحمراء فقط إذا unreadCount > 0
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -8,
                child: AnimatedOpacity(
                  opacity: unreadCount > 0 ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Container(
                    padding: EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12.w,
                      minHeight: 12.w,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      label: AppLocalizations.of(context)!.messages,
    );
  }



  BottomNavigationBarItem _buildNavItem(String iconPath, String activeIconPath, String label, int index,double height) {
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        _currentIndex == index ? activeIconPath : iconPath,
        color: _currentIndex == index ? AppColors.main : Colors.black,
        height: height, // Adjust size as needed
      ),
      label: label,
    );
  }


  String _getTitle(int index) {
    switch (index) {
      case 0:
        return AppLocalizations.of(context)!.home;
      case 1:
        return AppLocalizations.of(context)!.appointments;
      case 2:
        return AppLocalizations.of(context)!.documents;
      case 3:
        return AppLocalizations.of(context)!.messages;
      case 4:
        return AppLocalizations.of(context)!.account;
      default:
        return AppLocalizations.of(context)!.home;
    }
  }
}
