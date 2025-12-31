import 'package:docsera/app/const.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:docsera/screens/doctors/doctor_panel/patient_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientsPage extends StatefulWidget {
  final Map<String, dynamic>? doctorData;

  const PatientsPage({super.key, this.doctorData});

  @override
  _PatientsPageState createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  String? doctorId;
  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> filteredPatients = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// **🔹 Fetch Patients from Firestore**
  Future<void> _fetchPatients() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    doctorId = prefs.getString('doctorId');

    final localDoctorId = doctorId;
    if (localDoctorId == null) {
      print("❌ Doctor ID not found.");
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('id, patientName, userGender, userAge')
          .eq('doctorId', localDoctorId);

      List<Map<String, dynamic>> patientList = (response as List<dynamic>).map((data) {
        return {
          'id': data['id'],
          'patientName': data['patientName'],
          'userGender': data['userGender'],
          'userAge': data['userAge'].toString(),
        };
      }).toList();

      // ✅ Sort Alphabetically
      patientList.sort((a, b) => a['patientName'].compareTo(b['patientName']));

      setState(() {
        patients = patientList;
        filteredPatients = patientList;
      });

      print("✅ Loaded ${patients.length} patients.");
    } catch (e) {
      print("❌ Error fetching patients: $e");
    }
  }

  /// **🔍 Filter Patients Based on Search**
  void _filterPatients() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredPatients = patients
          .where((patient) =>
          patient['patientName'].toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DoctorDrawer(doctorData: widget.doctorData),
      appBar: AppBar(
        backgroundColor: AppColors.main,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.whiteText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Patients",
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          /// **🔍 Search Bar**
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search Patients...",
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.main),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(25),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.main),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          /// **📃 Patients List**
          /// **📃 Patients List**
          Expanded(
            child: filteredPatients.isEmpty
                ? const Center(
              child: Text(
                "No matching patients found.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            )
                : ListView.separated(
              physics: const BouncingScrollPhysics(), // ✅ Smooth scrolling
              itemCount: filteredPatients.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey.shade300, // ✅ Light gray divider
                thickness: 0.5, // ✅ Thinner divider
                indent: 15,
                endIndent: 15,
              ),
              itemBuilder: (context, index) {
                var patient = filteredPatients[index];

                return ListTile(
                  dense: true, // ✅ Reduces overall height
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 1), // ✅ Reduce space further
                  leading: const Icon(Icons.person, color: AppColors.main, size: 18), // ✅ Smaller icon
                  title: Text(
                    patient['patientName'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), // ✅ Make text smaller
                  ),
                  subtitle: Text(
                    "(${patient['userGender']}, ${patient['userAge']})",
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.main), // ✅ Smaller arrow
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientProfilePage(
                          patientId: patient['id'],
                          doctorId: doctorId!,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),


        ],
      ),
    );
  }
}
