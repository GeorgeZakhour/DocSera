import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/screens/home/Document/edit_document_name_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DocumentDetailsPage extends StatefulWidget {
  final UserDocument document;

  const DocumentDetailsPage({Key? key, required this.document}) : super(key: key);

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  late String documentName;
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

  @override
  void initState() {
    super.initState();
    documentName = widget.document.name; // نسخة قابلة للتعديل
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('d MMMM yyyy', Localizations.localeOf(context).languageCode)
        .format(widget.document.uploadedAt);
    final localizedType = _documentTypeMap[widget.document.type]?.call(locale) ?? widget.document.type;

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
            )
            ,
          )
        ],
      ),
      backgroundColor: AppColors.background2,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow(context, locale.nameOfTheDocument, documentName, canEdit: true),
            _buildRow(context, locale.typeOfTheDocument, localizedType),
            _buildRow(context, locale.createdAt, formattedDate),
            FutureBuilder<DocumentSnapshot>(
              future: widget.document.uploadedById.isNotEmpty
                  ? FirebaseFirestore.instance.collection('users').doc(widget.document.uploadedById).get()
                  : null,
              builder: (context, snapshot) {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildRow(context, locale.createdBy, '...');
                } else if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final isCurrentUser = widget.document.uploadedById == currentUserId;
                  final fullName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();

                  return _buildRowRich(
                    context,
                    locale.createdBy,
                    fullName,
                    isCurrentUser ? "(${locale.you})" : null,
                  );
                } else {
                  return _buildRow(context, locale.createdBy, locale.unknown);
                }
              },
            ),

            _buildPatientRow(context, locale.patientConcerned, widget.document),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.lock, size: 16.sp, color: AppColors.main),
                SizedBox(width: 8.w),
                Text(
                  locale.encryptedDocument,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.main),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRowRich(BuildContext context, String title, String mainText, [String? lightSuffix]) {
    final isArabic = Directionality.of(context) == TextDirection.RTL;
    return Column(
      children: [
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText3(context)),
                  SizedBox(height: 6.h),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.blackText,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: mainText),
                        if (lightSuffix != null)
                          TextSpan(
                            text: isArabic ? ' $lightSuffix' : ' $lightSuffix',
                            style: AppTextStyles.getText3(context).copyWith(
                              color: AppColors.blackText,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: 18.h, color: Colors.grey[300]),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String title, String value, {bool canEdit = false}) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText3(context)),
                  SizedBox(height: 6.h),
                  Text(value, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (canEdit)
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final mainUserId = prefs.getString('userId') ?? '';

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => EditDocumentNameSheet(
                      initialName: documentName,
                      onConfirm: (newName) async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(mainUserId) // ✅ هذا هو الحساب الأساسي، وليس الـ patientId
                            .collection('documents')
                            .doc(widget.document.id)
                            .update({'name': newName});
                      },
                      onNameUpdated: (newName) {
                        setState(() {
                          documentName = newName;
                        });
                      },
                    ),
                  );
                },

                child: Text(
                  AppLocalizations.of(context)!.edit,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.main,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),


          ],
        ),
        Divider(height: 18.h, color: Colors.grey[300]),
      ],
    );
  }

  Widget _buildPatientRow(BuildContext context, String title, UserDocument doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Text(title, style: AppTextStyles.getText3(context)),
        SizedBox(height: 6.h),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(doc.patientId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPatientRowUI('...', '');
            } else if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final firstName = data['firstName'] ?? '';
              final lastName = data['lastName'] ?? '';
              final fullName = "$firstName $lastName".trim();
              final avatarText = _getAvatarText(firstName, lastName);

              return _buildPatientRowUI(fullName, avatarText);
            } else {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('relatives')
                    .doc(doc.patientId)
                    .get(),
                builder: (context, relativeSnapshot) {
                  if (relativeSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPatientRowUI('...', '');
                  } else if (relativeSnapshot.hasData && relativeSnapshot.data!.exists) {
                    final data = relativeSnapshot.data!.data() as Map<String, dynamic>;
                    final firstName = data['firstName'] ?? '';
                    final lastName = data['lastName'] ?? '';
                    final fullName = "$firstName $lastName".trim();
                    final avatarText = _getAvatarText(firstName, lastName);

                    return _buildPatientRowUI(fullName, avatarText);
                  } else {
                    return _buildPatientRowUI(AppLocalizations.of(context)!.unknown, '?');
                  }
                },
              );
            }
          },
        ),
        Divider(height: 18.h, color: Colors.grey[300]),
      ],
    );
  }

  Widget _buildPatientRowUI(String name, String avatarText) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14.r,
          backgroundColor: AppColors.main,
          child: Text(
            avatarText,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.white),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          name,
          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getAvatarText(String firstName, String lastName) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    if (isArabic) {
      return normalizeArabicInitial(firstName).toUpperCase();
    } else {
      return "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase();
    }
  }


  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return '';
    String firstChar = input[0];
    return firstChar == 'ه' ? 'هـ' : firstChar;
  }
}
