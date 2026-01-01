import 'dart:io';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_details_page.dart';
import 'package:docsera/screens/home/Document/edit_document_name_sheet.dart';
import 'package:docsera/screens/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/screens/home/Document/document_info_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void showConversationPdfOptionsSheet(
    BuildContext context,
    UserDocument document,
    String patientId,
    String doctorName,
    ) {
  final local = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final formattedDate = DateFormat('d MMM yyyy', locale).format(document.uploadedAt);

  final importedText = local.importedFromConversationWith(formattedDate,doctorName);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                children: [
                  SvgPicture.asset('assets/icons/pdf-file.svg', width: 30.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(document.name,
                            style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4.h),
                        Text(
                          importedText,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.grayMain),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 10.h, color: Colors.grey[300]),
            _buildOption(
              context,
              Icons.save_alt,
              local.save,
              onTap: () async {
                Navigator.pop(ctx);
                await launchUrl(Uri.parse(document.pages.first));
              },
            ),
            _buildOption(
              context,
              SvgPicture.asset('assets/icons/save2documents.svg', width: 20.w),
              local.addToDocuments,
              onTap: () async {
                Navigator.pop(ctx);

                final tempDir = await getTemporaryDirectory();
                final tempFilePath = '${tempDir.path}/${document.name}.pdf';
                final tempFile = File(tempFilePath);

                try {
                  final response = await http.get(Uri.parse(document.pages.first));
                  await tempFile.writeAsBytes(response.bodyBytes);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentInfoScreen(
                        images: [tempFile.path],
                        initialName: document.name,
                        cameFromMultiPage: false,
                        pageCount: 1,
                        initialPatientId: patientId,
                        cameFromConversation: true, // 👈 ضروري
                        conversationDoctorName: doctorName, // 👈 ضروري
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(local.uploadFailed),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 12.h),
          ],
        ),
      );
    },
  );
}

void showDocumentOptionsSheet(
    BuildContext context,
    UserDocument document, {
      String? doctorName,
    }) {
  final locale = Localizations.localeOf(context).languageCode;
  final formattedDate = DateFormat('d MMM yyyy', locale).format(document.uploadedAt);
  final local = AppLocalizations.of(context)!;
  final importedText = local.importedFromConversationWith(
    formattedDate,
    document.conversationDoctorName ?? ''
  );
  final createdByText = document.cameFromConversation && doctorName != null
      ? local.importedFromConversationWith(doctorName, formattedDate)
      : local.createdByYou(formattedDate);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                children: [
                    SvgPicture.asset('assets/icons/pdf-file.svg', width: 30.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          document.cameFromConversation ? importedText : createdByText,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.grayMain),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 10.h, color: Colors.grey[300]),
            _buildOption(
              context,
              Icons.email_outlined,
              local.sendToDoctor,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchPage(mode: "message", attachedDocument: document),
                  ),
                );
              },
            ),
            _buildOption(
              context,
              Icons.edit_outlined,
              local.rename,
              onTap: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                final mainUserId = prefs.getString('userId') ?? '';
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.white,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
                  builder: (_) => EditDocumentNameSheet(
                    initialName: document.name,
                    onConfirm: (newName) async {
                      await Supabase.instance.client
                          .from('documents')
                          .update({'name': newName})
                          .eq('id', document.id!)
                          .eq('user_id', mainUserId);
                    },
                    onNameUpdated: (newName) {
                      Future.delayed(const Duration(milliseconds: 50), () {
                        context.read<DocumentsCubit>().listenToDocuments(context: context);
                      });
                    },
                  ),
                );
              },
            ),
            _buildOption(
              context,
              Icons.info_outline,
              local.viewDetails,
              onTap: () {
                Navigator.pop(context);
                Navigator.push<UserDocument?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentDetailsPage(document: document),
                  ),
                ).then((_) => Future.delayed(const Duration(milliseconds: 50), () {
                  context.read<DocumentsCubit>().listenToDocuments(context: context);
                }));
              },
            ),
            _buildOption(
              context,
              Icons.download,
              local.download,
              onTap: () async {
                Navigator.pop(context);
                await _downloadDocumentAsPDF(context, document);
              },
            ),
            _buildOption(
              context,
              Icons.delete,
              local.delete,
              onTap: () async {
                Navigator.pop(context);
                await showDeleteConfirmationDialog(
                  context: context,
                  document: document,
                  onConfirmDelete: () async {
                    await context.read<DocumentsCubit>().deleteDocument(document: document, context: context);
                  },
                );
              },
              isRed: true,
            ),
            SizedBox(height: 12.h),
          ],
        ),
      );
    },
  );
}

Widget _buildOption(BuildContext context, dynamic icon, String title,
    {required VoidCallback onTap, bool isRed = false}) {
  return Column(
    children: [
      ListTile(
        dense: true,
        minVerticalPadding: 0,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 8.w,
        leading: icon is IconData
            ? Icon(icon, color: isRed ? AppColors.red : AppColors.main, size: 18.sp)
            : icon, // مثلاً SvgPicture
        title: Text(
          title,
          style: AppTextStyles.getText3(context).copyWith(
            color: isRed ? AppColors.red : AppColors.main,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
      Divider(height: 1.h, color: Colors.grey[300]),
    ],
  );
}

Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isGranted) return true;

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
  return false;
}



Future<void> _downloadDocumentAsPDF(BuildContext context, UserDocument doc) async {
  final pdf = pw.Document();
  final hasPermission = await _requestStoragePermission();
  if (!hasPermission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.permissionDenied), backgroundColor: AppColors.red.withOpacity(0.8)),
    );
    return;
  }

  final dir = Directory('/storage/emulated/0/Download'); // ✅ تعديل مكان التخزين
  final file = File('${dir.path}/${doc.name}.pdf');

  if (doc.type == 'pdf' && doc.pages.length == 1) {
    final response = await http.get(Uri.parse(doc.pages.first));
    await file.writeAsBytes(response.bodyBytes);
  } else {
    for (String imageUrl in doc.pages) {
      final response = await http.get(Uri.parse(imageUrl));
      final imageBytes = response.bodyBytes;
      final image = pw.MemoryImage(imageBytes);

      final decodedImage = await decodeImageFromList(imageBytes);
      final width = decodedImage.width.toDouble();
      final height = decodedImage.height.toDouble();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, height),
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }

    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context)!.downloadSuccess), backgroundColor: AppColors.main.withOpacity(0.8)),
  );
}


Future<void> showDeleteConfirmationDialog({
  required BuildContext context,
  required UserDocument document,
  required VoidCallback onConfirmDelete,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.deleteTheDocument,
              style: AppTextStyles.getTitle2(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.areYouSureToDelete(document.name),
              style: AppTextStyles.getText2(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onPressed: () {
                Navigator.pop(context);
                onConfirmDelete();
              },
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.delete,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold,color: AppColors.blackText),
              ),
            ),
          ],
        ),
      );
    },
  );
}
