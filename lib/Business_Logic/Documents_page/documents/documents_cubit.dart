import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/models/document.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Authentication/auth_cubit.dart';
import '../../Authentication/auth_state.dart';
import 'documents_state.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';


import 'documents_service.dart';

class DocumentsCubit extends Cubit<DocumentsState> {
  final DocumentsService _service;

  DocumentsCubit({DocumentsService? service})
      : _service = service ?? DocumentsService(),
        super(DocumentsLoading());

  RealtimeChannel? _documentsRealtimeChannel;
  String? _loadedUserId;

  /// ✅ Start listening to document updates in real-time
  void listenToDocuments({BuildContext? context, String? explicitUserId, bool forceReload = false}) {
    String userId;

    if (explicitUserId != null) {
      userId = explicitUserId;
    } else if (context != null) {
      final authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) {
        emit(DocumentsNotLogged());
        return;
      }
      userId = authState.user.id;
    } else {
        // No user ID found
        return;
    }

    if (!forceReload && state is DocumentsLoaded && _loadedUserId == userId) return; // ✅ Prevent redundant reloads

    _loadedUserId = userId; // Update loaded user ID

    _documentsRealtimeChannel?.unsubscribe();
    emit(DocumentsLoading());

    _documentsRealtimeChannel = _service.subscribeToDocuments(userId, () {
      _fetchDocuments(userId);
    });

