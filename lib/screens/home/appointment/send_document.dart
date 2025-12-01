import 'dart:io';
import 'dart:ui';
import 'package:docsera/screens/home/Document/add_image_preview_sheet.dart';
import 'package:docsera/screens/home/Document/document_info_screen.dart';
import 'package:docsera/screens/home/Document/multi_page_upload_screen.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class SendDocumentToDoctorPage extends StatefulWidget {
  final String doctorName;
  final String appointmentId; // 👈 جديد

  const SendDocumentToDoctorPage({
    Key? key,
    required this.doctorName,
    required this.appointmentId,
  }) : super(key: key);

  @override
  State<SendDocumentToDoctorPage> createState() => _SendDocumentToDoctorPageState();
}

class _SendDocumentToDoctorPageState extends State<SendDocumentToDoctorPage> {
  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return BaseScaffold(
      title: Text(
        local.sendDocuments,
        style: AppTextStyles.getTitle1(context).copyWith(
          color: AppColors.whiteText,
          fontSize: 13.sp,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.main,
                  child: Icon(Icons.lock, color: Colors.white, size: 14),
                  radius: 12,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText),
                      children: [
                        TextSpan(text: '${local.sendDocumentsTo} '),
                        TextSpan(
                          text: widget.doctorName,
                          style: AppTextStyles.getText2(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.blackText,
                          ),
                        ),
                        TextSpan(text: ' ${local.beforeConsultation}.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                local.exampleDocuments,
                style: AppTextStyles.getText3(context).copyWith(
                  color: Colors.black87,
                  fontSize: 11.sp,
                ),
              ),
            ),
            SizedBox(height: 25.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 40.h),
                ),
                onPressed: () => _pickAndUploadFile(context),
                icon: Icon(Icons.upload_file, color: Colors.white, size: 16.sp),
                label: Text(
                  local.addDocument,
                  style: AppTextStyles.getText2(context).copyWith(
                    fontSize: 12.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${local.sizeLimit}: 5 MB',
                  style: AppTextStyles.getText3(context).copyWith(
                    fontSize: 10.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${local.acceptedFormat}: jpeg, jpg, png, pdf',
                  style: AppTextStyles.getText3(context).copyWith(
                    fontSize: 10.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<File> _persistImage(String originalPath) async {
    final dir = await getTemporaryDirectory();
    final newPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(originalPath).copy(newPath);
  }


  void _pickAndUploadFile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final local = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                local.chooseAddDocumentMethod,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.grayMain),
              ),
              SizedBox(height: 10.h),
              Divider(height: 1.h, color: Colors.grey[200]),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconAction(
                    context,
                    iconPath: 'assets/icons/camera.svg',
                    label: local.takePhoto,
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (pickedImage != null) {
                        final safeFile = await _persistImage(pickedImage.path);
                        _handleImagePicked(context, safeFile.path);
                      }

                    },
                  ),
                  _buildIconAction(
                    context,
                    iconPath: 'assets/icons/gallery.svg',
                    label: local.chooseFromLibrary,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null && result.files.isNotEmpty) {
                        final safeFile = await _persistImage(result.files.first.path!);
                        _handleImagePicked(context, safeFile.path);
                      }

                    },
                  ),
                  _buildIconAction(
                    context,
                    iconPath: 'assets/icons/file.svg',
                    label: local.chooseFile,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        _handlePdfPicked(context, result.files.first.path!);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconAction(BuildContext context,
      {required String iconPath, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.main.withOpacity(0.1),
            ),
            child: Center(
              child: SvgPicture.asset(iconPath, width: 22.w, height: 22.w),
            ),
          ),
          SizedBox(height: 8.h),
          Text(label, style: AppTextStyles.getText3(context)),
        ],
      ),
    );
  }

  Future<File> _forceToJpg(String path) async {
    final dir = await getTemporaryDirectory();
    final newPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final bytes = await File(path).readAsBytes();
    final decoded = await decodeImageFromList(bytes);

    final buffer = await decoded.toByteData(format: ImageByteFormat.png);
    final file = File(newPath)..writeAsBytesSync(buffer!.buffer.asUint8List());
    return file;
  }


  void _handleImagePicked(BuildContext context, String imagePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AddImagePreviewSheet(
          imagePath: imagePath,
          onAdd: () async {
            Navigator.pop(sheetContext);

            // IMPORTANT — convert + persist
            final fixedFile = await _forceToJpg(imagePath);
            final safeFile = await _persistImage(fixedFile.path);

            Future.microtask(() {
              _goToMultiImageUploadFlow(context, safeFile.path);
            });
          },
        );
      },
    );
  }




  Future<void> _goToMultiImageUploadFlow(BuildContext context, String firstImagePath) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiPageUploadScreen(
          images: [firstImagePath],
          isSendMode: true,
          appointmentId: widget.appointmentId, // 👈 جديد
        ),
      ),
    );

    if (result == true) {
      Navigator.pop(context, true);   // ⬅ يرجع إلى AppointmentDetailsPage
    }
  }


  void _handlePdfPicked(BuildContext context, String pdfPath) async {
    final fileName = path.basenameWithoutExtension(pdfPath);
    final pageCount = await getPdfPageCount(pdfPath);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentInfoScreen(
          images: [pdfPath],
          initialName: fileName,
          pageCount: pageCount,
          isSendMode: true,
          appointmentId: widget.appointmentId,   // 👈 جديد
        ),
      ),
    );


    if (result == true) {
      Navigator.pop(context, true);  // ⬅ يرجع إلى AppointmentDetailsPage
    }
  }

  Future<int> getPdfPageCount(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final count = document.pages.count;
    document.dispose();
    return count;
  }
}
