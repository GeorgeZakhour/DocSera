import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

class DoctorConversationPage extends StatefulWidget {
  final String conversationId;
  final String patientName;
  final String accountHolderName;
  final String selectedReason;
  final bool isClosed;
  final String doctorName;
  final String doctorImage;

  const DoctorConversationPage({
    Key? key,
    required this.conversationId,
    required this.patientName,
    required this.accountHolderName,
    required this.selectedReason,
    required this.isClosed,
    required this.doctorName,
    required this.doctorImage,
  }) : super(key: key);

  @override
  State<DoctorConversationPage> createState() => _DoctorConversationPageState();
}

class _DoctorConversationPageState extends State<DoctorConversationPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool showReplyOptions = true;
  bool hasResponded = false;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get()
        .then((doc) {
      final data = doc.data();
      if (data != null && data['hasDoctorResponded'] == true) {
        setState(() {
          showReplyOptions = false;
          hasResponded = true;
        });
      }
    });
  }

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  String _getInitials(String name) {
    final isAr = _isArabic(name);
    final parts = name.trim().split(' ');
    if (isAr) {
      final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';
      return firstChar == 'ه' ? 'هـ' : firstChar;
    } else {
      final first = parts.isNotEmpty ? parts[0][0] : '';
      final second = parts.length > 1 ? parts[1][0] : '';
      return (first + second).toUpperCase();
    }
  }

  String _formatReadTime(DateTime? date, String lang) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return intl.DateFormat('HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
    } else if (messageDate == yesterday) {
      final time = intl.DateFormat('HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
      return lang == 'ar' ? 'أمس الساعة $time' : 'Yesterday at $time';
    } else {
      return intl.DateFormat('d MMM • HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);

    final msgRef = conversationRef.collection('messages').doc();

    await msgRef.set({
      'text': text,
      'isUser': false,
      'senderName': widget.doctorName,
      'timestamp': FieldValue.serverTimestamp(),
      'readByUser': false,
      'readByDoctor': true,
      'readByDoctorAt': FieldValue.serverTimestamp(),
      'readByUserAt': null,
    });

    // ✅ تحديث معلومات المحادثة ليتفعل الـ snapshot في MessagesCubit
    await conversationRef.update({
      'lastMessage': text,
      'lastSenderId': 'doctor', // أو uid حسب الحاجة
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageReadByUser': false,
      'lastMessageReadByDoctor': true,
      'unreadCountForUser': FieldValue.increment(1), // ✅ مضاف
    });


    _controller.clear();
  }


  void _showCloseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إغلاق المحادثة', style: AppTextStyles.getTitle1(context).copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 10.h),
            Text('هل أنت متأكد أنك تريد إغلاق هذه المحادثة؟ لن يتمكن المريض من الرد بعد ذلك.',
              textAlign: TextAlign.center,
              style: AppTextStyles.getText3(context),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .update({'isClosed': true});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
              ),
              child: Text('إغلاق المحادثة', style: AppTextStyles.getText3(context).copyWith(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: AppTextStyles.getText3(context)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: AppColors.whiteText, size: 28.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.patientName, style: TextStyle(color: AppColors.whiteText, fontWeight: FontWeight.bold, fontSize: 14.sp)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Chat-BG.png', fit: BoxFit.cover),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .collection('messages')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!.docs;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });


                    bool hasUnread = false;
                    int unreadCount = 0;

                    for (final doc in messages) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isUser = data['isUser'] ?? false;
                      final alreadyRead = data['readByDoctor'] == true;

                      if (isUser && !alreadyRead) {
                        doc.reference.update({
                          'readByDoctor': true,
                          'readByDoctorAt': FieldValue.serverTimestamp(),
                        });
                        unreadCount++;
                      }
                    }

                    if (unreadCount > 0) {
                      FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .update({
                        'lastMessageReadByDoctor': true,
                        'unreadCountForDoctor': 0, // ✅ هذا الحقل هو ما يظهر عدد غير المقروء في DoctorMessagesPage
                      });
                    }




                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                                left: 16.w,
                                right: 16.w,
                                top: widget.isClosed
                                    ? 25.h
                                    : widget.patientName != widget.accountHolderName
                                ? 20.h
                                    : 12.h,
                                bottom: 65.h),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index].data() as Map<String, dynamic>;
                              final time = (msg['timestamp'] as Timestamp?)?.toDate();
                              final isUser = msg['isUser'] ?? false;
                              final content = msg['text'] ?? '';
                              final senderName = msg['senderName'] ?? '';

                              final bool isReadByUser = !isUser && (msg['readByUser'] == true);
                              final bool isLastRead = isReadByUser && (index == messages.length - 1);
                              final readByUserAt = (msg['readByUserAt'] as Timestamp?)?.toDate();


                              // ✅ منطق فاصل التاريخ
                              DateTime? currentDate = time != null ? DateTime(time.year, time.month, time.day) : null;
                              DateTime? previousDate;
                              if (index > 0) {
                                final prevTime = (messages[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                                final prevDate = prevTime?.toDate();
                                if (prevDate != null) {
                                  previousDate = DateTime(prevDate.year, prevDate.month, prevDate.day);
                                }
                              }
                              final showDivider = previousDate != currentDate;

                              return Column(
                                children: [
                                  if (showDivider && time != null)
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10.h),
                                      child: Row(
                                        children: [
                                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                          Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                                            child: Text(
                                              intl.DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(time),
                                              style: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.black54),
                                            ),
                                          ),
                                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                        ],
                                      ),
                                    ),

                                  // ✅ الرسالة نفسها
                                  Align(
                                    alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 8.h),
                                      padding: EdgeInsets.all(10.w),
                                      constraints: BoxConstraints(maxWidth: 0.7.sw),
                                      decoration: BoxDecoration(
                                        color: isUser ? AppColors.grayMain.withOpacity(0.25) : AppColors.main.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(senderName, style: AppTextStyles.getText2(context).copyWith(
                                            color: isUser ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          )),
                                          SizedBox(height: 6.h),
                                          Text(content, style: AppTextStyles.getText2(context).copyWith(
                                            color: isUser ? Colors.black87 : Colors.white,
                                          )),
                                          SizedBox(height: 4.h),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              time != null ? intl.DateFormat('HH:mm').format(time) : '',
                                              style: AppTextStyles.getText3(context).copyWith(
                                                color: isUser ? Colors.black45 : Colors.white70,
                                                fontSize: 10.sp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (isLastRead) ...[
                                    Align(
                                      alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 7.r,
                                            backgroundColor: AppColors.main.withOpacity(0.5),
                                            child: Icon(Icons.person, size: 9.sp, color: Colors.white),
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            '${AppLocalizations.of(context)!.read} • ${_formatReadTime(readByUserAt, lang)}',
                                            style: AppTextStyles.getText3(context).copyWith(fontSize: 9.sp, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                ],
                              );
                            },

                          ),
                        ),

                        if (widget.isClosed)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildClosedInfo(context),
                          )
                        else if (showReplyOptions && !hasResponded)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildReplyOptions(),
                          )
                        else
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildSendMessageBar(context),
                          ),

                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          if (widget.isClosed)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  color: AppColors.main.withOpacity(0.5),
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18, color: Colors.black54),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          "تم إغلاق هذه المحادثة. لا يمكنك الرد بعد الآن.",
                          style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),



          if (widget.patientName != widget.accountHolderName)
            if (widget.patientName != widget.accountHolderName)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.grayMain.withOpacity(0.35),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      child: Row(
                        children: _isArabic(widget.accountHolderName)
                            ? [
                          Text("الرسالة من حساب: ",

                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 10.sp,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 6.w),

                          CircleAvatar(
                            radius: 10.r,
                            backgroundColor: AppColors.main.withOpacity(0.9),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.translate(
                                offset: const Offset(0, -1.5),
                                child: Text(
                                  _getInitials(widget.accountHolderName),
                                  style: AppTextStyles.getText3(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.whiteText,
                                    fontSize: 9.sp,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),

                          Text(
                            widget.accountHolderName,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                        ]
                            : [
                          CircleAvatar(
                            radius: 10.r,
                            backgroundColor: AppColors.main.withOpacity(0.9),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.translate(
                                offset: const Offset(0, -1.5),
                                child: Text(
                                  _getInitials(widget.patientName),
                                  style: AppTextStyles.getText3(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.whiteText,
                                    fontSize: 9.sp,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            widget.accountHolderName,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "From the account of: ",
                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 12.sp,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),


        ],
      ),
    );
  }

  Widget _buildReplyOptions() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.grayMain.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showCloseDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Colors.red),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  child: Text('إغلاق المحادثة', style: AppTextStyles.getText3(context).copyWith(color: Colors.red)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .update({'hasDoctorResponded': true});
                    setState(() {
                      showReplyOptions = false;
                      hasResponded = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  child: Text('الرد على المحادثة', style: AppTextStyles.getText3(context).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendMessageBar(BuildContext context) {
    return SafeArea(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SizedBox(
            height: 55.h,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grayMain.withOpacity(0.15),
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp), // ✅ حجم النص المكتوب
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.writeYourMessage,
                        hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppColors.main,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white, size: 18.sp),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedInfo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ✅ فقط محتوى الـ Container يتأثر بـ blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: AppColors.grayMain.withOpacity(0.2),
                  ),
                ),
              ),

              // ✅ النص فوق الخلفية المبلورة
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Text(
                  AppLocalizations.of(context)!.conversationClosed,
                  style: AppTextStyles.getText3(context).copyWith(
                    fontSize: 12.sp,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showBottomMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
        child: ListTile(
          title: Center(
            child: Text('إغلاق المحادثة', style: AppTextStyles.getText2(context).copyWith(color: Colors.red)),
          ),
          onTap: () {
            Navigator.pop(context);
            _showCloseDialog();
          },
        ),
      ),
    );
  }
}
