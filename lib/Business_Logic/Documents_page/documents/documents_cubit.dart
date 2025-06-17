import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/models/document.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Authentication/auth_cubit.dart';
import '../../Authentication/auth_state.dart';
import 'documents_state.dart';
import 'package:pdfx/pdfx.dart';


class DocumentsCubit extends Cubit<DocumentsState> {
  DocumentsCubit() : super(DocumentsLoading());

  StreamSubscription? _documentsSubscription;

  /// ✅ Start listening to document updates in real-time
  void listenToDocuments(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      emit(DocumentsNotLogged());
      return;
    }

    final userId = authState.user.uid;

    _documentsSubscription?.cancel();
    emit(DocumentsLoading());

    _documentsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs
          .map((doc) => UserDocument.fromFirestore(doc))
          .toList();
      emit(DocumentsLoaded(docs));
    }, onError: (e) {
      emit(DocumentsError("Listen error: $e"));
    });
  }

  /// ✅ Upload document (PDF or multiple images)
  Future<void> uploadDocument() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        emit(DocumentsError("User not authenticated."));
        return;
      }

      final userId = currentUser.uid;
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (picked == null || picked.files.isEmpty) return;

      final firstPath = picked.files.first.path ?? '';
      final isPdf = firstPath.toLowerCase().endsWith('.pdf');


      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc();

      final uploadedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final docCounterKey = 'lastUploadedDocNumber';
      int docCounter = prefs.getInt(docCounterKey) ?? 0;
      final autoName = 'Document ${++docCounter}';
      await prefs.setInt(docCounterKey, docCounter);

      final docName = picked.files.first.name.trim().isEmpty
          ? autoName
          : picked.files.first.name;

      if (isPdf) {
        final file = File(picked.files.first.path!);
        final fileName = picked.files.first.name;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child("users/$userId/documents/${docRef.id}/$fileName");

        await storageRef.putFile(file);
        final url = await storageRef.getDownloadURL();

        final previewUrl = await generatePdfThumbnail(file.path, docRef.id, userId);

        final doc = UserDocument(
          id: docRef.id,
          name: docName,
          type: "pdf",
          fileType: "pdf",
          patientId: userId,
          previewUrl: previewUrl ?? url, // 👈 هذا المهم
          pages: [url],
          uploadedAt: uploadedAt,
          uploadedById: userId,
        );

        await docRef.set(doc.toMap());
        return;
      }


      // Multiple images
      final uploadedUrls = <String>[];
      for (int i = 0; i < picked.files.length; i++) {
        final file = File(picked.files[i].path!);
        final fileName = 'page_$i.jpg';

        final storageRef = FirebaseStorage.instance
            .ref()
            .child("users/$userId/documents/${docRef.id}/$fileName");

        await storageRef.putFile(file);
        final url = await storageRef.getDownloadURL();
        uploadedUrls.add(url);
      }

      final doc = UserDocument(
        id: docRef.id,
        name: docName,
        fileType: "image", // ✅ أضف هذا
        type: "image",
        patientId: userId,
        previewUrl: uploadedUrls.first,
        pages: uploadedUrls,
        uploadedAt: uploadedAt,
        uploadedById: userId, // ✅ أضف هذا
      );


      await docRef.set(doc.toMap());

    } catch (e) {
      emit(DocumentsError("Upload failed: $e"));
    }
  }

  Future<void> uploadPdfDirectly(String path) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw "User not authenticated.";

      final userId = currentUser.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc();

      final uploadedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final docCounterKey = 'lastUploadedDocNumber';
      int docCounter = prefs.getInt(docCounterKey) ?? 0;
      final autoName = 'Document ${++docCounter}';
      await prefs.setInt(docCounterKey, docCounter);

      final file = File(path);
      final fileName = basename(path);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child("users/$userId/documents/${docRef.id}/$fileName");

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      final previewUrl = await generatePdfThumbnail(path, docRef.id, userId);

      final doc = UserDocument(
        id: docRef.id,
        name: fileName.trim().isEmpty ? autoName : fileName,
        type: "pdf",
        fileType: "pdf", // ✅ أضف هذا
        patientId: userId,
        previewUrl: previewUrl ?? url, // استخدم الصورة إن وُجدت، وإلا الرابط
        pages: [url],
        uploadedAt: uploadedAt,
        uploadedById: userId,
      );

      await docRef.set(doc.toMap());
    } catch (e) {
      emit(DocumentsError("Upload failed: $e"));
    }
  }


  // داخل `uploadPdfDirectly` أو `DocumentInfoScreen`:

  Future<String?> generatePdfThumbnail(String pdfPath, String docId, String userId) async {
    try {
      final doc = await PdfDocument.openFile(pdfPath);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );

      final bytes = pageImage?.bytes;
      if (bytes == null) throw Exception('PDF thumbnail generation failed: null bytes');

      final tempDir = await getTemporaryDirectory();
      final imagePath = '${tempDir.path}/$docId-preview.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(bytes);


      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/documents/$docId/preview.png');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      await page.close();
      await doc.close();

      return url;
    } catch (e) {
      print("❌ Thumbnail generation failed: $e");
      return null;
    }
  }



  /// ✅ Delete document and its files
  Future<void> deleteDocument(BuildContext context, UserDocument document) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw "User not authenticated.";

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc(document.id);

      await docRef.delete();

      for (final url in document.pages) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          print("⚠️ Failed to delete file from storage: $e");
        }
      }
      listenToDocuments(context);

    } catch (e) {
      emit(DocumentsError("Delete failed: $e"));
    }
  }

  @override
  Future<void> close() {
    _documentsSubscription?.cancel();
    return super.close();
  }
}
