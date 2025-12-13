import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AttachmentsBubble extends StatelessWidget {
  final List<String> urls;
  final bool isUser;
  final DateTime? time;
  final VoidCallback onOpenGrid;
  final Function(int index) onOpenImage;

  const AttachmentsBubble({
    Key? key,
    required this.urls,
    required this.isUser,
    required this.time,
    required this.onOpenGrid,
    required this.onOpenImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final count = urls.length;

    return Column(
      crossAxisAlignment:
      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            constraints: BoxConstraints(maxWidth: 0.55.sw),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: count > 4 ? 4 : count,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count == 1 ? 1 : 2,
                crossAxisSpacing: 6.w,
                mainAxisSpacing: 6.h,
              ),
              itemBuilder: (_, i) {
                if (i == 3 && count > 4) {
                  return GestureDetector(
                    onTap: onOpenGrid,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: Text(
                          "+${count - 3}",
                          style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.main,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => onOpenImage(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: CachedNetworkImage(
                      imageUrl: urls[i],
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.shade200),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            time == null ? "" : "${time!.hour}:${time!.minute.toString().padLeft(2, "0")}",
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 9.sp,
              color: Colors.black54,
            ),
          ),
        )
      ],
    );
  }
}
