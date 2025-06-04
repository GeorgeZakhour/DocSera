import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
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
  bool showReplyOptions = true;

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

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .add({
      'text': text,
      'isUser': false,
      'senderName': widget.doctorName,
      'timestamp': FieldValue.serverTimestamp(),
      'readByUser': false,
      'readByDoctor': true,
      'readByDoctorAt': FieldValue.serverTimestamp(),
      'readByUserAt': null,
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
            Text(
              'إغلاق المحادثة',
              style: AppTextStyles.getTitle1(context).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'هل أنت متأكد أنك تريد إغلاق هذه المحادثة؟ لن يتمكن المريض من الرد بعد ذلك.',
              textAlign: TextAlign.center,
              style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp),
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              child: Text(
                'إغلاق المحادثة',
                style: AppTextStyles.getText3(context).copyWith(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: AppTextStyles.getText3(context).copyWith(color: Colors.black),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _updateReadStatusIfNeeded(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final lastMsgDoc = snapshot.docs.last;
      final lastMsg = lastMsgDoc.data() as Map<String, dynamic>;

      final isUser = lastMsg['isUser'] ?? false;
      final readByDoctor = lastMsg['readByDoctor'] ?? false;

      if (isUser && !readByDoctor) {
        lastMsgDoc.reference.update({
          'readByDoctor': true,
          'readByDoctorAt': FieldValue.serverTimestamp(),
        });
      }
    }
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
          icon: Icon(Icons.chevron_right, color: AppColors.whiteText, size: 28.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.patientName,
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.patientName != widget.accountHolderName)
            Container(
              width: double.infinity,
              color: AppColors.grayMain.withOpacity(0.15),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                children: [
                  Text(
                    _isArabic(widget.accountHolderName) ? "الرسالة من حساب " : "From the account of: ",
                    style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                  ),
                  Text(
                    widget.accountHolderName,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.isClosed)
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
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

                _updateReadStatusIfNeeded(snapshot.data!);
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isUser = msg['isUser'] ?? false;
                    final content = msg['text'] ?? '';
                    final senderName = msg['senderName'] ?? '';
                    final time = (msg['timestamp'] as Timestamp?)?.toDate();
                    final readByDoctorAt = (msg['readByDoctorAt'] as Timestamp?)?.toDate();

                    final isLastMessage = index == messages.length - 1;

                    return Align(
                      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: 0.7.sw),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                            margin: EdgeInsets.only(bottom: 6.h),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.grey.shade200 : AppColors.mainDark,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12.r),
                                topRight: Radius.circular(12.r),
                                bottomLeft: isUser ? Radius.zero : Radius.circular(12.r),
                                bottomRight: isUser ? Radius.circular(12.r) : Radius.zero,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12.r,
                                      backgroundColor: isUser
                                          ? AppColors.main.withOpacity(0.6)
                                          : AppColors.whiteText.withOpacity(0.4),
                                      backgroundImage: !isUser
                                          ? (widget.doctorImage.startsWith('http')
                                          ? NetworkImage(widget.doctorImage)
                                          : AssetImage(widget.doctorImage)) as ImageProvider
                                          : null,
                                      child: isUser
                                          ? Text(
                                        _getInitials(senderName),
                                        style: AppTextStyles.getText3(context).copyWith(
                                          color: AppColors.whiteText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.sp,
                                        ),
                                      )
                                          : null,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      senderName,
                                      style: AppTextStyles.getText2(context).copyWith(
                                        color: isUser ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Directionality(
                                  textDirection: _isArabic(content) ? TextDirection.rtl : TextDirection.ltr,
                                  child: Text(
                                    content,
                                    style: AppTextStyles.getText2(context).copyWith(
                                      color: isUser ? Colors.black87 : Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    time != null ? intl.DateFormat('HH:mm').format(time) : '',
                                    style: AppTextStyles.getText3(context).copyWith(
                                      fontSize: 10.sp,
                                      color: isUser ? Colors.black54 : Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLastMessage && isUser)
                            Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: Row(
                                mainAxisAlignment: lang == 'ar'
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.main, size: 14.sp),
                                  SizedBox(width: 4.w),
                                  Text(
                                    _formatReadTime(readByDoctorAt, lang),
                                    style: AppTextStyles.getText3(context).copyWith(
                                      fontSize: 9.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: !widget.isClosed
          ? SafeArea(
        child: showReplyOptions
            ? _buildReplyOptions()
            : _buildSendMessageBar(),
      )
          : null,
    );
  }

  Widget _buildReplyOptions() {
    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 12.h, bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text(
                'إغلاق المحادثة',
                style: AppTextStyles.getText3(context).copyWith(color: Colors.red),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  showReplyOptions = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text(
                'الرد على المحادثة',
                style: AppTextStyles.getText3(context).copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMessageBar() {
    return Padding(
      padding: EdgeInsets.only(left: 8.w, right: 8.w, bottom: 12.h, top: 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp),
              decoration: InputDecoration(
                hintText: 'اكتب ردك هنا...',
                hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
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
    );
  }
}
