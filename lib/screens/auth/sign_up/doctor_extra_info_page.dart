// import 'package:doctor_booking_app/screens/auth/sign_up/sign_up_email.dart';
// import 'package:doctor_booking_app/screens/auth/sign_up/sign_up_phone.dart';
// import 'package:doctor_booking_app/widgets/base_scaffold.dart';
// import 'package:flutter/material.dart';
// import '../../../models/sign_up_info.dart';
// import 'create_password.dart';
// import '../../../utils/page_transitions.dart';
// import '../../../app/const.dart';
//
// class DoctorExtraInfoPage extends StatefulWidget {
//   final SignUpInfo signUpInfo; // Pass SignUpInfo to collect extra doctor data
//
//   const DoctorExtraInfoPage({Key? key, required this.signUpInfo}) : super(key: key);
//
//   @override
//   State<DoctorExtraInfoPage> createState() => _DoctorExtraInfoPageState();
// }
//
// class _DoctorExtraInfoPageState extends State<DoctorExtraInfoPage> {
//   final TextEditingController _otherSpecialityController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//
//   String? _selectedSpeciality; // Track selected speciality
//   bool isFormValid = false; // Track overall form validity
//   bool isOtherSpeciality = false; // Track if "Other" is selected for speciality
//
//   final List<String> specialities = [
//     "Cardiology",
//     "Dermatology",
//     "Neurology",
//     "Pediatrics",
//     "Orthopedics",
//     "Psychiatry",
//     "Radiology",
//     "Surgery",
//     "Urology",
//     "Ophthalmology",
//     "Other", // Last option for custom speciality
//   ];
//
//   /// Validate form
//   void _validateForm() {
//     setState(() {
//       isFormValid =
//           _selectedSpeciality != null &&
//               (isOtherSpeciality ? _otherSpecialityController.text.isNotEmpty : true) &&
//               _addressController.text.isNotEmpty; // Removed description from required fields
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BaseScaffold(
//       title: Text(
//         "Sign Up", // Dynamic title
//       style: const TextStyle(
//         color: AppColors.whiteText,
//         fontWeight: FontWeight.bold,
//         fontSize: 16,
//       ),
//     ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Provide additional information to complete your profile:',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 20),
//
//               // Speciality Dropdown
//               const Text("Speciality", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 10),
//               _buildDropdownValidatedField(
//                 value: _selectedSpeciality,
//                 hint: "Select Speciality",
//                 items: specialities.map((speciality) {
//                   return DropdownMenuItem(value: speciality, child: Text(speciality));
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedSpeciality = value;
//                     widget.signUpInfo.speciality = value == "Other" ? null : value; // Update speciality
//                     isOtherSpeciality = value == "Other"; // Track if "Other" is selected
//                   });
//                   _validateForm();
//                 },
//               ),
//               const SizedBox(height: 10),
//
//               // Other Speciality Field (Appears if "Other" is selected)
//               if (isOtherSpeciality)
//                 _buildValidatedField(
//                   controller: _otherSpecialityController,
//                   labelText: 'Specify Your Speciality',
//                   validator: (value) => value.isNotEmpty,
//                   onChanged: (value) {
//                     widget.signUpInfo.speciality = value; // Store custom speciality
//                     _validateForm();
//                   },
//                 ),
//               if (isOtherSpeciality) const SizedBox(height: 10),
//
//               // Description Field
//               _buildValidatedField(
//                 controller: _descriptionController,
//                 labelText: 'Description (Optional)',
//                 validator: (value) => value.isNotEmpty, // Check appears only if something is written
//                 onChanged: (value) {
//                   widget.signUpInfo.description = value; // Store description
//                   _validateForm();
//                 },
//               ),
//               const SizedBox(height: 10),
//
//               // Address Field
//               _buildValidatedField(
//                 controller: _addressController,
//                 labelText: 'Address',
//                 validator: (value) => value.isNotEmpty,
//                 onChanged: (value) {
//                   widget.signUpInfo.address = value; // Store address
//                   _validateForm();
//                 },
//               ),
//               const SizedBox(height: 20),
//
//               // Progress Line
//               const LinearProgressIndicator(
//                 value: 0.42,
//                 backgroundColor: AppColors.background2,
//                 valueColor: AlwaysStoppedAnimation<Color>(AppColors.main),
//                 minHeight: 4,
//               ),
//               const SizedBox(height: 20),
//
//               // Continue Button
//               ElevatedButton(
//                 onPressed: isFormValid
//                     ? () {
//                   if (widget.signUpInfo.email != null && widget.signUpInfo.phoneNumber == null) {
//                     Navigator.push(
//                       context,
//                       fadePageRoute(EnterPhoneNumberPage(signUpInfo: widget.signUpInfo)),
//                     );
//                   } else if (widget.signUpInfo.phoneNumber != null && widget.signUpInfo.email == null) {
//                     Navigator.push(
//                       context,
//                       fadePageRoute(EnterEmailPage(signUpInfo: widget.signUpInfo)),
//                     );
//                   } else {
//                     Navigator.push(
//                       context,
//                       fadePageRoute(CreatePasswordPage(signUpInfo: widget.signUpInfo)),
//                     );
//                   }
//                 }
//                     : null,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: isFormValid ? AppColors.main : Colors.grey,
//                   padding: const EdgeInsets.symmetric(vertical: 12.0),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8.0),
//                   ),
//                 ),
//                 child: const SizedBox(
//                   width: double.infinity,
//                   child: Center(
//                     child: Text('Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// Reusable dropdown with validation
//   Widget _buildDropdownValidatedField({
//     required String? value,
//     required String hint,
//     required List<DropdownMenuItem<String>> items,
//     required Function(String?) onChanged,
//   }) {
//     final isValid = value != null && (value != "Other" || _otherSpecialityController.text.isNotEmpty);
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey),
//         borderRadius: BorderRadius.circular(8.0),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: DropdownButtonFormField<String>(
//               value: value,
//               decoration: const InputDecoration(
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
//               ),
//               hint: Text(hint),
//               items: items,
//               onChanged: (val) => onChanged(val),
//             ),
//           ),
//           if (isValid) // Show green check only when valid
//             const Padding(
//               padding: EdgeInsets.only(right: 8.0),
//               child: CircleAvatar(
//                 radius: 12,
//                 backgroundColor: Colors.green,
//                 child: Icon(
//                   Icons.check,
//                   color: Colors.white,
//                   size: 14,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// Reusable validated field builder
//   Widget _buildValidatedField({
//     required TextEditingController controller,
//     required String labelText,
//     required bool Function(String value) validator,
//     required Function(String value) onChanged,
//   }) {
//     final isValid = validator(controller.text);
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey),
//         borderRadius: BorderRadius.circular(8.0),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextFormField(
//               controller: controller,
//               decoration: InputDecoration(
//                 labelText: labelText,
//                 border: InputBorder.none,
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
//               ),
//               onChanged: (value) {
//                 onChanged(value);
//                 _validateForm();
//               },
//             ),
//           ),
//           if (isValid) // Show green check only when valid
//             const Padding(
//               padding: EdgeInsets.only(right: 8.0),
//               child: CircleAvatar(
//                 radius: 12,
//                 backgroundColor: Colors.green,
//                 child: Icon(
//                   Icons.check,
//                   color: Colors.white,
//                   size: 14,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
