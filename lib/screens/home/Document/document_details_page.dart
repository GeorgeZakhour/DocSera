import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/screens/home/Document/edit_document_name_sheet.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:intl/intl.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentDetailsPage extends StatefulWidget {
  final UserDocument document;

  const DocumentDetailsPage({super.key, required this.document});

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  late String documentName;

  @override
  void initState() {
    super.initState();
    documentName = widget.document.name;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _resolveFileFormat(AppLocalizations locale) {
    final ft = widget.document.fileType.toLowerCase();
    if (ft.contains('pdf')) return locale.formatPdf;
    if (ft.contains('image') || ft.contains('jpg') || ft.contains('jpeg') || ft.contains('png') || ft.contains('webp')) {
      return locale.formatImage;
    }
    if (ft.isNotEmpty) return ft.toUpperCase();
    return locale.formatUnknown;
  }

  String _resolveSource(AppLocalizations locale) {
    switch (widget.document.source) {
      case 'patient':
        return locale.sourceUploadedByYou;
      case 'doctor_added':
        final name = widget.document.sourceDoctorName;
        if (name != null && name.isNotEmpty) {
          return locale.sourceAddedByDoctor(name);
        }
        return locale.sourceBadgeDoctor;
      default:
        return widget.document.source;
    }
  }

  Color _sourceColor() {
    switch (widget.document.source) {
      case 'patient':
        return AppColors.main;
      case 'doctor_added':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;
    final damascusTime = DocSeraTime.toSyria(widget.document.uploadedAt);
    final formattedDate = DateFormat('d MMMM yyyy', langCode).format(damascusTime);
    final formattedTime = DateFormat('HH:mm', langCode).format(damascusTime);
    final pageCount = widget.document.pages.length;
    final sourceColor = _sourceColor();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(locale.documentDetails, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.blackText),
            onPressed: () => Navigator.pop(
              context,
              widget.document.copyWith(name: documentName),
            ),
          )
        ],
      ),
      backgroundColor: AppColors.background2,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Source badge ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sourceColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.document.source == 'patient' ? Icons.cloud_upload_rounded : Icons.person_rounded,
                    size: 14.sp,
                    color: sourceColor,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    _resolveSource(locale),
                    style: AppTextStyles.getText3(context).copyWith(
                      color: sourceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── Name (editable for own files) ──
            _buildRow(
              context,
              Icons.label_rounded,
              locale.nameOfTheDocument,
              documentName,
              canEdit: widget.document.source == 'patient',
            ),

            // ── File format ──
            _buildRow(context, Icons.description_rounded, locale.detailFileFormat, _resolveFileFormat(locale)),

            // ── File size ──
            if (widget.document.fileSizeBytes > 0)
              _buildRow(context, Icons.data_usage_rounded, locale.detailFileSize, _formatFileSize(widget.document.fileSizeBytes)),

            // ── Date ──
            _buildRow(context, Icons.calendar_today_rounded, locale.createdAt, formattedDate),

            // ── Time ──
            _buildRow(context, Icons.access_time_rounded, locale.time, formattedTime),

            // ── Source ──
            _buildRow(context, Icons.source_rounded, locale.detailSource, _resolveSource(locale)),

            // ── Patient concerned ──
            _buildPatientRow(context, locale.patientConcerned, widget.document),

            // ── Number of pages ──
            if (pageCount > 0)
              _buildRow(context, Icons.pages_rounded, locale.detailNumberOfPages, locale.detailPageCount(pageCount)),

            // ── Visibility ──
            _buildRow(context, Icons.visibility_rounded, locale.detailVisibility, locale.visibleToDoctors),

            // ── Encryption ──
            _buildIconValueRow(
              context,
              widget.document.encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
              locale.detailEncryption,
              widget.document.encrypted ? locale.encryptedYes : locale.encryptedNo,
              valueColor: widget.document.encrypted ? AppColors.main : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    bool canEdit = false,
  }) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16.sp, color: AppColors.main),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                  SizedBox(height: 3.h),
                  Text(
                    value,
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (canEdit)
              GestureDetector(
                onTap: _onEditName,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.main.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.edit,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 18.h, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildIconValueRow(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: (valueColor ?? AppColors.main).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16.sp, color: valueColor ?? AppColors.main),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                  SizedBox(height: 3.h),
                  Text(
                    value,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: 18.h, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildPatientRow(BuildContext context, String title, UserDocument doc) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_outline_rounded, size: 16.sp, color: AppColors.main),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                  SizedBox(height: 3.h),
                  FutureBuilder(
                    future: Supabase.instance.client
                        .from('users')
                        .select('first_name, last_name')
                        .eq('id', doc.patientId)
                        .maybeSingle(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text('...', style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600));
                      } else if (snapshot.hasData && snapshot.data != null) {
                        final data = snapshot.data as Map<String, dynamic>;
                        final name = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
                        // Found in users table — it's a main user, not a relative
                        return _buildPatientChip(name, data['first_name'] ?? '', data['last_name'] ?? '', isRelative: false);
                      } else {
                        return FutureBuilder(
                          future: Supabase.instance.client
                              .from('relatives')
                              .select('first_name, last_name')
                              .eq('id', doc.patientId)
                              .maybeSingle(),
                          builder: (context, relSnap) {
                            if (relSnap.connectionState == ConnectionState.waiting) {
                              return Text('...', style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600));
                            } else if (relSnap.hasData && relSnap.data != null) {
                              final data = relSnap.data as Map<String, dynamic>;
                              final name = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
                              // Found in relatives table — yellow avatar
                              return _buildPatientChip(name, data['first_name'] ?? '', data['last_name'] ?? '', isRelative: true);
                            }
                            return Text(
                              AppLocalizations.of(context)!.unknown,
                              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: 18.h, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildPatientChip(String fullName, String firstName, String lastName, {bool isRelative = false}) {
    final avatar = _getAvatarText(firstName, lastName);
    final avatarColor = isRelative ? const Color(0xFFF5A623) : AppColors.main;
    return Row(
      children: [
        CircleAvatar(
          radius: 12.r,
          backgroundColor: avatarColor,
          child: Text(
            avatar,
            style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          fullName,
          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _onEditName() async {
    final cubit = context.read<DocumentsCubit>();
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = prefs.getString('userId') ?? '';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditDocumentNameSheet(
        initialName: documentName,
        onConfirm: (newName) {
          cubit.renameDocument(
            docId: widget.document.id!,
            newName: newName,
            userId: mainUserId,
          );
          setState(() {
            documentName = newName;
          });
        },
        onNameUpdated: (newName) {
          setState(() {
            documentName = newName;
          });
        },
      ),
    );
  }

  String _getAvatarText(String firstName, String lastName) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    if (isArabic) {
      return _normalizeArabicInitial(firstName).toUpperCase();
    }
    return "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase();
  }

  String _normalizeArabicInitial(String input) {
    if (input.isEmpty) return '';
    String firstChar = input[0];
    return firstChar == 'ه' ? 'هـ' : firstChar;
  }
}
