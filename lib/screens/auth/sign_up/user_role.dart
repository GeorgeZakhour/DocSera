// import 'package:doctor_booking_app/widgets/base_scaffold.dart';
// import 'package:flutter/material.dart';
// import '../../../models/sign_up_info.dart';
// import 'sign_up_phone.dart';
// import '../../../utils/page_transitions.dart';
// import '../../../app/const.dart';
//
// class RoleSelectionPage extends StatelessWidget {
//   final SignUpInfo signUpInfo; // Pass SignUpInfo to store the role
//
//   const RoleSelectionPage({Key? key, required this.signUpInfo}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return BaseScaffold(
//       title: Text(
//         "Sign Up", // Dynamic title
//         style: const TextStyle(
//           color: AppColors.whiteText,
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             const Text(
//               'Are you signing up as a Doctor or a Patient?',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//
//             // Doctor Button
//             ElevatedButton(
//               onPressed: () {
//                 signUpInfo.role = 'Doctor'; // Save role as Doctor
//                 Navigator.push(
//                   context,
//                   fadePageRoute(SignUpFirstPage(signUpInfo: signUpInfo)), // Navigate to first page
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.main,
//                 padding: const EdgeInsets.symmetric(vertical: 12.0),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//               ),
//               child: const SizedBox(
//                 width: double.infinity,
//                 child: Center(
//                   child: Text(
//                     'Doctor',
//                     style: TextStyle(fontSize: 16, color: Colors.white),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//
//             // Patient Button
//             ElevatedButton(
//               onPressed: () {
//                 signUpInfo.role = 'Patient'; // Save role as Patient
//                 Navigator.push(
//                   context,
//                   fadePageRoute(SignUpFirstPage(signUpInfo: signUpInfo)), // Navigate to first page
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.main,
//                 padding: const EdgeInsets.symmetric(vertical: 12.0),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//               ),
//               child: const SizedBox(
//                 width: double.infinity,
//                 child: Center(
//                   child: Text(
//                     'Patient',
//                     style: TextStyle(fontSize: 16, color: Colors.white),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
