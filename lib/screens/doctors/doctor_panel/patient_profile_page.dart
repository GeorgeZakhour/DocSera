import 'package:docsera/app/const.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientProfilePage extends StatelessWidget {
  final String doctorId;
  final String patientId;

  const PatientProfilePage({Key? key, required this.doctorId, required this.patientId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text("Patient Profile", style: TextStyle(color: AppColors.whiteText, fontSize: 16, fontWeight: FontWeight.bold)),
      child: FutureBuilder(
        future: Supabase.instance.client
            .from('patients')
            .select()
            .eq('doctorId', doctorId)
            .eq('id', patientId)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data == null) return const Center(child: Text('Patient not found'));

          var data = snapshot.data as Map<String, dynamic>;
          List visits = data['visits'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// **🔹 Patient Info Card**
                Card(
                  elevation: 0,
                  color: AppColors.background2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),side: BorderSide(color: Colors.grey.shade200, width: 0.8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// **Patient Name (Title)**
                        Row(
                          children: [
                            Icon(Icons.account_circle_rounded, color: AppColors.mainDark),
                            const SizedBox(width: 10),
                            Text(
                              data['patientName'] ?? "Unknown",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.mainDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        /// **Patient Info List**
                        _infoRow("Gender", data['userGender'] ?? "Unknown"),
                        _infoRow("Age", data['userAge']?.toString() ?? "Unknown"),
                        _infoRow("Date of Birth", data['dateOfBirth'] ?? "Unknown"),
                        _infoRow("Phone Number", data['phone_number'] ?? "Unknown"),
                        _infoRow("Email", data['email'] ?? "Unknown"),
                        _infoRow("Number of Visits", visits.length.toString()),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// **🔹 Visits History Card**
                Card(
                  elevation: 0,
                  color: AppColors.background2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),side: BorderSide(color: Colors.grey.shade200, width: 0.8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// **Title: Visits History (X Visits)**
                        Text(
                          "Visits History (${visits.length})",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.mainDark),
                        ),
                        const SizedBox(height: 10),

                        /// **List of Visits**
                        ...visits.asMap().entries.map((entry) {
                          int index = entry.key;
                          var visit = entry.value;

                          return Column(
                            children: [
                              /// **Each Visit Tile**
                              _visitTile(visit),

                              /// **Divider (Except for last item)**
                              if (index < visits.length - 1)
                                Divider(color: Colors.grey.shade300, thickness: 1),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// **🔹 Helper: Display Info Row**
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  /// **🔹 Helper: Visit Tile with Expandable Details**
  Widget _visitTile(Map<String, dynamic> visit) {
    bool isExpanded = false; // Track expansion state

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            /// **Visit Row**
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Visit on ${visit['date'] ?? 'Unknown'}",
                style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 14),
              ),
              subtitle: Text(visit['reason'] ?? "No reason provided"),
              trailing: IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.chevron_right,
                  color: AppColors.main,
                ),
                onPressed: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
              ),
            ),

            /// **Expanded Details**
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow("Date of Visit", visit['date'] ?? "Unknown"),
                    _infoRow("Reason", visit['reason'] ?? "Unknown"),
                    _infoRow("Notes", visit['notes'] ?? "No notes added"),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
