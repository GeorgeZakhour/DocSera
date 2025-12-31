import 'package:flutter/material.dart';
import 'app/const.dart';

class UserInfoPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserInfoPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> userInfo = [
      {"Role": userData['role'] ?? "Not Specified"},
      {
        "Name": "${userData['firstName'] ?? "Not Provided"} ${userData['lastName'] ?? ""}"
      },
      {"Email": userData['email'] ?? "Not Provided"},
      {"Phone": userData['phone_number'] ?? "Not Provided"},
      {"Gender": userData['gender'] ?? "Not Specified"},
      {"Date of Birth": userData['dateOfBirth'] ?? "Not Provided"},
      if (userData['role'] == 'Doctor') ...[
        {"Speciality": userData['speciality'] ?? "Not Provided"},
        {"Description": userData['description'] ?? "Not Provided"},
        {"Address": userData['address'] ?? "Not Provided"},
      ],
      {
        "Terms Accepted":
        userData['termsAccepted'] == true ? "Yes" : "No"
      },
      if (userData['marketingChecked'] == true)
        {"Marketing Preferences": "Yes"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Info',
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.main,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: userInfo.length,
          itemBuilder: (context, index) {
            final entry = userInfo[index];
            final title = entry.keys.first;
            final value = entry.values.first;

            return Container(
              color: index % 2 == 0 ? Colors.lightGreen[100] : Colors.white,
              padding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
