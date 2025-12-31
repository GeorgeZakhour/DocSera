import 'dart:io';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
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

class _DocumentInfoScreenState extends State<DocumentInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedType;
  String? _selectedPatientId;
  List<Map<String, String>> _patients = [];
  late List<Color> avatarColors;
  bool _isUploading = false;

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
              onPressed: isFormValid && !_isUploading ? _submitDocument : null,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                backgroundColor:
                isFormValid && !_isUploading ? AppColors.main : Colors.grey,
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

      const int maxAllowedSize = 2 * 1024 * 1024;

      if (compressedSize >= originalSize || compressedSize > maxAllowedSize) {
        debugPrint("⚠️ Compression skipped (inefficient or >2MB)");
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

    if (totalCompressedSize > 2 * 1024 * 1024) {
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
      final String attachmentId = DateTime.now().millisecondsSinceEpoch.toString();

      // 📄 اسم الملف (إما من المستخدم أو Auto Name)
      final String name = _nameController.text.trim().isEmpty
          ? await _generateAutoName(userId)
          : _nameController.text.trim();

      final DateTime uploadedAt = DateTime.now();

      final bool isPdf = widget.images.first.toLowerCase().endsWith('.pdf');
      final String fileType = isPdf ? 'pdf' : 'image';

      // 🧮 تجهيز الملفات للرفع
      final List<File> filesToUpload = [];

      if (isPdf) {
        // ✅ PDF بدون ضغط – حد 5MB
        final pdfFile = File(widget.images.first);
        final sizeInBytes = await pdfFile.length();
        if (sizeInBytes > 5 * 1024 * 1024) {
          throw Exception("PDF too large");
        }
        filesToUpload.add(pdfFile);
      } else {
        // ✅ sendMode لموعد: لا ضغط، فقط تأكد أن كل صورة <= 5MB
        for (final imgPath in widget.images) {
          final file = File(imgPath);
          if (!file.existsSync()) {
            throw Exception("Image file not found: ${file.path}");
          }
          final size = await file.length();
          if (size > 5 * 1024 * 1024) {
            throw Exception("Document too large");
          }
          filesToUpload.add(file);
        }
      }

      // 📤 الرفع إلى Bucket appointments-attachments
      final supabase = Supabase.instance.client;
      final storage = supabase.storage.from('appointments-attachments');

      final List<String> paths = [];

      for (int i = 0; i < filesToUpload.length; i++) {
        final fileToUpload = filesToUpload[i];

        // نفس الفولدَر لكل Attachment، أسماء الملفات فقط تختلف
        final String fileName = isPdf ? 'file.pdf' : 'page_$i.jpg';
        final String filePath = '$userId/${widget.appointmentId}/$attachmentId/$fileName';

        await storage.upload(filePath, fileToUpload);
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
        'file_type': fileType,                 // "pdf" | "image"
        'paths': paths,                        // relative storage paths
        'page_count': pageCount,
        'preview_path': paths.isNotEmpty ? paths.first : null,
        'patient_id': _selectedPatientId,
        'uploaded_by_id': userId,
        'uploaded_at': uploadedAt.toIso8601String(),
        'source': 'appointment',
        'appointment_id': widget.appointmentId,
      };

      // 📥 قراءة الـ attachments الحالية من الموعد
      final apptRow = await supabase
          .from('appointments')
          .select('attachments')
          .eq('id', widget.appointmentId!)
          .maybeSingle();

      final List<dynamic> attachments =
          (apptRow?['attachments'] as List?)?.toList() ?? [];

      // ➕ إضافة الـ attachment الجديد
      attachments.add(attachment);

      // 💾 تحديث الموعد
      await supabase
          .from('appointments')
          .update({'attachments': attachments})
          .eq('id', widget.appointmentId!);

      if (!mounted) return;

      // ✅ رجوع إلى صفحة الإرسال
      Navigator.pop(context, true);

      // إذا جاي من MultiPage ترجع لورا كمان
      if (widget.cameFromMultiPage && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.main.withOpacity(0.8),
          content: Text(locale.documentUploadedSuccessfully),
        ),
      );
    } catch (e) {
      debugPrint("❌ Upload appointment attachment error: $e");
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
    }
  }

  void _submitDocument() async {
    final locale = AppLocalizations.of(context)!;
    setState(() => _isUploading = true);

    try {
      if (widget.isSendMode) {
        await _submitAppointmentAttachment(locale);
        return;
      }

      debugPrint("📤 Starting document submission...");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.uploadingDocument),
          backgroundColor: AppColors.main.withOpacity(0.7),
          duration: const Duration(seconds: 2),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      debugPrint("👤 Loaded userId: $userId");
      if (userId == null || userId.isEmpty) {
        throw Exception("User ID not found");
      }

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint("🆔 Generated temp ID used in file name: $tempId");

      final name = _nameController.text.trim().isEmpty
          ? await _generateAutoName(userId)
          : _nameController.text.trim();
      debugPrint("📄 Document name: $name");

      final uploadedAt = DateTime.now();
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
        if (sizeInBytes > 2 * 1024 * 1024) {
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

        await supabase.storage
            .from('documents')
            .upload(filePath, fileToUpload);
        final publicUrl =
        supabase.storage.from('documents').getPublicUrl(filePath);
        uploadedUrls.add(publicUrl);

        debugPrint("✅ Uploaded $fileName - URL: $publicUrl");
      }

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
      // context.read<DocumentsCubit>().listenToDocuments(context);

      Navigator.pop(context);
      if (widget.cameFromMultiPage && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

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
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        icon:
        Icon(Icons.arrow_drop_down, color: AppColors.main, size: 22.sp),
        borderRadius: BorderRadius.circular(15.r),
        menuMaxHeight: 380.h,
        dropdownColor: Colors.white.withOpacity(0.99),
        elevation: 1,
        selectedItemBuilder: selectedItemBuilder,
        decoration: InputDecoration(
          labelText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: AppTextStyles.getText3(context)
              .copyWith(color: Colors.grey, fontSize: 12.sp),
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
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
