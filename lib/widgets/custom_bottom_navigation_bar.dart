import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_state.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/screens/home/appointments_page.dart';
import 'package:docsera/screens/home/health_page.dart';
import 'package:docsera/screens/home/messages_page.dart';
import 'package:docsera/screens/auth/identification_page.dart';
import 'package:docsera/screens/home/account_page.dart';
import 'package:docsera/screens/home/main_screen.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/services/navigation/app_lifecycle.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int initialIndex;
  
  // ✅ Global Key to access state from NotificationService
  static final GlobalKey<_CustomBottomNavigationBarState> globalKey = GlobalKey<_CustomBottomNavigationBarState>();

  CustomBottomNavigationBar({this.initialIndex = 0}) : super(key: globalKey);

  @override
  _CustomBottomNavigationBarState createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool isLoaded = false;
  int _currentIndex = 0;
  late bool isLoggedIn;
  late List<Widget> _pages;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // ✅ Signal that the app structure is ready for deep links
    AppLifecycle.isAppReady.value = true;

    _currentIndex = widget.initialIndex;

    Future.microtask(() {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        context.read<MessagesCubit>().loadMessages(context);
      }
    });

    _pages = [
      const MainScreen(),
      const AppointmentsPage(),
      const HealthPage(), // 🔹 بدل DocumentsPage
      const MessagesPage(),
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

  // ✅ Public method to switch tabs
  void switchTab(int index) {
      if (index >= 0 && index < _pages.length) {
          setState(() {
              _currentIndex = index;
              // Also update the Cubit/State if needed, but setState usually triggers the UI update
          });
      }
  }

  // --- Helpers ---
  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
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
            String currentLocale =
                Localizations.localeOf(innerContext).languageCode;
            bool isArabic = currentLocale == 'ar';

            return Directionality(
              textDirection:
              isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
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
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 2.h, horizontal: 16.w),
                      leading: const Icon(Icons.language,
                          color: AppColors.main),
                      title: const Text(
                        "العربية",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      trailing: currentLocale == 'ar'
                          ? const Icon(Icons.check,
                          color: AppColors.main)
                          : null,
                      onTap: () {
                        _changeLanguage("ar");
                        setState(() {});
                      },
                    ),
                    Divider(color: Colors.grey[300]),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 2.h, horizontal: 16.w),
                      leading: const Icon(Icons.language,
                          color: AppColors.main),
                      title: const Text(
                        "English",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      trailing: currentLocale == 'en'
                          ? const Icon(Icons.check,
                          color: AppColors.main)
                          : null,
                      onTap: () {
                        _changeLanguage("en");
                        setState(() {});
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

  void _changeLanguage(String languageCode) {
    final myAppState = MyApp.of(context);
    if (myAppState != null) {
      myAppState.changeLanguage(languageCode);
    }

    setState(() {});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final authState = context.watch<AuthCubit>().state;
    final bool isLoggedIn = authState is AuthAuthenticated;

    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth / 5;
    DateTime? lastBackPressed;

    final bool isArabicLocale =
        Localizations.localeOf(context).languageCode == 'ar';

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false;
        }

        if (lastBackPressed != null &&
            DateTime.now().difference(lastBackPressed!) <
                const Duration(seconds: 1)) {
          return true;
        }

        lastBackPressed = DateTime.now();

        final shouldExit = await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "exit",
          barrierColor: Colors.black.withOpacity(0.5),
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Builder(
                builder: (innerContext) => Center(
                  child: Material(
                    color: Colors.transparent,
                    child: AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r)),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 24.w, vertical: 20.h),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(innerContext)!.exitAppTitle,
                            style: AppTextStyles.getTitle2(innerContext),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            AppLocalizations.of(innerContext)!
                                .areYouSureToExit,
                            style: AppTextStyles.getText2(innerContext),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24.h),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.main,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24.w, vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10.r)),
                            ),
                            onPressed: () =>
                                Navigator.of(innerContext).pop(true),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(innerContext)!.exit,
                                style: AppTextStyles
                                    .getText2(innerContext)
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(innerContext).pop(false),
                            child: Text(
                              AppLocalizations.of(innerContext)!.cancel,
                              style: AppTextStyles
                                  .getText2(innerContext)
                                  .copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.blackText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        return shouldExit == true;
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.main,
          appBar: _currentIndex == 2
              ? null
              : AppBar(
            backgroundColor: AppColors.main.withOpacity(1),
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Row(
              children: [
                if (_currentIndex == 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton(
                      onPressed: _showLanguageSelectionSheet,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(40, 40),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language_rounded,
                              color: AppColors.whiteText, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            Localizations.localeOf(context)
                                .languageCode
                                .toUpperCase(),
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
                  const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: _currentIndex == 0
                        ? SvgPicture.asset(
                      'assets/images/docsera_white.svg',
                      height: 18,
                    )
                        : Text(
                      _getTitle(_currentIndex, isArabicLocale),
                      style: const TextStyle(
                        color: AppColors.whiteText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (_currentIndex == 0 && !isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.only(right: 0),
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
                        style: TextStyle(
                          color: AppColors.whiteText,
                          fontSize:
                          Localizations.localeOf(context)
                              .languageCode ==
                              'ar'
                              ? 11
                              : 12,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 50),
              ],
            ),
          ),
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SafeArea(
                child: _pages[_currentIndex],
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  bool isRtl =
                      Directionality.of(context) == TextDirection.rtl;

                  return Positioned(
                    bottom: 0,
                    left: isRtl
                        ? ((4 - _animation.value) * buttonWidth) +
                        (buttonWidth * 0.05)
                        : (_animation.value * buttonWidth) +
                        (buttonWidth * 0.05),
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
              fontFamily: isArabicLocale ? 'Cairo' : 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: isArabicLocale ? 'Cairo' : 'Montserrat',
              fontWeight: FontWeight.w400,
            ),
            enableFeedback: false,
            mouseCursor: SystemMouseCursors.basic,
            items: [
              _buildNavItem(
                  'assets/icons/home.svg',
                  'assets/icons/home-on_.svg',
                  AppLocalizations.of(context)!.home,
                  0,
                  18.h),
              _buildNavItem(
                  'assets/icons/appointment.svg',
                  'assets/icons/appointment-on.svg',
                  AppLocalizations.of(context)!.appointments,
                  1,
                  22.h),
              _buildNavItem(
                'assets/icons/health.svg',
                'assets/icons/health-on.svg',
                AppLocalizations.of(context)!.health_tab,
                2,
                22.h,
              ),
              _buildMessagesNavItem(context),
              _buildNavItem(
                isLoggedIn
                    ? 'assets/icons/account.svg'
                    : 'assets/icons/login.svg',
                isLoggedIn
                    ? 'assets/icons/account-on.svg'
                    : 'assets/icons/login-on.svg',
                isLoggedIn
                    ? AppLocalizations.of(context)!.account
                    : AppLocalizations.of(context)!.logIn,
                4,
                isLoggedIn ? 22.h : 17.h,
              ),
            ],
          ),
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
            SvgPicture.asset(
              isSelected
                  ? 'assets/icons/conversation-on.svg'
                  : 'assets/icons/conversation.svg',
              color: isSelected ? AppColors.main : Colors.black,
              height: 18.h,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -8,
                child: AnimatedOpacity(
                  opacity: unreadCount > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
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

  BottomNavigationBarItem _buildNavItem(
      String iconPath, String activeIconPath, String label, int index, double height) {
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        _currentIndex == index ? activeIconPath : iconPath,
        color:
        _currentIndex == index ? AppColors.main : Colors.black,
        height: height,
      ),
      label: label,
    );
  }

  String _getTitle(int index, bool isArabicLocale) {
    switch (index) {
      case 0:
        return AppLocalizations.of(context)!.home;
      case 1:
        return AppLocalizations.of(context)!.appointments;
      case 2:
        return AppLocalizations.of(context)!.health_tab;
      case 3:
        return AppLocalizations.of(context)!.messages;
      case 4:
        return AppLocalizations.of(context)!.account;
      default:
        return AppLocalizations.of(context)!.home;
    }
  }
}
