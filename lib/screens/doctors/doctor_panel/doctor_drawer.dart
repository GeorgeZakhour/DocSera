import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_dashboard.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_appointments.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_messages_page.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_analytics.dart';
import 'package:docsera/screens/doctors/doctor_panel/patients_page.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_account_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Business_Logic/Doctor/Messages_page/doctor_messages_cubit.dart';

class DoctorDrawer extends StatelessWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorDrawer({Key? key, this.doctorData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background2,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(doctorData),
          _buildDrawerItem(Icons.dashboard, "Dashboard", context,  DoctorDashboard(doctorData: doctorData)),
          _buildDrawerItem(Icons.event_available, "Appointments", context, DoctorAppointments(doctorData: doctorData)),
          _buildDrawerItem(Icons.people, "Patients", context,  PatientsPage(doctorData: doctorData)),
          _buildDrawerItem(
            Icons.chat,
            "Messages",
            context,
            BlocProvider(
              create: (_) => DoctorMessagesCubit(doctorId: doctorData?['id']),
              child: DoctorMessagesPage(doctorData: doctorData),
            ),
          ),
          _buildDrawerItem(Icons.bar_chart, "Analytics", context,  DoctorAnalyticsPage(doctorData: doctorData)),
          _buildDrawerItem(Icons.settings, "Account", context,  DoctorAccountPage(doctorData: doctorData)),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: const Text("Log Out", style: TextStyle(color: AppColors.red)),
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('doctorId'); // Clear saved doctor ID
              await prefs.setBool('isDoctorLoggedIn', false); // Mark doctor as logged out

              Navigator.pushAndRemoveUntil(
                context,
                fadePageRoute( CustomBottomNavigationBar()), // ✅ Navigate to home page
                    (route) => false, // Remove all previous routes
              );
            },
          ),

        ],
      ),
    );
  }

  /// **🔹 Drawer Header (Handles Null Data)**
  Widget _buildDrawerHeader(Map<String, dynamic>? doctorData) {
    print("🛠️ Debug: Building Drawer Header with doctorData -> $doctorData");

    String doctorName = "Doctor";
    String specialty = "Specialty";
    ImageProvider<Object> avatarImage = const AssetImage("assets/images/male-doc.png");

    if (doctorData != null) {
      // ✅ Get Name & Specialty Safely
      doctorName =
          "${doctorData['title'] ?? ''} ${doctorData['first_name'] ?? 'Doctor'} ${doctorData['last_name'] ?? ''}".trim();
      specialty = doctorData['specialty'] ?? "Specialty";

      final imageResult = resolveDoctorImagePathAndWidget(
        doctor: {
          'doctor_image': doctorData['doctor_image'],
          'gender': doctorData['gender'],
          'title': doctorData['title'],
        },
        width: 60,
        height: 60,
      );

      avatarImage = imageResult.imageProvider;

    }

    print("📸 Selected Avatar: $avatarImage");

    return DrawerHeader(
      decoration: BoxDecoration(color: AppColors.main),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.5),
            radius: 30,
            backgroundImage: avatarImage,

          ),
          const SizedBox(height: 10),
          Text(
            doctorName,
            style: const TextStyle(
                color: AppColors.whiteText,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          Text(
            specialty,
            style:
            const TextStyle(color: AppColors.whiteText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// **🔹 Drawer Item Helper**
  Widget _buildDrawerItem(IconData icon, String title, BuildContext context, Widget page) {
    return ListTile(
      leading: Icon(icon, color: AppColors.mainDark),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.push(context, fadePageRoute(page));
      },
    );
  }
}

