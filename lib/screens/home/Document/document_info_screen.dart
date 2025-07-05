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

  const DocumentInfoScreen({
    Key? key,
    required this.images,
    this.initialName,
    this.pageCount,
    this.cameFromMultiPage = false,
    this.initialPatientId,
    this.cameFromConversation = false,
    this.conversationDoctorName,
    this.isSendMode = false, // ← افتراضي رفع عادي
  }) : super(key: key);



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


    // فقط 3 تدرجات من كل لون
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

    // دمجهم بالتناوب
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) return;

    final supabase = Supabase.instance.client;

    // ✅ جلب بيانات المستخدم الأساسي
    final userResponse = await supabase
        .from('users')
        .select('first_name, last_name')
        .eq('id', userId)
        .maybeSingle();

    if (userResponse == null) return;

    final userName = "${userResponse['first_name'] ?? ''} ${userResponse['last_name'] ?? ''}".trim();
    _patients.add({'id': userId, 'name': userName});

    // ✅ جلب الأقارب من جدول relatives
    final relativesResponse = await supabase
        .from('relatives')
        .select('id, first_name, last_name')
        .eq('user_id', userId);

    for (var relative in relativesResponse) {
      final name = "${relative['first_name'] ?? ''} ${relative['last_name'] ?? ''}".trim();
      _patients.add({'id': relative['id'], 'name': name});
    }

    setState(() {});
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
                    style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.mainDark),
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
            // ✅ Document Name

            SizedBox(height: 6.h),
            TextFormField(
              controller: _nameController,
              style: AppTextStyles.getText2(context),
              maxLength: 50,
              decoration: InputDecoration(
                labelText: "${locale.nameOfTheDocument} (${locale.optional})",
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                floatingLabelStyle: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontSize: 14.sp),
                hintStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey, fontSize: 11.sp),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide: BorderSide(color: AppColors.main, width: 2),
                ),
              ),
            ),


            // ✅ Document Type Dropdown
            SizedBox(height: 10.h),
            _buildDropdownField(
              value: _selectedType,
              hint: locale.typeOfTheDocument,
              items: _documentTypeMap.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value(locale),
                    style: AppTextStyles.getText2(context), // ✅ ستايل موحّد
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedType = value),
            ),


            SizedBox(height: 20.h),

            // ✅ Patient Concerned Dropdown
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
                final color = avatarColors[index % avatarColors.length]; // ✅ تدرج لوني

                return DropdownMenuItem<String>(
                  value: patient['id'],
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14.r,
                        backgroundColor: color,
                        child: Text(
                          initials,
                          style: AppTextStyles.getText3(context).copyWith(color: Colors.white),
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


            // ✅ Lock Info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: AppColors.mainDark, size: 12.sp,),
                SizedBox(width: 4.w),
                Text(
                  locale.documentWillBeEncrypted,
                  style: AppTextStyles.getText3(context).copyWith(color: Colors.blueGrey),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // ✅ Submit Button
            ElevatedButton(
              onPressed: isFormValid && !_isUploading ? _submitDocument : null,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                backgroundColor: isFormValid && !_isUploading ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isUploading
                  ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
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
      return "${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}";
    }
  }

  Future<List<File>> compressImages(List<File> imageFiles) async {
    int totalOriginalSize = 0;
    int totalCompressedSize = 0;
    List<File> compressedImages = [];

    for (final file in imageFiles) {
      final realFile = File(file.absolute.path);
      final int originalSize = await realFile.length();
      totalOriginalSize += originalSize;

      debugPrint("🖼️ Real image path: ${realFile.path}");
      debugPrint("📄 Real image size: ${(originalSize / 1024).toStringAsFixed(2)} KB");

      if (originalSize <= 200 * 1024) {
        debugPrint("📷 Skipped compression (small file)");
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
        quality = 25; // fallback للصور الكبيرة
      }

      final targetPath = '${realFile.path}_compressed.jpg';

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        realFile.absolute.path,
        targetPath,
        quality: quality,
        keepExif: true,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        final File compressedFile = File(compressed.path);
        final int compressedSize = await compressedFile.length();

        final int maxAllowedSize = 2 * 1024 * 1024; // 2MB (or any threshold you want per image)

        if (compressedSize >= originalSize || compressedSize > maxAllowedSize) {
          debugPrint("📷 Compression skipped (inefficient or too big): original ${originalSize / 1024} KB, compressed ${compressedSize / 1024} KB");
          totalCompressedSize += originalSize;
          compressedImages.add(realFile);
        } else {
          debugPrint("📉 Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB");
          debugPrint("🗜️ Compression saved: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(2)}%");
          totalCompressedSize += compressedSize;
          compressedImages.add(compressedFile);
        }
      } else {
        debugPrint("⚠️ Compression failed, using original");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
      }
    }

    debugPrint("📦 Total original size: ${(totalOriginalSize / 1024).toStringAsFixed(2)} KB");
    debugPrint("📦 Total compressed size: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");

    if (totalCompressedSize > 2 * 1024 * 1024) {
      throw Exception("💥 Document too large after compression: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
    }

    return compressedImages;
  }

  void _submitDocument() async {
    setState(() => _isUploading = true);
    final locale = AppLocalizations.of(context)!;

    // ✅ تحقق إذا الوضع هو "إرسال فقط"
    if (widget.isSendMode) {
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.orangeText.withOpacity(0.8),
          content: Text(locale.sendDocumentsLater),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
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
      if (userId == null || userId.isEmpty) throw Exception("User ID not found");

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
        debugPrint("✅ Compression done. Pages: ${filesToUpload.length}");
      }

      final supabase = Supabase.instance.client;

      for (int i = 0; i < filesToUpload.length; i++) {
        final fileToUpload = filesToUpload[i];
        final fileName = isPdf ? 'file.pdf' : 'page_$i.jpg';
        final filePath = '$userId/documents/$tempId/$fileName';

        debugPrint("📤 Uploading file: $filePath");

        await supabase.storage.from('documents').upload(filePath, fileToUpload);
        final publicUrl = supabase.storage.from('documents').getPublicUrl(filePath);
        uploadedUrls.add(publicUrl);

        debugPrint("✅ Uploaded $fileName - URL: $publicUrl");
      }

      String previewUrl = uploadedUrls.first;
      if (isPdf) {
        debugPrint("🖼 Generating PDF thumbnail...");
        final generated = await context.read<DocumentsCubit>().generatePdfThumbnail(
          widget.images.first,
          tempId,
          userId,
        );
        if (generated != null) {
          previewUrl = generated;
          debugPrint("✅ Thumbnail generated: $previewUrl");
        } else {
          debugPrint("⚠️ Thumbnail generation failed, using first URL");
        }
      }

      final userDocument = UserDocument(
        id: '', // Supabase رح يولد ID تلقائيًا
        name: name,
        type: docType,
        fileType: fileType,
        patientId: _selectedPatientId!,
        previewUrl: previewUrl,
        pages: isPdf && widget.pageCount != null
            ? List.generate(widget.pageCount!, (index) => uploadedUrls.first)
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

      final realId = response['id']; // هذا هو UUID الحقيقي من Supabase
      debugPrint("✅ Document inserted");

      if (!mounted) return;
      context.read<DocumentsCubit>().listenToDocuments(context);

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
    DropdownButtonBuilder? selectedItemBuilder, // ✅ أضف هذا
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.arrow_drop_down, color: AppColors.main, size: 22.sp),
        borderRadius: BorderRadius.circular(15.r),
        menuMaxHeight: 380.h,
        dropdownColor: Colors.white.withOpacity(0.99),
        elevation: 1,
        selectedItemBuilder: selectedItemBuilder,
        decoration: InputDecoration(
          labelText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey, fontSize: 12.sp),
          floatingLabelStyle: AppTextStyles.getText3(context).copyWith(color: AppColors.main, fontSize: 14.sp),
          hintStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey, fontSize: 11.sp),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: const BorderSide(color: AppColors.main, width: 2),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
