import 'package:docsera/screens/doctors/auth/login/doctor_login_page.dart';
import 'package:docsera/screens/doctors/auth/register/doctor_registration_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import '../../../app/const.dart';

class DoctorIdentificationPage extends StatelessWidget {
  const DoctorIdentificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text(
      "Doctor Identification", // Dynamic title
      style: TextStyle(
        color: AppColors.whiteText,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.containerPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Register or Log in as a Doctor',
              style: TextStyle(
                fontSize: AppConstants.titleFontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.blackText,
              ),
            ),
            const SizedBox(height: 20),

            // Register Container
            _buildContainer(
              context,
              'New to Doctor Booking App?',
              'REGISTER',
              AppColors.whiteText,
              AppColors.main,
              const DoctorRegistrationPage(), // Navigates to Doctor Registration
            ),

            // Log In Container
            _buildContainer(
              context,
              'I already have an account',
              'LOG IN',
              AppColors.blackText,
              AppColors.yellow,
              const DoctorLoginPage(), // Navigates to Doctor Login Page
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainer(
      BuildContext context,
      String text,
      String buttonText,
      Color buttonTextColor,
      Color buttonColor,
      Widget nextPage,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.containerPaddingVertical,
        horizontal: AppConstants.containerPaddingHorizontal,
      ),
      decoration: BoxDecoration(
        color: AppColors.background2,
        borderRadius: BorderRadius.circular(AppConstants.containerBorderRadius),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: AppConstants.subTitleFontSize,
              color: AppColors.blackText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                fadePageRoute(nextPage),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(vertical: AppConstants.buttonPaddingVertical),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  buttonText,
                  style: TextStyle(fontSize: 14, color: buttonTextColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
