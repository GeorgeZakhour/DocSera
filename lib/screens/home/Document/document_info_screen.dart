import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentInfoScreen extends StatefulWidget {
  final List<String> images;
  final String? initialName; // ← أضف هذا
  final bool cameFromMultiPage;
  final int? pageCount;
  final String? initialPatientId; // أضف هذا السطر
  final bool cameFromConversation;
  final String? conversationDoctorName;
  final bool isSendMode; // ← جديد
  final String? appointmentId;

  const DocumentInfoScreen({
    super.key,
    required this.images,
    this.initialName,
    this.pageCount,
    this.cameFromMultiPage = false,
    this.initialPatientId,
    this.cameFromConversation = false,
    this.conversationDoctorName,
    this.isSendMode = false, // ← افتراضي رفع عادي
    this.appointmentId,
  });

  @override
  State<DocumentInfoScreen> createState() => _DocumentInfoScreenState();
}

const int kMaxPatientFileSize = 15 * 1024 * 1024; // 15MB

class _DocumentInfoScreenState extends State<DocumentInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedType;
  String? _selectedPatientId;
  List<Map<String, String>> _patients = [];
  late List<Color> avatarColors;
  bool _isUploading = false;
  bool _triedToSubmit = false;

  final Map<String, String Function(AppLocalizations)> _documentTypeMap = {
    'نتائج': (locale) => locale.results,
    'تصوير شعاعي': (locale) => locale.medicalImaging,
    'تقرير': (locale) => locale.report,
    'إحالة طبية': (locale) => locale.referralLetter,
    'خطة علاج': (locale) => locale.treatmentPlan,
    'إثبات هوية': (locale) => locale.identityProof,
    'إثبات تأمين صحي': (locale) => locale.insuranceProof,
    'أخرى': (locale) => locale.other,
  };

  bool get isFormValid => _selectedType != null && _selectedPatientId != null;

  @override
  void initState() {
    super.initState();

    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }

    final List<Color> mainShades = [
      AppColors.main,
      AppColors.main.withOpacity(0.4),
      AppColors.main.withOpacity(0.6),
    ];

    final List<Color> yellowShades = [
      AppColors.yellow.withOpacity(0.85),
      AppColors.yellow.withOpacity(0.65),
      AppColors.yellow.withOpacity(0.75),
    ];

    avatarColors = List.generate(6, (index) {
      final i = index ~/ 2;
      return index % 2 == 0 ? mainShades[i] : yellowShades[i];
    });

    _fetchPatients();
  }

  List<Color> generateShades(Color baseColor, int count) {
    return List.generate(count, (index) {
      final t = index / (count - 1);
      return Color.lerp(baseColor.withOpacity(0.7), baseColor, t)!;
    });
  }

  Future<void> _fetchPatients() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.rpc('rpc_get_my_patient_context');

      if (response == null) return;

      final Map<String, dynamic> data = Map<String, dynamic>.from(response);

      final List<Map<String, String>> patients = [];

      // 👤 المستخدم الأساسي
      final user = data['user'];
      if (user != null) {
        final userName =
        "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();

        patients.add({
          'id': user['id'],
          'name': userName,
        });
      }

      // 👨‍👩‍👧 الأقارب
      final relatives = data['relatives'] as List<dynamic>;
      for (final r in relatives) {
        final name =
        "${r['first_name'] ?? ''} ${r['last_name'] ?? ''}".trim();

        patients.add({
          'id': r['id'],
          'name': name,
        });
      }

      if (!mounted) return;
      setState(() {
        _patients = patients;
        // Default to the initially selected patient (from health page switcher)
        if (widget.initialPatientId != null &&
            patients.any((p) => p['id'] == widget.initialPatientId)) {
          _selectedPatientId = widget.initialPatientId;
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to load patients via RPC: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.h),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Directionality.of(context) == TextDirection.rtl
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grayMain),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Center(
                  child: Text(
                    locale.addNewDocument,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: AppColors.mainDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6.h),
            TextFormField(
              controller: _nameController,
              style: AppTextStyles.getText2(context),
              maxLength: 50,
              decoration: InputDecoration(
                labelText: "${locale.nameOfTheDocument} (${locale.optional})",
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                labelStyle: AppTextStyles.getText3(context)
                    .copyWith(color: Colors.grey),
                floatingLabelStyle: AppTextStyles.getText3(context)
                    .copyWith(color: AppColors.main, fontSize: 14.sp),
                hintStyle: AppTextStyles.getText3(context)
                    .copyWith(color: Colors.grey, fontSize: 11.sp),
                contentPadding:
                EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide:
                  const BorderSide(color: AppColors.main, width: 2),
                ),
              ),
            ),

            SizedBox(height: 10.h),
            _buildDropdownField(
              value: _selectedType,
              hint: locale.typeOfTheDocument,
              items: _documentTypeMap.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value(locale),
                    style: AppTextStyles.getText2(context),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedType = value),
              showError: _triedToSubmit,
              errorText: locale.fieldRequired,
            ),

            SizedBox(height: 20.h),
            _buildDropdownField(
              value: _selectedPatientId,
              hint: locale.patientConcerned,
              items: _patients.asMap().entries.map((entry) {
                final index = entry.key;
                final patient = entry.value;
                final name = patient['name']!;
                final names = name.split(' ');
                final firstName = names.isNotEmpty ? names[0] : '';
                final lastName = names.length > 1 ? names[1] : '';
                final initials = getInitials(firstName, lastName);
                final color = avatarColors[index % avatarColors.length];

                return DropdownMenuItem<String>(
                  value: patient['id'],
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14.r,
                        backgroundColor: color,
                        child: Text(
                          initials,
                          style: AppTextStyles.getText3(context)
                              .copyWith(color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(name, style: AppTextStyles.getText2(context)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedPatientId = value),
              showError: _triedToSubmit,
              errorText: locale.fieldRequired,
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock,
                  color: AppColors.mainDark,
                  size: 12.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  locale.documentWillBeEncrypted,
                  style: AppTextStyles.getText3(context)
                      .copyWith(color: Colors.blueGrey),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      if (!isFormValid) {
                        setState(() => _triedToSubmit = true);
                        return;
                      }
                      _submitDocument();
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                backgroundColor:
                isFormValid && !_isUploading ? AppColors.main : Colors.grey[400],
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isUploading
                  ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    widget.isSendMode
                        ? locale.sendDocument.toUpperCase()
                        : locale.addDocument.toUpperCase(),
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getInitials(String firstName, String lastName) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    if (isArabic) {
      return firstName.isNotEmpty ? firstName[0] : '';
    } else {
      return "${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}"
          "${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}";
    }
  }

  Future<List<File>> compressImages(List<File> imageFiles) async {
    debugPrint("==============================================");
    debugPrint("🔵 START compressImages()");
    debugPrint("Number of input images = ${imageFiles.length}");
    debugPrint("==============================================");

    int totalOriginalSize = 0;
    int totalCompressedSize = 0;
    List<File> compressedImages = [];

    for (int index = 0; index < imageFiles.length; index++) {
      final file = imageFiles[index];
      final realFile = File(file.absolute.path);

      debugPrint("----------------------------------------------");
      debugPrint("🖼️ Image #$index");
      debugPrint("Real path: ${realFile.path}");
      debugPrint("Exists: ${realFile.existsSync()}");

      final int originalSize = await realFile.length();
      totalOriginalSize += originalSize;

      debugPrint(
          "Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB");

      if (originalSize <= 200 * 1024) {
        debugPrint("⚪ Skipped compression (small file)");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
        continue;
      }

      int quality = 50;
      if (originalSize <= 500 * 1024) {
        quality = 75;
      } else if (originalSize <= 1000 * 1024) {
        quality = 50;
      } else if (originalSize <= 2000 * 1024) {
        quality = 35;
      } else {
        quality = 25;
      }

      final targetPath = '${realFile.path}_compressed.jpg';

      debugPrint("🔧 Compressing...");
      debugPrint("Target path: $targetPath");
      debugPrint("Quality: $quality");

      XFile? compressed;
      try {
        compressed = await FlutterImageCompress.compressAndGetFile(
          realFile.absolute.path,
          targetPath,
          quality: quality,
          keepExif: true,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint("❌ ERROR: Compression crashed: $e");
      }

      if (compressed == null) {
        debugPrint("⚠️ Compression returned NULL, using original");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
        continue;
      }

      final File compressedFile = File(compressed.path);
      final int compressedSize = await compressedFile.length();

      debugPrint("Compressed exists: ${compressedFile.existsSync()}");
      debugPrint("Compressed path: ${compressedFile.path}");
      debugPrint(
          "Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB");

      const int maxAllowedSize = kMaxPatientFileSize;

      if (compressedSize >= originalSize || compressedSize > maxAllowedSize) {
        debugPrint("⚠️ Compression skipped (inefficient or >15MB)");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
      } else {
        debugPrint(
            "📉 Compression saved: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(2)}%");
        totalCompressedSize += compressedSize;
        compressedImages.add(compressedFile);
      }
    }

    debugPrint("==============================================");
    debugPrint(
        "📦 Total original size: ${(totalOriginalSize / 1024).toStringAsFixed(2)} KB");
    debugPrint(
        "📦 Total compressed size: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
    debugPrint(
        "🟦 Final compressed image count: ${compressedImages.length}");

    for (final f in compressedImages) {
      debugPrint(
          " • ${f.path}   size = ${(await f.length()) / 1024} KB");
    }
    debugPrint("==============================================");

    if (totalCompressedSize > kMaxPatientFileSize) {
      throw Exception(
          "💥 Document too large after compression: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
    }

    debugPrint("🟢 END compressImages()");
    return compressedImages;
  }

  Future<void> _submitAppointmentAttachment(AppLocalizations locale) async {
    if (widget.appointmentId == null || widget.appointmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red.withOpacity(0.8),
          content: Text(locale.somethingWentWrong),
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null || userId.isEmpty) {
        throw Exception("User ID not found");
      }

      // 🆔 ID ثابت للـ attachment نفسه
      final String attachmentId = DocSeraTime.nowUtc().millisecondsSinceEpoch.toString();

      // 📄 اسم الملف (إما من المستخدم أو Auto Name)
      final String name = _nameController.text.trim().isEmpty
          ? await _generateAutoName(userId)
          : _nameController.text.trim();

      final DateTime uploadedAt = DocSeraTime.nowUtc();

      final bool isPdf = widget.images.first.toLowerCase().endsWith('.pdf');
      final String fileType = isPdf ? 'pdf' : 'image';

      // 🧮 تجهيز الملفات للرفع
      final List<File> filesToUpload = [];

      if (isPdf) {
        // ✅ PDF بدون ضغط – حد 5MB
        final pdfFile = File(widget.images.first);
        final sizeInBytes = await pdfFile.length();
        if (sizeInBytes > kMaxPatientFileSize) {
          throw Exception("PDF too large");
        }
        filesToUpload.add(pdfFile);
      } else {
        // ✅ Enable compression for appointment attachments
        debugPrint("🗜 Compressing images for appointment...");
        final compressedFiles = await compressImages(
          widget.images.map((e) => File(File(e).absolute.path)).toList(),
        );

        // ✅ Validate Post-Compression Size (Must be < 15MB)
        for (final file in compressedFiles) {
          final size = await file.length();
          if (size > kMaxPatientFileSize) {
             throw Exception("Document too large");
          }
        }

        filesToUpload.addAll(compressedFiles);
        debugPrint("✅ Compression done. Count: ${filesToUpload.length}");
      }

      // 📤 الرفع إلى Bucket appointments-attachments
      final supabase = Supabase.instance.client;
      final storage = supabase.storage.from('appointments-attachments');

      final List<String> paths = [];

      for (int i = 0; i < filesToUpload.length; i++) {
        final fileToUpload = filesToUpload[i];

        final extension = fileToUpload.path.split('.').last.toLowerCase();
        final String fileName = isPdf ? 'file.pdf' : 'page_$i.$extension';
        
        final String filePath = 'users/$userId/appointments/${widget.appointmentId}/$attachmentId/$fileName';

        // ✅ Phase 2C: Encrypt file bytes before upload
        var fileBytes = await fileToUpload.readAsBytes();
        final enc = MessageEncryptionService.instance;
        if (enc.isReady) {
          final encrypted = enc.encryptBytes(Uint8List.fromList(fileBytes));
          if (encrypted != null) fileBytes = encrypted;
        }

        debugPrint("📤 Uploading: $filePath (encrypted)");

        await storage.uploadBinary(filePath, fileBytes,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );
        paths.add(filePath);
      }

      // ✅ عدد الصفحات
      final int pageCount = isPdf
          ? (widget.pageCount ?? 1)
          : filesToUpload.length;

      // ✅ JSON النهائي للـ Attachment (الشكل الموحد)
      final Map<String, dynamic> attachment = {
        'id': attachmentId,
        'name': name,
        'bucket': 'appointments-attachments',
        'file_type': fileType,
        'paths': paths,
        'page_count': pageCount,
        'preview_path': paths.isNotEmpty ? paths.first : null,
        'patient_id': _selectedPatientId,
        'uploaded_by_id': userId,
        'uploaded_at': uploadedAt.toIso8601String(),
        'source': 'appointment',
        'appointment_id': widget.appointmentId,
        'encrypted': true,
      };

      // 💾 استدعاء دالة RPC للتحديث الآمن
      await supabase.rpc('add_appointment_attachment', params: {
        'appointment_id': widget.appointmentId!,
        'attachment': attachment,
      });

      if (!mounted) return;

      // ✅ رجوع إلى صفحة الإرسال
      Navigator.pop(context, true);

      // (تمت إزالة الـ Double Pop لتوحيد منطق التصفح Chain of Responsibility)
      // MultiPageUploadScreen ستنتظر النتيجة true وتقوم هي بالخروج.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.main.withOpacity(0.8),
          content: Text(locale.documentUploadedSuccessfully),
        ),
      );
    } catch (e, stack) {
      debugPrint("❌ Upload appointment attachment error: $e");
      debugPrint("Stacktrace: $stack");
      if (mounted) {
        // ✅ Show RAW error temporarily to debug
        // ✅ Show Localized Error
        String errorMessage = locale.uploadFailed;

        if (e.toString().contains("PDF too large")) {
          errorMessage = locale.pdfTooLarge;
        } else if (e.toString().contains("Document too large")) {
          errorMessage = locale.documentTooLarge;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red.withOpacity(0.8),
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _submitDocument() async {
    final locale = AppLocalizations.of(context)!;
    setState(() => _isUploading = true);

    try {
      if (widget.isSendMode) {
        // Note: _submitAppointmentAttachment handles its own finally block & navigation
        // But if it FAILS, we need to ensure _isUploading is false.
        // And if it SUCCEEDS, the page pops, so this setState might be skipped or throw.
        // Actually, let's delegate the whole logic to _submitAppointmentAttachment
        await _submitAppointmentAttachment(locale);
        return; 
      }

      debugPrint("📤 Starting document submission...");
      // ... rest of normal document upload logic ...
      // I am keeping the logic separate to preserve legacy document upload flow and only touch SEND mode.


      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      debugPrint("👤 Loaded userId: $userId");
      if (userId == null || userId.isEmpty) {
        throw Exception("User ID not found");
      }

      final tempId = DocSeraTime.nowUtc().millisecondsSinceEpoch.toString();
      debugPrint("🆔 Generated temp ID used in file name: $tempId");

      final name = _nameController.text.trim().isEmpty
          ? await _generateAutoName(userId)
          : _nameController.text.trim();
      debugPrint("📄 Document name: $name");

      final uploadedAt = DocSeraTime.nowUtc();
      final List<String> uploadedUrls = [];
      final isPdf = widget.images.first.toLowerCase().endsWith('.pdf');
      final fileType = isPdf ? 'pdf' : 'image';
      final docType = _selectedType ?? 'أخرى';
      debugPrint("📁 File type: $fileType, Doc type: $docType");

      final List<File> filesToUpload;

      if (isPdf) {
        final File pdfFile = File(widget.images.first);
        final int sizeInBytes = await pdfFile.length();
        debugPrint("📄 PDF size in bytes: $sizeInBytes");
        if (sizeInBytes > kMaxPatientFileSize) {
          debugPrint("❌ PDF too large");
          throw Exception("PDF too large");
        }
        filesToUpload = [pdfFile];
      } else {
        debugPrint("🗜 Compressing images...");
        filesToUpload = await compressImages(
          widget.images.map((e) => File(File(e).absolute.path)).toList(),
        );
        debugPrint(
            "✅ Compression done. Pages: ${filesToUpload.length}");
      }

      final supabase = Supabase.instance.client;

      for (int i = 0; i < filesToUpload.length; i++) {
        final fileToUpload = filesToUpload[i];
        final fileName = isPdf ? 'file.pdf' : 'page_$i.jpg';
        final filePath = '$userId/documents/$tempId/$fileName';

        debugPrint("📤 Uploading file: $filePath");

        // ✅ Phase 2C: Encrypt file bytes before upload
        var fileBytes = await fileToUpload.readAsBytes();
        final enc = MessageEncryptionService.instance;
        if (enc.isReady) {
          final encrypted = enc.encryptBytes(Uint8List.fromList(fileBytes));
          if (encrypted != null) fileBytes = encrypted;
        }

        await supabase.storage
            .from('documents')
            .uploadBinary(filePath, fileBytes,
              fileOptions: const FileOptions(contentType: 'application/octet-stream'),
            );

        // ✅ Phase 2B: Store storage path (not public URL)
        uploadedUrls.add(filePath);

        debugPrint("✅ Uploaded $fileName - path: $filePath");
      }

      // ✅ Calculate total file size for tracking
      int totalFileSizeBytes = 0;
      for (final file in filesToUpload) {
        totalFileSizeBytes += await file.length();
      }
      debugPrint("📦 Total file size: $totalFileSizeBytes bytes");

      String previewUrl = uploadedUrls.first;
      if (isPdf) {
        debugPrint("🖼 Generating PDF thumbnail...");
        final generated = await context
            .read<DocumentsCubit>()
            .generatePdfThumbnail(
          widget.images.first,
          tempId,
          userId,
        );
        if (generated != null) {
          previewUrl = generated;
          debugPrint("✅ Thumbnail generated: $previewUrl");
        } else {
          debugPrint(
              "⚠️ Thumbnail generation failed, using first URL");
        }
      }

      final userDocument = UserDocument(
        id: '',
        userId: userId,
        name: name,
        type: docType,
        fileType: fileType,
        patientId: _selectedPatientId!,
        previewUrl: previewUrl,
        pages: isPdf && widget.pageCount != null
            ? List.generate(
            widget.pageCount!, (index) => uploadedUrls.first)
            : uploadedUrls,
        uploadedAt: uploadedAt,
        uploadedById: userId,
        cameFromConversation: widget.cameFromConversation,
        conversationDoctorName: widget.conversationDoctorName,
        encrypted: true, // ✅ Phase 2C: Mark as encrypted
        fileSizeBytes: totalFileSizeBytes, // ✅ Track total file size
      );

      debugPrint("📝 Inserting document into Supabase...");
      final response = await supabase
          .from('documents')
          .insert(userDocument.toMap())
          .select('id')
          .single();

      final realId = response['id'];
      debugPrint("✅ Document inserted with id = $realId");

      if (!mounted) return;
      final switcher = context.read<PatientSwitcherCubit>().state;
      context.read<DocumentsCubit>().listenToDocuments(
        context: context,
        relativeId: switcher.relativeId,
        forceReload: true,
      );
      context.read<StorageQuotaCubit>().loadStorageUsage();

      Navigator.pop(context, true);
      // (Removed Double Pop - let the caller handle it)
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.main.withOpacity(0.8),
          content: Text(locale.documentUploadedSuccessfully),
        ),
      );
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red.withOpacity(0.8),
            content: Text(
              e.toString().contains("PDF too large")
                  ? locale.pdfTooLarge
                  : e.toString().contains("Document too large")
                  ? locale.documentTooLarge
                  : locale.uploadFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String> _generateAutoName(String userId) async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('documents')
        .select('id')
        .eq('uploaded_by_id', userId);

    final count = response.length;
    final nextNumber = count + 1;

    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'ar' ? ' ملف $nextNumber' : 'Document $nextNumber';
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    DropdownButtonBuilder? selectedItemBuilder,
    bool showError = false,
    String? errorText,
  }) {
    final hasError = showError && value == null;
    final borderColor = hasError ? AppColors.red : Colors.grey;
    final labelColor = hasError ? AppColors.red : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            icon:
            Icon(Icons.arrow_drop_down, color: hasError ? AppColors.red : AppColors.main, size: 22.sp),
            borderRadius: BorderRadius.circular(15.r),
            menuMaxHeight: 380.h,
            dropdownColor: Colors.white.withOpacity(0.99),
            elevation: 1,
            selectedItemBuilder: selectedItemBuilder,
            decoration: InputDecoration(
              labelText: hint,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelStyle: AppTextStyles.getText3(context)
                  .copyWith(color: labelColor, fontSize: 12.sp),
              floatingLabelStyle: AppTextStyles.getText3(context)
                  .copyWith(color: hasError ? AppColors.red : AppColors.main, fontSize: 14.sp),
              hintStyle: AppTextStyles.getText3(context)
                  .copyWith(color: Colors.grey, fontSize: 11.sp),
              contentPadding:
              EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.r),
                borderSide: BorderSide(color: borderColor, width: hasError ? 1.5 : 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.r),
                borderSide:
                BorderSide(color: hasError ? AppColors.red : AppColors.main, width: 2),
              ),
            ),
            items: items,
            onChanged: (val) {
              onChanged(val);
              if (_triedToSubmit) setState(() {});
            },
          ),
        ),
        if (hasError && errorText != null)
          Padding(
            padding: EdgeInsets.only(top: 4.h, left: 14.w, right: 14.w),
            child: Text(
              errorText,
              style: AppTextStyles.getText3(context).copyWith(
                color: AppColors.red,
                fontSize: 10.sp,
              ),
            ),
          ),
      ],
    );
  }
}
