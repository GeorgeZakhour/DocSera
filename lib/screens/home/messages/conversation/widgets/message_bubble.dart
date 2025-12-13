import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/chat_name_utils.dart';

class MessageBubble extends StatelessWidget {
  final String senderName;
  final String text;
  final bool isUser;
  final DateTime? time;
  final bool showSender;
  final bool isArabic;

  const MessageBubble({
    Key? key,
    required this.senderName,
    required this.text,
    required this.isUser,
    required this.time,
    required this.showSender,
    required this.isArabic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final alignment =
    isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
          child: Container(
            constraints: BoxConstraints(maxWidth: 0.65.sw),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            margin: EdgeInsets.symmetric(vertical: 4.h),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.mainDark.withOpacity(0.9)
                  : AppColors.grayMain.withOpacity(0.18),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
                bottomLeft: isUser ? Radius.circular(12.r) : Radius.zero,
                bottomRight: isUser ? Radius.zero : Radius.circular(12.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      senderName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                Directionality(
                  textDirection:
                  isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    text,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    time == null
                        ? ""
                        : ChatNameUtils.formatReadTime(time!, "ar"),
                    style: AppTextStyles.getText3(context).copyWith(
                      fontSize: 9.sp,
                      color: isUser ? Colors.white70 : Colors.black54,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
