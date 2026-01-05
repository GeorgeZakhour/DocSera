import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:docsera/app/const.dart';

class MessageSkeleton extends StatelessWidget {
  final bool isUser;

  const MessageSkeleton({super.key, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: 0.6.sw,
            height: 60.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
                bottomLeft: isUser ? Radius.circular(12.r) : Radius.zero,
                bottomRight: isUser ? Radius.zero : Radius.circular(12.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
