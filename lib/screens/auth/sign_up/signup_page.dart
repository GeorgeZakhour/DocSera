// // ignore_for_file: library_private_types_in_public_api
// import 'package:docsera/utils/text_direction_utils.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});
//
//   @override
//   _SignUpPageState createState() => _SignUpPageState();
// }
//
// class _SignUpPageState extends State<SignUpPage> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   String? _selectedRole;
//   final TextEditingController _specialtyController = TextEditingController();
//
//   Future<void> _registerUser() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         // Firebase Authentication
//         UserCredential userCredential = await FirebaseAuth.instance
//             .createUserWithEmailAndPassword(
//           email: _emailController.text,
//           password: _passwordController.text,
//         );
//
//         // Add user details to Firestore
//         await FirebaseFirestore.instance
//             .collection('Users')
//             .doc(userCredential.user!.uid)
//             .set({
//           'email': _emailController.text,
//           'role': _selectedRole,
//           'specialty': _selectedRole == 'Doctor' ? _specialtyController.text : null,
//         });
//
//         // Check if widget is still mounted before interacting with the context
//         if (!mounted) return;
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('User registered successfully!')),
//         );
//
//         Navigator.pop(context); // Go back to the previous screen
//       } catch (e) {
//         if (!mounted) return;
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: ${e.toString()}')),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Sign Up'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               TextFormField(
//                 controller: _emailController,
//                 textDirection: detectTextDirection(_emailController.text), // ✅ ضبط الاتجاه ديناميكيًا
//                 textAlign: getTextAlign(context),
//                 decoration: const InputDecoration(labelText: 'Email'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your email';
//                   }
//                   final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
//                   if (!emailRegex.hasMatch(value)) {
//                     return 'Please enter a valid email';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _passwordController,
//                 textDirection: detectTextDirection(_passwordController.text), // ✅ ضبط الاتجاه ديناميكيًا
//                 textAlign: getTextAlign(context),
//                 decoration: const InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your password';
//                   }
//                   if (value.length < 8) {
//                     return 'Password must be at least 8 characters long';
//                   }
//                   final passwordRegex =
//                   RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$');
//                   if (!passwordRegex.hasMatch(value)) {
//                     return 'Password must contain at least one uppercase letter, one number, and one special character';
//                   }
//                   return null;
//                 },
//               ),
//               DropdownButtonFormField<String>(
//                 value: _selectedRole,
//                 decoration: const InputDecoration(labelText: 'Role'),
//                 items: const [
//                   DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
//                   DropdownMenuItem(value: 'Patient', child: Text('Patient')),
//                 ],
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedRole = value;
//                   });
//                 },
//                 validator: (value) =>
//                 value == null ? 'Please select a role' : null,
//               ),
//               if (_selectedRole == 'Doctor')
//                 TextFormField(
//                   controller: _specialtyController,
//                   textDirection: detectTextDirection(_specialtyController.text), // ✅ ضبط الاتجاه ديناميكيًا
//                   textAlign: getTextAlign(context),
//                   decoration: const InputDecoration(labelText: 'Specialty'),
//                   validator: (value) {
//                     if (_selectedRole == 'Doctor' && (value == null || value.isEmpty)) {
//                       return 'Please enter your specialty';
//                     }
//                     return null;
//                   },
//                 ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _registerUser,
//                 child: const Text('Register'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
