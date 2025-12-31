import 'dart:async';
import 'dart:io';
import 'package:docsera/models/document.dart';
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


class DocumentsCubit extends Cubit<DocumentsState> {
  DocumentsCubit() : super(DocumentsLoading());

  RealtimeChannel? _documentsRealtimeChannel;

  /// ✅ Start listening to document updates in real-time
  void listenToDocuments(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      emit(DocumentsNotLogged());
      return;
    }

    final userId = authState.user.id;

    _documentsRealtimeChannel?.unsubscribe();
    emit(DocumentsLoading());

    _documentsRealtimeChannel = Supabase.instance.client
        .channel('public:documents')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'documents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _fetchDocuments(userId);
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'documents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _fetchDocuments(userId);
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'documents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _fetchDocuments(userId);
      },
    )
        .subscribe();

    _fetchDocuments(userId); // تحميل أولي
  }

  void _fetchDocuments(String userId) async {
    emit(DocumentsLoading());

    try {
      final response = await Supabase.instance.client
          .from('documents')
          .select()
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false);

      final docs = response.map((e) => UserDocument.fromMap(e)).toList();
      emit(DocumentsLoaded(docs));
    } catch (e) {
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

        final storage = Supabase.instance.client.storage;
        await storage.from('documents').upload(path, file);
        final url = storage.from('documents').getPublicUrl(path);

        final previewUrl = await generatePdfThumbnail(file.path, path, userId);

        final docData = {
          'id': docId,
          'user_id': userId, // ✅ المالك الأساسي
          'patient_id': patientId, // ✅ المريض المقصود
          'name': docName,
          'type': 'pdf',
          'file_type': 'pdf',
          'preview_url': previewUrl ?? url,
          'pages': [url],
          'uploaded_at': uploadedAt.toIso8601String(),
          'uploaded_by_id': userId,
        };

        await Supabase.instance.client.from('documents').insert(docData);
        return;
      }

      // الصور
      final uploadedUrls = <String>[];
      for (int i = 0; i < picked.files.length; i++) {
        final file = File(picked.files[i].path!);
        final fileName = 'page_$i.jpg';
        final path = 'documents/$userId/${DateTime.now().millisecondsSinceEpoch}-$fileName';

        // ✅ Compress image before upload
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );

        final storage = Supabase.instance.client.storage;

        if (compressedBytes != null) {
           await storage.from('documents').uploadBinary(
            path,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
        } else {
          // Fallback to original if compression fails
           await storage.from('documents').upload(path, file);
        }

        final url = storage.from('documents').getPublicUrl(path);
        uploadedUrls.add(url);
      }

      final docData = {
        'user_id': userId,
        'patient_id': patientId,
        'name': docName,
        'type': 'image',
        'file_type': 'image',
        'preview_url': uploadedUrls.first,
        'pages': uploadedUrls,
        'uploaded_at': uploadedAt.toIso8601String(),
        'uploaded_by_id': userId,
      };

      await Supabase.instance.client.from('documents').insert(docData);
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
      final fileBytes = await file.readAsBytes();

      final storageRes = await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(storagePath, fileBytes);

      final url = Supabase.instance.client.storage
          .from('documents')
          .getPublicUrl(storagePath);


      final previewUrl = await generatePdfThumbnail(path, docId, userId);

      final docData = {
        'id': docId,
        'name': fileName.trim().isEmpty ? autoName : fileName,
        'type': 'pdf',
        'file_type': 'pdf',
        'patient_id': userId,
        'preview_url': previewUrl ?? url,
        'pages': [url],
        'uploaded_at': uploadedAt.toIso8601String(),
        'uploaded_by_id': userId,
      };

      await Supabase.instance.client.from('documents').insert(docData);
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


      final storageResponse = await Supabase.instance.client.storage
          .from('documents')
          .upload(
        'users/$userId/$docId/preview.png',
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );
      if (storageResponse.isEmpty) throw Exception('Upload failed');
      final url = Supabase.instance.client.storage
          .from('documents')
          .getPublicUrl('users/$userId/$docId/preview.png');

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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw "User not authenticated.";

      // حذف من قاعدة البيانات
      await Supabase.instance.client
          .from('documents')
          .delete()
          .eq('id', document.id!)
          .eq('user_id', userId);

      // حذف من التخزين
      for (final url in document.pages) {
        try {
          final path = Uri.parse(url).path.split('/storage/v1/object/public/documents/').last;
          await Supabase.instance.client.storage.from('documents').remove([path]);
        } catch (e) {
          print("⚠️ Failed to delete file from storage: $e");
        }
      }
      // إعادة تحميل البيانات
      listenToDocuments(context);
    } catch (e) {
      emit(DocumentsError("Delete failed: $e"));
    }
  }

  @override
  Future<void> close() {
    _documentsRealtimeChannel?.unsubscribe();
    return super.close();
  }
}