    _fetchDocuments(userId); // تحميل أولي
  }

  void _fetchDocuments(String userId) async {
    // emit(DocumentsLoading()); // ListenToDocuments already emits loading

    try {
      final docs = await _service.fetchDocuments(userId);
      emit(DocumentsLoaded(docs));
    } catch (e) {
      _loadedUserId = null; // Reset on failure
      emit(DocumentsError("فشل تحميل الوثائق: $e"));
    }
  }

  /// ✅ Upload document (PDF or multiple images)
  Future<void> uploadDocument({required String patientId}) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        emit(DocumentsError("User not authenticated."));
        return;
      }

      final userId = currentUser.id; // المستخدم الأساسي
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (picked == null || picked.files.isEmpty) return;

      final firstPath = picked.files.first.path ?? '';
      final isPdf = firstPath.toLowerCase().endsWith('.pdf');

      final uploadedAt = DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      const docCounterKey = 'lastUploadedDocNumber';
      int docCounter = prefs.getInt(docCounterKey) ?? 0;
      final autoName = 'Document ${++docCounter}';
      await prefs.setInt(docCounterKey, docCounter);

      final docName = picked.files.first.name.trim().isEmpty
          ? autoName
          : picked.files.first.name;

      final docId = const Uuid().v4();

      if (isPdf) {
        final file = File(picked.files.first.path!);
        final fileName = picked.files.first.name;
        final path = 'documents/$userId/${DateTime.now().millisecondsSinceEpoch}-$fileName';

        // ✅ Phase 2C: Encrypt file bytes before upload
        var fileBytes = await file.readAsBytes();
        final enc = MessageEncryptionService.instance;
        if (enc.isReady) {
          final encrypted = enc.encryptBytes(Uint8List.fromList(fileBytes));
          if (encrypted != null) fileBytes = encrypted;
        }

        final storage = Supabase.instance.client.storage;
        await storage.from('documents').uploadBinary(path, fileBytes);

        // ✅ Phase 2B: Store storage path (not public URL) — resolved via signed URL at display time
        final previewPath = await generatePdfThumbnail(file.path, path, userId);

        final docData = {
          'id': docId,
          'user_id': userId,
          'patient_id': patientId,
          'name': docName,
          'type': 'pdf',
          'file_type': 'pdf',
          'preview_url': previewPath ?? path,
          'pages': [path],
          'uploaded_at': uploadedAt.toIso8601String(),
          'uploaded_by_id': userId,
          'source': 'patient',
          'encrypted': true,
        };

        await Supabase.instance.client.from('documents').insert(docData);
        _fetchDocuments(userId);
        return;
      }

      // الصور
      final uploadedPaths = <String>[];
      final enc = MessageEncryptionService.instance;
      for (int i = 0; i < picked.files.length; i++) {
        final file = File(picked.files[i].path!);
        final fileName = 'page_$i.jpg';
        final path = 'documents/$userId/${DateTime.now().millisecondsSinceEpoch}-$fileName';

        // ✅ Compress image before upload
        var uploadBytes = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );

        uploadBytes ??= await file.readAsBytes();

        // ✅ Phase 2C: Encrypt image bytes before upload
        if (enc.isReady) {
          final encrypted = enc.encryptBytes(Uint8List.fromList(uploadBytes));
          if (encrypted != null) uploadBytes = encrypted;
        }

        final storage = Supabase.instance.client.storage;
        await storage.from('documents').uploadBinary(
          path,
          Uint8List.fromList(uploadBytes),
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );

        // ✅ Phase 2B: Store storage path (not public URL)
        uploadedPaths.add(path);
      }

      final docData = {
        'user_id': userId,
        'patient_id': patientId,
        'name': docName,
        'type': 'image',
        'file_type': 'image',
        'preview_url': uploadedPaths.first,
        'pages': uploadedPaths,
        'uploaded_at': uploadedAt.toIso8601String(),
        'uploaded_by_id': userId,
        'source': 'patient',
        'encrypted': true,
      };

      await Supabase.instance.client.from('documents').insert(docData);
      _fetchDocuments(userId);
    } catch (e) {
      emit(DocumentsError("Upload failed: $e"));
    }
  }

  Future<void> uploadPdfDirectly(String path) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw "User not authenticated.";

      final userId = currentUser.id;
      final docId = const Uuid().v4();

      final uploadedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      const docCounterKey = 'lastUploadedDocNumber';
      int docCounter = prefs.getInt(docCounterKey) ?? 0;
      final autoName = 'Document ${++docCounter}';
      await prefs.setInt(docCounterKey, docCounter);

      final file = File(path);
      final fileName = basename(path);

      final storagePath = 'users/$userId/documents/$docId/$fileName';
      var fileBytes = await file.readAsBytes();

      // ✅ Phase 2C: Encrypt file bytes before upload
      final enc = MessageEncryptionService.instance;
      if (enc.isReady) {
        final encrypted = enc.encryptBytes(Uint8List.fromList(fileBytes));
        if (encrypted != null) fileBytes = encrypted;
      }

      await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(storagePath, fileBytes);

      // ✅ Phase 2B: Store storage path (not public URL)
      final previewPath = await generatePdfThumbnail(path, docId, userId);

      final docData = {
        'id': docId,
        'user_id': userId,
        'name': fileName.trim().isEmpty ? autoName : fileName,
        'type': 'pdf',
        'file_type': 'pdf',
        'patient_id': userId,
        'preview_url': previewPath ?? storagePath,
        'pages': [storagePath],
        'uploaded_at': uploadedAt.toIso8601String(),
        'uploaded_by_id': userId,
        'source': 'patient',
        'encrypted': true,
      };

      await Supabase.instance.client.from('documents').insert(docData);
      _fetchDocuments(userId);
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


      final previewStoragePath = 'users/$userId/$docId/preview.png';

      // ✅ Phase 2C: Encrypt preview bytes
      var previewBytes = bytes;
      final enc = MessageEncryptionService.instance;
      if (enc.isReady) {
        final encrypted = enc.encryptBytes(Uint8List.fromList(previewBytes));
        if (encrypted != null) previewBytes = encrypted;
      }

      final storageResponse = await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(
        previewStoragePath,
        Uint8List.fromList(previewBytes),
        fileOptions: const FileOptions(upsert: true),
      );
      if (storageResponse.isEmpty) throw Exception('Upload failed');

      await page.close();
      await doc.close();

      // ✅ Phase 2B: Return storage path (not public URL)
      return previewStoragePath;
    } catch (e) {
      debugPrint("❌ Thumbnail generation failed: $e");
      return null;
    }
  }



  /// ✅ Delete document and its files
  Future<void> deleteDocument({required UserDocument document, BuildContext? context, String? explicitUserId}) async {
    try {
      String? userId;
      if (explicitUserId != null) {
        userId = explicitUserId;
      } else if (context != null) {
         final authState = context.read<AuthCubit>().state;
         if (authState is AuthAuthenticated) {
             userId = authState.user.id;
        }
      }

      if (userId == null) {
          emit(DocumentsError("User not authenticated."));
          return;
      }

      // حذف من قاعدة البيانات
      await _service.deleteDocument(document.id!, userId);

      // حذف من التخزين
      await _service.deleteFiles(document.pages);

      // إعادة تحميل البيانات
      listenToDocuments(context: context, explicitUserId: userId, forceReload: true);
    } catch (e) {
      emit(DocumentsError("Delete failed: $e"));
    }
  }

  /// ✅ Rename document
  Future<void> renameDocument({required String docId, required String newName, required String userId}) async {
    final previousState = state;
    List<UserDocument>? previousDocs;

    // 1. Optimistic Update
    if (previousState is DocumentsLoaded) {
      previousDocs = previousState.documents;
      try {
        final index = previousDocs.indexWhere((doc) => doc.id == docId);
        if (index != -1) {
          final updatedDoc = previousDocs[index].copyWith(name: newName);
          final updatedList = List<UserDocument>.from(previousDocs);
          updatedList[index] = updatedDoc;
          emit(DocumentsLoaded(updatedList));
        }
      } catch (e) {
        debugPrint("Optimistic update failed: $e");
      }
    }

    // 2. Perform Server Update
    try {
      await Supabase.instance.client
          .from('documents')
          .update({'name': newName})
          .eq('id', docId)
          .eq('user_id', userId);

      // No need to re-fetch if successful, as we already updated locally.
      // But we can do it silently if needed. For now, trust the optimistic update.
      // _fetchDocuments(userId); 
    } catch (e) {
      // 3. Revert on Failure
      if (previousState is DocumentsLoaded && previousDocs != null) {
         emit(previousState); // Revert to old list
      }
      emit(DocumentsError("Rename failed: $e"));
    }
  }


  @override
  Future<void> close() {
    _documentsRealtimeChannel?.unsubscribe();
    return super.close();
  }
}
