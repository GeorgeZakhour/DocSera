import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSearchService {
  final CollectionReference doctorsCollection =
  FirebaseFirestore.instance.collection('doctors');

  /// 🔍 **Search doctors by name, specialty, or clinic**
  Future<List<Map<String, dynamic>>> searchDoctors(String query) async {
    try {
      if (query.isEmpty) return [];

      // Convert query to lowercase for case-insensitive search
      String lowerQuery = query.toLowerCase();

      // Fetch all doctors from Firestore
      QuerySnapshot snapshot = await doctorsCollection.get();

      // Convert Firestore data to a list
      List<Map<String, dynamic>> allDoctors = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // **Filter manually**
      List<Map<String, dynamic>> filteredDoctors = allDoctors.where((doctor) {
        // Ensure all fields are valid strings before calling `toLowerCase()`
        String fullName = ("${doctor['firstName']} ${doctor['lastName']}").toLowerCase();
        String specialty = (doctor['specialty'] ?? "").toLowerCase();
        String clinic = (doctor['clinic'] ?? "").toLowerCase();

        return fullName.contains(lowerQuery) ||
            specialty.contains(lowerQuery) ||
            clinic.contains(lowerQuery);
      }).toList();

      return filteredDoctors;
    } catch (e) {
      print("Error fetching doctors: $e");
      return [];
    }
  }
}
