import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
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
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
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
            if (document.source == 'patient')
            _buildOption(
              context,
              Icons.edit_outlined,
              local.rename,
                onTap: () async {
                final cubit = context.read<DocumentsCubit>();
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                final mainUserId = prefs.getString('userId') ?? '';

                if (!context.mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.white,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
                  builder: (_) => EditDocumentNameSheet(
                    initialName: document.name,
                    onConfirm: (newName) {
                       cubit.renameDocument(
                         docId: document.id!,
                         newName: newName,
                         userId: mainUserId,
                       );
                    },
                    onNameUpdated: null,
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
            if (document.source == 'patient')
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
                    if (context.mounted) {
                      context.read<StorageQuotaCubit>().loadStorageUsage();
                    }
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
  if (Platform.isIOS) return true; // iOS uses app sandbox — no permission needed
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
  return false;
}

/// Downloads bytes for a page reference — uses Supabase storage download for
/// relative paths and http.get for full URLs.
Future<Uint8List> _downloadPageBytes(String urlOrPath, String bucket) async {
  if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
    // Full URL — extract storage path and download, or fetch directly
    if (urlOrPath.contains('/storage/v1/object/public/$bucket/')) {
      final rawPath = urlOrPath.split('/$bucket/').last;
      final storagePath = Uri.decodeComponent(rawPath);
      return await Supabase.instance.client.storage
          .from(bucket)
          .download(storagePath);
    }
    final response = await http.get(Uri.parse(urlOrPath));
    return response.bodyBytes;
  }
  // Relative storage path → download directly
  return await Supabase.instance.client.storage
      .from(bucket)
      .download(urlOrPath);
}

/// Decrypts bytes if the document is encrypted, otherwise returns as-is.
Future<Uint8List> _maybeDecrypt(Uint8List bytes, bool encrypted) async {
  if (!encrypted) return bytes;
  try {
    final svc = MessageEncryptionService.instance;
    await svc.init();
    final decrypted = svc.decryptBytes(bytes);
    if (decrypted != null) return decrypted;
  } catch (e) {
    debugPrint('⚠️ Decryption failed, using raw bytes: $e');
  }
  return bytes;
}

Rect _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.of(context).size;
  return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
}

Future<void> _downloadDocumentAsPDF(BuildContext context, UserDocument doc) async {
  final origin = _shareOrigin(context);
  final hasPermission = await _requestStoragePermission();
  if (!hasPermission) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.permissionDenied), backgroundColor: AppColors.red.withValues(alpha: 0.8)),
      );
    }
    return;
  }

  try {
    final tempDir = await getTemporaryDirectory();
    final safeName = doc.name.replaceAll(RegExp(r'[^\w\s\-.]'), '_');
    final isPdf = doc.type == 'pdf' ||
        doc.fileType.toLowerCase().contains('pdf') ||
        doc.pages.first.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      // PDF — download, decrypt if needed, share via system share sheet
      var bytes = await _downloadPageBytes(doc.pages.first, doc.bucket);
      bytes = await _maybeDecrypt(bytes, doc.encrypted);
      final file = File('${tempDir.path}/$safeName.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
    } else if (doc.pages.length == 1) {
      // Single image — save directly to photo gallery
      final pageRef = doc.pages.first;
      final ext = pageRef.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      var bytes = await _downloadPageBytes(pageRef, doc.bucket);
      bytes = await _maybeDecrypt(bytes, doc.encrypted);
      final file = File('${tempDir.path}/$safeName.$ext');
      await file.writeAsBytes(bytes);
      await GallerySaver.saveImage(file.path);
    } else {
      // Multiple images — compose into a single PDF and share
      final pdf = pw.Document();
      for (String pageRef in doc.pages) {
        var imageBytes = await _downloadPageBytes(pageRef, doc.bucket);
        imageBytes = await _maybeDecrypt(imageBytes, doc.encrypted);
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
      final file = File('${tempDir.path}/$safeName.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.downloadSuccess), backgroundColor: AppColors.main.withValues(alpha: 0.8)),
      );
    }
  } catch (e) {
    debugPrint('❌ Download failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.uploadFailed), backgroundColor: AppColors.red.withValues(alpha: 0.8)),
      );
    }
  }
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
