import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorDashboard extends StatefulWidget {
  Map<String, dynamic>? doctorData;

  DoctorDashboard({Key? key,this.doctorData}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  Map<String, dynamic>? doctorData;
  bool isExpanded = false;
  String? doctorId;
  List<Map<String, dynamic>> appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  /// **🔹 Fetch logged-in doctor data from Firestore**
  Future<void> _fetchDoctorData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedDoctorId = prefs.getString('doctorId');

    if (storedDoctorId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('doctors')
          .select()
          .eq('id', storedDoctorId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          doctorId = storedDoctorId;
          doctorData = response;
        });
        _fetchAppointments();
      }
    } catch (e) {
      print("❌ Error fetching doctor data: $e");
    }
  }

  /// **🔹 Fetch doctor's appointments**
  Future<void> _fetchAppointments() async {
    final String? id = doctorId;
    if (id == null) return;

    try {
      final response = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('doctorId', id)
          .order('timestamp', ascending: true);

      setState(() {
        appointments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("❌ Error fetching appointments: $e");
    }
  }


  /// **🔹 Build Appointment Card**
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    bool isBooked = appointment['booked'] ?? false;
    bool isExpanded = false; // ✅ Expand/Collapse state

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          elevation: 0,
          color: AppColors.background2, // ✅ Updated Background Color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300, width: 0.8), // ✅ Thin Border
          ),
          child: Column(
            children: [
              // 🔹 **Main Row**
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔹 Status Icon & Time
                    Row(
                      children: [
                        Icon(
                          isBooked ? Icons.event_busy : Icons.event_available,
                          color: isBooked ? AppColors.red : AppColors.main,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          appointment['time'] ?? "Unknown Time",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // 🔹 "Show Details >" Button (Only if booked)
                    if (isBooked)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpanded = !isExpanded; // ✅ Toggle expand state
                          });
                        },
                        child: Text(
                          isExpanded ? "Hide Details ▲" : "Show Details >",
                          style: TextStyle(
                            color: AppColors.main,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 🔹 **Expanded Section**
              if (isExpanded && isBooked) _buildExpandedDetails(appointment),
            ],
          ),
        );
      },
    );
  }

  /// 🔹 **Helper: Expanded Details**
  Widget _buildExpandedDetails(Map<String, dynamic> appointment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow("Patient", appointment['patientName']),
          _infoRow("Account Holder", appointment['accountName']),
          _infoRow("Age", "${appointment['userAge']} years"),
          _infoRow("Gender", appointment['userGender']),
          _infoRow("Date", appointment['date']),
          _infoRow("Reason", appointment['reason']),
          _infoRow("Booking Time", _formatTimestamp(appointment['bookingTimestamp'])),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    try {
      if (timestamp is String) {
        return DateFormat("yyyy-MM-dd HH:mm").format(DateTime.parse(timestamp));
      } else if (timestamp is DateTime) {
        return DateFormat("yyyy-MM-dd HH:mm").format(timestamp);
      } else {
        return "Invalid date";
      }
    } catch (e) {
      return "Invalid date";
    }
  }


  /// **🔹 Helper for displaying info rows**
  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? "Unknown", overflow: TextOverflow.ellipsis, maxLines: 2)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.whiteText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Doctor Dashboard",
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),

      /// 🔹 **Drawer Menu (Burger Menu)**
      drawer: DoctorDrawer(doctorData: doctorData), // ✅ Use Reusable Drawer

      /// 🔹 **Main Content**
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: CircleAvatar(
                  backgroundColor: AppColors.main.withOpacity(0.2),
                  radius: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: doctorData != null
                        ? Image.asset(
                      _getDoctorAvatar(doctorData!),
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                        : const CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Your Appointments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: appointments.isEmpty
                  ? const Center(child: Text("No appointments available"))
                  : ListView.builder(
                itemCount: appointments.length,
                itemBuilder: (context, index) {
                  return _buildAppointmentCard(appointments[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **🔹 Helper: Get Doctor Avatar**
  String _getDoctorAvatar(Map<String, dynamic> doctor) {
    return getDoctorImage(
      imageUrl: doctor['profileImage'],
      gender: doctor['gender'],
      title: doctor['title'],
    );
  }
}
