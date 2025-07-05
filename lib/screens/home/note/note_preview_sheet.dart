import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/notes.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'note_editor_page.dart';

class NotePreviewSheet extends StatelessWidget {
  final Note note;
  final ScrollController scrollController;

  const NotePreviewSheet({
    Key? key,
    required this.note,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = QuillController(
      document: Document.fromJson(note.content),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true, // ✅ هنا صارت الخاصية المطلوبة
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // ✅ ترويسة العنوان مع زر X يميناً و Edit يساراً
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.main, size: 18.sp,),
                  onPressed: () {
                    Navigator.pop(context); // أول شي أغلق الـ preview

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: false,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.75,
                        maxChildSize: 0.9,
                        expand: false,
                        builder: (context, scrollController) => NoteEditorPage(
                          scrollController: scrollController,
                          existingNote: note, // ⬅️ هذا المهم!
                        ),
                      ),
                    );
                  },

                ),

                Expanded(
                  child: Center(
                    child: Text(
                      note.title,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 15.sp),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),

              ],
            ),
          ),
          SizedBox(height: 12.h),

          // ✅ المحتوى مع الخطوط
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LinedPaperPainter(
                      lineHeight: 26.h,
                      lineColor: Colors.grey.withOpacity(0.2),
                      startFrom: 40.h,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16.h, left: 16.w, right: 16.w),
                  child: QuillEditor(
                    controller: controller,
                    scrollController: scrollController,
                    focusNode: FocusNode(),
                    config: QuillEditorConfig(
                      autoFocus: false,
                      expands: true,
                      padding: EdgeInsets.zero,
                      placeholder: '',
                      showCursor: false, // ✅ يمنع ظهور المؤشر
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: 13.sp,
                            height: 1.65,
                            fontFamily: Localizations.localeOf(context).languageCode == 'ar'
                                ? 'Cairo'
                                : 'Montserrat',
                            color: Colors.black87,
                          ),
                          HorizontalSpacing(0, 0),
                          VerticalSpacing(0, 0),
                          VerticalSpacing(0, 0),
                          null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _LinedPaperPainter extends CustomPainter {
  final double lineHeight;
  final Color lineColor;
  final double startFrom;

  _LinedPaperPainter({
    required this.lineHeight,
    required this.lineColor,
    this.startFrom = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor;
    for (double y = startFrom; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
