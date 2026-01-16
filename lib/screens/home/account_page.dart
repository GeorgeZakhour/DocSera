import 'dart:async';
import 'dart:io';
import 'package:docsera/Business_Logic/Account_page/danger/account_danger_cubit.dart';

import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_state.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_state.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/home/account/goodbye_page.dart';
import 'package:docsera/screens/home/account/legal_information.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/account/user_profile_page.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Business_Logic/Account_page/user_cubit.dart';
import '../../Business_Logic/Account_page/user_state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'account/preferences.dart';

// 🆕 NEW COMPONENTS
import 'account/widgets/account_banner_card.dart';
import 'account/widgets/points_card.dart';
import 'account/widgets/account_section_title.dart';
import 'account/widgets/account_list_tile.dart';
import 'account/sheets/edit_contact_info_sheet.dart';
import 'account/sheets/change_password_sheet.dart';
import 'account/sheets/language_selection_sheet.dart';
import 'account/sheets/security_info_sheets.dart';
import 'account/sheets/delete_account_sheet.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AccountScreen({super.key, required this.onLogout});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String biometricType = "Biometric Authentication"; // Default fallback
  IconData biometricIcon = Icons.fingerprint; // Default icon
  bool _biometricChecked = false;
  String currentLocale = "en"; // Default
  String appVersion = '';

  @override
  void initState() {
    super.initState();

    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;

    if (authState is AuthAuthenticated) {
      // 🔹 Load primary user data
      context.read<UserCubit>().loadUserData(context: context);

      // 🔹 Load profile tabs immediately
      context.read<AccountProfileCubit>().loadProfile();
    }

    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        appVersion = 'v${info.version}';
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    String newLocale = Localizations.localeOf(context).languageCode;

    if (!_biometricChecked || newLocale != currentLocale) {
      currentLocale = newLocale; // Update stored locale
      Future.delayed(Duration.zero, _detectBiometricType); // ✅ Ensure localization is loaded
      _biometricChecked = true;
    }
  }

  Future<void> _detectBiometricType() async {
    try {
      List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
      if (!mounted) return;

      debugPrint("✅ Available Biometrics: $availableBiometrics");

      String detectedType;
      IconData detectedIcon;

      if (Platform.isIOS) {
        if (availableBiometrics.contains(BiometricType.face)) {
          detectedType = AppLocalizations.of(context)!.faceIdTitle;
          detectedIcon = Icons.face;
        } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
          detectedType = AppLocalizations.of(context)!.fingerprintTitle;
          detectedIcon = Icons.fingerprint;
        } else {
          detectedType = AppLocalizations.of(context)!.biometricTitle;
          detectedIcon = Icons.lock;
        }
      } else if (Platform.isAndroid) {
        if (availableBiometrics.contains(BiometricType.strong)) {
          detectedType = AppLocalizations.of(context)!.fingerprintTitle;
          detectedIcon = Icons.fingerprint;
        } else if (availableBiometrics.contains(BiometricType.weak)) {
          detectedType = AppLocalizations.of(context)!.faceIdTitle;
          detectedIcon = Icons.face;
        } else {
          detectedType = AppLocalizations.of(context)!.biometricTitle;
          detectedIcon = Icons.lock;
        }
      } else {
        detectedType = AppLocalizations.of(context)!.biometricTitle;
        detectedIcon = Icons.lock;
      }

      // ✅ Save biometric type in SharedPreferences for login page
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('biometricType', detectedType);

      setState(() {
        biometricType = detectedType;
        biometricIcon = detectedIcon;
      });

      debugPrint("✅ Biometric Type Set & Saved: $biometricType");
    } catch (e) {
      debugPrint("❌ Biometric detection error: $e");
    }
  }

  String _mapSecurityError(BuildContext context, String code) {
    switch (code) {
      case 'INVALID_OTP':
        return AppLocalizations.of(context)!.invalidOtp;
      case 'OTP_REQUEST_FAILED':
        return AppLocalizations.of(context)!.otpRequestFailed;
      case 'PHONE_ALREADY_EXISTS':
        return AppLocalizations.of(context)!.alreadyExistsPhone;
      case 'EMAIL_ALREADY_EXISTS':
        return AppLocalizations.of(context)!.alreadyExistsEmail;
      case 'TWO_FACTOR_UPDATE_FAILED':
        return AppLocalizations.of(context)!.twoFactorUpdateFailed;
      default:
        return AppLocalizations.of(context)!.somethingWentWrong;
    }
  }

  String _formatPhoneForDisplay(String rawPhone) {
    if (rawPhone.startsWith('00963')) {
      return '0${rawPhone.substring(5)}'; // 0096398765432 → 098765432
    }
    return rawPhone;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppAuthState>(
      builder: (context, authState) {

        if (authState is AuthUnauthenticated) {
          return Scaffold(
            backgroundColor: AppColors.background2,
            body: _buildLoginPrompt(context),
          );
        }

        if (authState is AuthLoading || authState is AuthInitial) {
          return Scaffold(
            backgroundColor: AppColors.background2,
            body: _buildShimmerLoading(),
          );
        }

        if (authState is AuthAuthenticated) {
          return _AuthenticatedAccountView(
            onLogout: widget.onLogout,
            buildShimmer: _buildShimmerLoading,
            buildAccountContent: _buildAccountContent,
            mapSecurityError: _mapSecurityError,
            biometricType: biometricType,
            biometricIcon: biometricIcon,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAccountContent(BuildContext context, UserLoaded state) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              SizedBox(height: 5.h),
              const AccountBannerCard(),
              SizedBox(height: 5.h),
              PointsCard(userPoints: state.userPoints, userId: state.userId),
              Divider(color: Colors.grey[200], height: 2.h),

              AccountSectionTitle(title: AppLocalizations.of(context)!.personalInformation),
              Divider(color: Colors.grey[200], height: 2.h),

              // My Profile
              BlocBuilder<AccountProfileCubit, AccountProfileState>(
                builder: (context, profileState) {
                  final subtitle = profileState is AccountProfileLoaded
                      ? profileState.fullName
                      : AppLocalizations.of(context)!.loading;

                  return AccountListTile(
                    icon: Icons.person,
                    title: AppLocalizations.of(context)!.myProfile,
                    subtitle: subtitle,
                    onTap: () => Navigator.push(context, fadePageRoute(const UserProfilePage())),
                  );
                },
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // My Relatives
              AccountListTile(
                icon: Icons.people,
                title: AppLocalizations.of(context)!.myRelatives,
                subtitle: AppLocalizations.of(context)!.myRelativesDescription,
                onTap: () => Navigator.push(context, fadePageRoute(const MyRelativesPage())),
              ),
              Divider(color: Colors.grey[200], height: 2.h),
              const SizedBox(height: 15),

              AccountSectionTitle(title: AppLocalizations.of(context)!.loginSection),
              Divider(color: Colors.grey[200], height: 2.h),

              // Phone
              BlocBuilder<AccountProfileCubit, AccountProfileState>(
                builder: (context, profileState) {
                  final phone = profileState is AccountProfileLoaded ? profileState.phone : '';
                  final isVerified = profileState is AccountProfileLoaded ? profileState.isPhoneVerified : false;
                  final subtitle = phone.isEmpty ? AppLocalizations.of(context)!.notProvided : _formatPhoneForDisplay(phone);

                  return AccountListTile(
                    icon: Icons.phone,
                    title: AppLocalizations.of(context)!.phone,
                    subtitle: subtitle,
                    isVerified: isVerified,
                    onTap: () {
                      if (profileState is AccountProfileLoaded) {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.background2,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) => EditContactInfoSheet(
                              fieldType: 'phoneNumber',
                              currentValue: profileState.phone
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // Email
              BlocBuilder<AccountProfileCubit, AccountProfileState>(
                builder: (context, profileState) {
                  final email = profileState is AccountProfileLoaded ? profileState.email : '';
                  final isVerified = profileState is AccountProfileLoaded ? profileState.isEmailVerified : false;
                  final subtitle = email.isEmpty ? AppLocalizations.of(context)!.notProvided : email;

                  return AccountListTile(
                    icon: Icons.email,
                    title: AppLocalizations.of(context)!.email,
                    subtitle: subtitle,
                    isVerified: isVerified,
                    onTap: () {
                      if (profileState is AccountProfileLoaded) {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.background2,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) => EditContactInfoSheet(
                            fieldType: 'email',
                            currentValue: profileState.email,
                            customTitle: email.isEmpty ? AppLocalizations.of(context)!.addEmailTitle : null,
                          ),
                        );
                      }
                    },
                  );
                },
              ),

              Divider(color: Colors.grey[200], height: 2.h),

              // Change Password
              AccountListTile(
                icon: Icons.lock,
                title: AppLocalizations.of(context)!.password,
                subtitle: AppLocalizations.of(context)!.passwordHidden,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.background2,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => const ChangePasswordSheet(),
                ),
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              const SizedBox(height: 15),
              AccountSectionTitle(title: AppLocalizations.of(context)!.settings),
              Divider(color: Colors.grey[200], height: 2.h),

              // Language
              AccountListTile(
                icon: Icons.language,
                title: AppLocalizations.of(context)!.language,
                subtitle: AppLocalizations.of(context)!.languageDescription,
                onTap: () => showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  backgroundColor: Colors.white,
                  builder: (_) => const LanguageSelectionSheet(),
                ),
                trailingWidget: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? "العربية" : "English",
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500, color: AppColors.grayMain),
                ),
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // Two Factor Auth
              AccountListTile(
                  icon: Icons.key,
                  title: AppLocalizations.of(context)!.twoFactorAuth,
                  subtitle: state.is2FAEnabled ? AppLocalizations.of(context)!.activated : AppLocalizations.of(context)!.notActivated,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => TwoFactorAuthSheet(is2FAEnabled: state.is2FAEnabled),
                  ),
                  trailingWidget: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: state.is2FAEnabled ? const Color(0xFFDFF6F3) : const Color(0xFFFFF4D9),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      state.is2FAEnabled ? AppLocalizations.of(context)!.activated : AppLocalizations.of(context)!.notActivated,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: state.is2FAEnabled ? const Color(0xFF00B7A0) : AppColors.yellow,
                        fontWeight: FontWeight.w400,
                        fontSize: 8,
                      ),
                    ),
                  )
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // Encrypted Documents
              AccountListTile(
                  icon: Icons.security,
                  title: AppLocalizations.of(context)!.encryptedDocuments,
                  subtitle: AppLocalizations.of(context)!.encryptedDocumentsDescription,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const EncryptedDocumentsSheet(),
                  ),
                  trailingWidget: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF6F3),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.activated,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: const Color(0xFF00B7A0),
                        fontWeight: FontWeight.w400,
                        fontSize: 8,
                      ),
                    ),
                  )
              ),

              Divider(color: Colors.grey[200], height: 2.h),

              // Biometrics (Face ID / Fingerprint)
              AccountListTile(
                  icon: biometricIcon,
                  title: biometricType,
                  subtitle: biometricType == AppLocalizations.of(context)!.faceIdTitle
                      ? AppLocalizations.of(context)!.faceIdDescription
                      : AppLocalizations.of(context)!.fingerprintDescription,
                  isFaceId: true,
                  trailingWidget: BlocBuilder<AccountSecurityCubit, AccountSecurityState>(
                    builder: (context, state) {
                      final bool isEnabled = state is AccountBiometricState && state.enabled;
                      final bool isLoading = state is AccountBiometricChecking;

                      return Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isEnabled,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (context.mounted) {
                                      context.read<AccountSecurityCubit>().toggleBiometric(enable: value);
                                  }
                              },
                          activeColor: Colors.white,
                          activeTrackColor: AppColors.main.withValues(alpha: 0.8),
                          inactiveTrackColor: Colors.grey[400],
                          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.main;
                            }
                            return Colors.grey[400]!;
                          }),
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                            return const Icon(
                              Icons.circle,
                              size: 30,
                              color: Colors.white,
                            );
                          }),
                        ),
                      );
                    },
                  )
              ),

              Divider(color: Colors.grey[200], height: 2.h),

              SizedBox(height: 15.h),
              AccountSectionTitle(title: AppLocalizations.of(context)!.confidentiality),
              Divider(color: Colors.grey[200], height: 2.h),

              // My Preferences
              _buildPrivacyItem(
                AppLocalizations.of(context)!.myPreferences,
                    () {
                  Navigator.push(context, fadePageRoute(const MyPreferencesPage()));
                },
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // Legal Information
              _buildPrivacyItem(
                AppLocalizations.of(context)!.legalInformation,
                    () {
                  Navigator.push(context, fadePageRoute(const LegalInformation()));
                },
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              // Delete Account
              _buildPrivacyItem(
                AppLocalizations.of(context)!.deleteMyAccount,
                    () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  ),
                  isScrollControlled: true,
                  builder: (_) => const DeleteAccountSheet(),
                ),
              ),

              Divider(color: Colors.grey[200], height: 2.h),

              SizedBox(height: 25.h),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<UserCubit>().logout();
                    widget.onLogout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 12.h),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.logOut,
                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText),
                  ),
                ),
              ),

              if (appVersion.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 10.h, bottom: 20.h),
                  child: Center(
                    child: Text(
                      appVersion,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.grey,
                        fontSize: 9.sp,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color:  AppColors.blackText,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// **🔹 Builds the UI shown when the user is logged out**
  Widget _buildLoginPrompt(BuildContext context) {
    return ClipPath(
      clipper: CustomTopBarClipper(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        width: double.infinity,
        color: AppColors.main,
        padding: EdgeInsets.symmetric(vertical: 30.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 80.sp, color: Colors.white),
            SizedBox(height: 10.h),
            Text(AppLocalizations.of(context)!.welcomeDocsera, style: AppTextStyles.getTitle3(context).copyWith(color: Colors.white)),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Text(
                AppLocalizations.of(context)!.welcome_subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.white70),
              ),
            ),
            SizedBox(height: 20.h),
            _buildBenefitsList(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.login, color: AppColors.main),
              label: Text(AppLocalizations.of(context)!.login_button,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 35.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  fadePageRoute(SignUpFirstPage(signUpInfo: SignUpInfo())),
                );
              },
              child: Text(AppLocalizations.of(context)!.signup_button,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.white)),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurEffect() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),
          SizedBox(height: 10.h),
          ...List.generate(2, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),
          SizedBox(height: 10.h),
          ...List.generate(3, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),          SizedBox(height: 10.h),
          ...List.generate(4, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return _buildBlurEffect();
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: Colors.white),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
              softWrap: true,
              overflow: TextOverflow.visible,),
          )
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Localizations.localeOf(context).languageCode == 'ar' ? 100.w : 80.w,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBenefitItem(Icons.event_available, AppLocalizations.of(context)!.benefit_appointments),
                _buildBenefitItem(Icons.notifications_active, AppLocalizations.of(context)!.benefit_reminders),
                _buildBenefitItem(Icons.history, AppLocalizations.of(context)!.benefit_history),
                _buildBenefitItem(Icons.chat, AppLocalizations.of(context)!.benefit_chat),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedAccountView extends StatelessWidget {
  final VoidCallback onLogout;
  final Widget Function() buildShimmer;
  final Widget Function(BuildContext, UserLoaded) buildAccountContent;
  final String Function(BuildContext, String) mapSecurityError;
  final String biometricType;
  final IconData biometricIcon;

  const _AuthenticatedAccountView({
    required this.onLogout,
    required this.buildShimmer,
    required this.buildAccountContent,
    required this.mapSecurityError,
    required this.biometricType,
    required this.biometricIcon,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 👤 User loaded → load account profile
        BlocListener<UserCubit, UserState>(
          listenWhen: (_, current) => current is UserLoaded,
          listener: (context, state) {
            context.read<AccountProfileCubit>().loadProfile();
          },
        ),

        // 🔐 Account Security listeners
        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountSecurityError,
          listener: (context, s) {
            final error = s as AccountSecurityError;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    mapSecurityError(context, error.message),
                  ),
                  backgroundColor: AppColors.red,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountPasswordChanged,
          listener: (context, s) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.passwordUpdatedSuccess,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) =>
          s is AccountOtpSent || s is AccountOtpVerified,
          listener: (context, s) {
            if (s is AccountOtpSent) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 20),
                    backgroundColor: AppColors.mainDark,
                    content: Text('OTP: ${s.otp}'),
                  ),
                );
            }

            if (s is AccountOtpVerified) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountTwoFactorUpdated,
          listener: (context, s) {
            final state = s as AccountTwoFactorUpdated;

            // Pops are handled in sheets now, except typically we don't pop here unless we were on a waiting screen.
            // The sheet calls Navigator.pop for itself.
            // But if there is a lingering loading dialog or snackbar...
            // In original code: Navigator.pop(context); // This was closing the sheet I presume?
            // "TwoFactorAuthSheet" handles the toggle. It does NOT close automatically on success in original code, it just showed snackbar?
            // Wait, original code for 2FA sheet had: check Toggle -> wait -> Listener hears Update -> Pop -> Load -> Snackbar.
            // So YES I need to Pop here if the sheet is open.
            // But how do I know if the sheet is open? Use Navigator.pop(context) blindly might pop the page if sheet isn't open.
            // However, 2FA toggle only happens FROM the sheet. So it's safe to assume sheet is open.
            
            Navigator.pop(context); // Close the sheet

            context.read<UserCubit>().loadUserData(
              context: context,
              useCache: false,
            );

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.enabled
                        ? AppLocalizations.of(context)!
                        .twoFactorActivatedSuccess
                        : AppLocalizations.of(context)!
                        .twoFactorDeactivatedSuccess,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountBiometricUpdated,
          listener: (context, s) {
            final state = s as AccountBiometricUpdated;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.enabled
                        ? AppLocalizations.of(context)!.faceIdEnabled
                        : AppLocalizations.of(context)!.faceIdDisabled,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        // ☠️ Account danger
        BlocListener<AccountDangerCubit, AccountDangerState>(
          listener: (context, s) async {
            if (s is AccountDangerError) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(s.message),
                    backgroundColor: AppColors.red,
                  ),
                );
            }

            if (s is AccountDangerSuccess) {
              await context.read<AuthCubit>().signOut();

              Navigator.pushAndRemoveUntil(
                context,
                fadePageRoute(const GoodbyePage()),
                    (_) => false,
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background2,
        body: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              return buildShimmer();
            }

            if (state is UserLoaded) {
              return buildAccountContent(context, state);
            }

            return buildShimmer();
          },
        ),
      ),
    );
  }
}
