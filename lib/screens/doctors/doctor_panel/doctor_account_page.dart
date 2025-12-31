import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';

class DoctorAccountPage extends StatelessWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorAccountPage({super.key, this.doctorData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DoctorDrawer(doctorData: doctorData), // ✅ Use Reusable Drawer
      appBar: AppBar(
        backgroundColor: AppColors.main,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.whiteText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),

      /// 🔹 **Main Content**
      body: const Center(
        child: Text(
          "Doctor's Account Settings",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
