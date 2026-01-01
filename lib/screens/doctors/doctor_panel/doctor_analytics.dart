import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorAnalyticsPage extends StatefulWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorAnalyticsPage({super.key, this.doctorData});

  @override
  _DoctorAnalyticsPageState createState() => _DoctorAnalyticsPageState();
}

class _DoctorAnalyticsPageState extends State<DoctorAnalyticsPage> {
  String? doctorId;
  int totalPatients = 0;
  int totalAppointments = 0;
  int attendedAppointments = 0;
  Map<String, int> appointmentTypes = {};
  Map<String, int> genderDistribution = {'Male': 0, 'Female': 0};
  Map<String, int> ageGroups = {'0-18': 0, '19-35': 0, '36-50': 0, '51+': 0};

  int? selectedIndexAppointments; // ✅ لكل مخطط فهرس مستقل
  int? selectedIndexGender;


  @override
  void initState() {
    super.initState();
    _fetchDoctorAnalytics();
  }

  Future<void> _fetchDoctorAnalytics() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    doctorId = prefs.getString('doctorId');

    final localDoctorId = doctorId;
    if (localDoctorId == null) {
      debugPrint("❌ Doctor ID not found.");
      return;
    }

    try {
      debugPrint("🚀 Fetching patients for doctor ID: $localDoctorId");
      final patientResponse = await Supabase.instance.client
          .from('patients')
          .select('id')
          .eq('doctorId', localDoctorId);

      totalPatients = patientResponse.length;
      debugPrint("✅ Total Patients Loaded: $totalPatients");

      debugPrint("🚀 Fetching appointments...");
      final appointmentResponse = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('doctorId', localDoctorId)
          .eq('booked', true);

      totalAppointments = appointmentResponse.length;
      debugPrint("✅ Total Booked Appointments Loaded: $totalAppointments");

      for (var data in appointmentResponse) {
        debugPrint("📄 Appointment Data: $data");

        bool attended = data['attended'] == true;
        if (attended) attendedAppointments++;

        // ✅ نوع الموعد
        String type = data['reason'] ?? 'Other';
        appointmentTypes[type] = (appointmentTypes[type] ?? 0) + 1;

        // ✅ توزيع الجنس
        String gender = data['userGender'] ?? '';
        genderDistribution[gender] = (genderDistribution[gender] ?? 0) + 1;

        // ✅ توزيع العمر
        int age = data['userAge'] ?? 0;
        if (age <= 18) {
          ageGroups['0-18'] = (ageGroups['0-18'] ?? 0) + 1;
        } else if (age <= 35) {
          ageGroups['19-35'] = (ageGroups['19-35'] ?? 0) + 1;
        } else if (age <= 50) {
          ageGroups['36-50'] = (ageGroups['36-50'] ?? 0) + 1;
        } else {
          ageGroups['51+'] = (ageGroups['51+'] ?? 0) + 1;
        }
      }

      debugPrint("✅ Attended Appointments: $attendedAppointments");
      debugPrint("📊 Appointments by Type: $appointmentTypes");
      debugPrint("📊 Gender Distribution: $genderDistribution");
      debugPrint("📊 Age Group Distribution: $ageGroups");

      setState(() {});
    } catch (e) {
      debugPrint("❌ Error fetching analytics: $e");
    }
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
          "Analytics",
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector( // ✅ الضغط خارج المخطط يرجع كل شيء للوضع الطبيعي
        onTap: () => setState(() {
          selectedIndexAppointments = null;
          selectedIndexGender = null;
        }),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCards(),
                const SizedBox(height: 20),
                _buildPieChart("Appointments by Type", appointmentTypes, selectedIndexAppointments, (index) {
                  setState(() => selectedIndexAppointments = index);
                }),
                const SizedBox(height: 20),
                _buildPieChart("Gender Distribution", genderDistribution, selectedIndexGender, (index) {
                  setState(() => selectedIndexGender = index);
                }),
                const SizedBox(height: 20),
                _buildBarChart("Age Group Distribution", ageGroups),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statCard("Patients", totalPatients.toString(), Icons.people),
        _statCard("Appointments", totalAppointments.toString(), Icons.calendar_today),
        _statCard("Attended", "$attendedAppointments/$totalAppointments", Icons.check_circle),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: AppColors.mainDark, size: 30),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSubColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(String title, Map<String, int> data, int? selectedIndex, Function(int?) onSelectionChange) {
    debugPrint("📊 Rendering Pie Chart: $title -> $data");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () => setState(() => onSelectionChange(null)), // ✅ عند الضغط خارج المخطط، يرجع للحجم الطبيعي
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: _getPieChartSections(data, selectedIndex),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlTapUpEvent) { // ✅ النقر العادي يحدد الجزء
                      if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                        setState(() => onSelectionChange(null)); // ✅ إلغاء التحديد عند الضغط خارج الدائرة
                      } else {
                        setState(() {
                          onSelectionChange(pieTouchResponse.touchedSection!.touchedSectionIndex);
                        });
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        if (selectedIndex != null && selectedIndex >= 0 && selectedIndex < data.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mainDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  data.keys.toList()[selectedIndex],
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<PieChartSectionData> _getPieChartSections(Map<String, int> data, int? selectedIndex) {
    List<Color> themeColors = [
      AppColors.main.withOpacity(0.8),
      AppColors.mainDark.withOpacity(0.8),
      AppColors.yellow.withOpacity(0.8),
      AppColors.background3
    ];

    int total = data.values.fold(0, (sum, value) => sum + value);

    return data.entries.map((entry) {
      int index = data.keys.toList().indexOf(entry.key);
      double percentage = (entry.value / total) * 100;
      bool isSelected = selectedIndex == index;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: "${percentage.toStringAsFixed(1)}% (${entry.value})",
        color: themeColors[index % themeColors.length],
        radius: isSelected ? 65 : 50, // ✅ التكبير عند الضغط فقط
        titleStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.orange : Colors.white, // ✅ تغيير لون النص عند الضغط
        ),
      );
    }).toList();
  }

  Widget _buildBarChart(String title, Map<String, int> data) {
    debugPrint("📊 Rendering Bar Chart: $title -> $data");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(height: 200, child: BarChart(BarChartData(barGroups: _getBarChartGroups(data)))),
      ],
    );
  }

  List<BarChartGroupData> _getBarChartGroups(Map<String, int> data) {
    return data.entries.map((entry) {
      return BarChartGroupData(x: data.keys.toList().indexOf(entry.key), barRods: [BarChartRodData(toY: entry.value.toDouble())]);
    }).toList();
  }
}
