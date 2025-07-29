import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/notes.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? existingNote;
  final ScrollController scrollController;

  const NoteEditorPage({
    Key? key,
    this.existingNote,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late QuillController _contentController;
  bool _toolbarExpanded = false;
  late FocusNode _contentFocusNode;


  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingNote?.title ?? '');
    _contentFocusNode = FocusNode();
    _contentFocusNode.addListener(() {
      setState(() {});
    });

    _contentController = widget.existingNote != null
        ? QuillController(
      document: Document.fromJson(widget.existingNote!.content),
      selection: const TextSelection.collapsed(offset: 0),
    )
        : QuillController.basic();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.document.toDelta().toJson();

    if (title.isEmpty || _contentController.document.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fillRequiredFields)),
      );
      return;
    }

    if (widget.existingNote == null) {
      context.read<NotesCubit>().addNote(title, content);
    } else {
      context.read<NotesCubit>().updateNote(
        widget.existingNote!.copyWith(title: title, content: content),
      );
    }

    Navigator.pop(context);
  }

  void _maybeExitEditor() {
    final titleEmpty = _titleController.text.trim().isEmpty;
    final contentEmpty = _contentController.document.toPlainText().trim().isEmpty;

    if (titleEmpty && contentEmpty) {
      Navigator.pop(context);
    } else {
      _showExitPopup();
    }
  }


  void _showExitPopup() {
    final locale = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                locale.unsavedNoteTitle,
                style: AppTextStyles.getTitle1(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                locale.unsavedNoteMessage,
                style: AppTextStyles.getText2(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15.h),

              // Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveNote();
                },
                child: Center(
                  child: Text(
                    locale.save,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ),

              // SizedBox(height: 10.h),

              // Cancel Button (outlined style)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  side: BorderSide(color: AppColors.main),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Center(
                  child: Text(
                    locale.cancel,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // SizedBox(height: 10.h),

              // Discard Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pop(); // close modal sheet
                },
                child: Text(
                  locale.discard,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final TextStyle currentStyle = TextStyle(
      fontSize: 13.sp,
      color: Colors.grey[800],
      fontFamily: isArabic ? 'Cairo' : 'Montserrat',
    );




    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent < 0.76 && mounted) {
          final title = _titleController.text.trim();
          final contentText = _contentController.document.toPlainText().trim();
          final contentDelta = _contentController.document.toDelta().toJson();

          final isNew = widget.existingNote == null;
          final isTitleEmpty = title.isEmpty;
          final isContentEmpty = contentText.isEmpty;

          final isSameTitle = widget.existingNote?.title == title;
          final isSameContent = widget.existingNote?.content.toString() == contentDelta.toString();

          final noChange = isSameTitle && isSameContent;

          if ((isNew && isTitleEmpty && isContentEmpty) || (!isNew && noChange)) {
            Future.microtask(() => Navigator.of(context).maybePop());
          } else {
            Future.microtask(() => _showExitPopup());
          }
        }

        return true;
      },

      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: widget.scrollController,
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          top: 10.h,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 100.h, // ✅ يتفاعل مع الكيبورد
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Center(
                                    child: Text(
                                      widget.existingNote == null
                                          ? locale.createNote
                                          : locale.editNote,
                                      style: AppTextStyles.getTitle1(context),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: _maybeExitEditor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 18.h),
                            TextField(
                              controller: _titleController,
                              style: AppTextStyles.getText2(context),
                              decoration: InputDecoration(
                                hintText: locale.noteTitle,
                                border: InputBorder.none,
                              ),
                            ),
                            Divider(height: 20.h, color: AppColors.grayMain.withOpacity(0.5)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppColors.main.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25.r),
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        canvasColor: Colors.white.withOpacity(0.95), // أهم شيء هنا
                                        cardColor: Colors.white.withOpacity(0.95),
                                        dialogBackgroundColor: Colors.white.withOpacity(0.95),
                                      ),
                                      child: QuillSimpleToolbar(
                                        controller: _contentController,
                                        config: QuillSimpleToolbarConfig(
                                          multiRowsDisplay: true,
                                          showFontFamily: false, // not supported via dropdown
                                          showCenterAlignment: _toolbarExpanded,
                                          showFontSize: _toolbarExpanded,
                                          showColorButton: _toolbarExpanded,
                                          showBackgroundColorButton: false,
                                          showCodeBlock: false,
                                          showDirection: false,
                                          showListCheck: false,
                                          showSearchButton: _toolbarExpanded,
                                          showClearFormat: false,
                                          showDividers: false,
                                          showUndo: true,
                                          showRedo: true,
                                          showBoldButton: true,
                                          showItalicButton: true,
                                          showUnderLineButton: true,
                                          showStrikeThrough: false,
                                          showQuote: false,
                                          showInlineCode: false,
                                          showListBullets: _toolbarExpanded,
                                          showListNumbers: _toolbarExpanded,
                                          showIndent: false,
                                          showLink: false,
                                          showAlignmentButtons: false,
                                          showHeaderStyle: false,
                                          showSubscript: false,
                                          showSuperscript: false,
                                          toolbarSize: 20.h,
                                          buttonOptions: QuillSimpleToolbarButtonOptions(
                                            base: QuillToolbarBaseButtonOptions(
                                              iconSize: 11.sp,
                                              iconTheme: QuillIconTheme(
                                                iconButtonUnselectedData: IconButtonData(
                                                  iconSize: 10.sp,
                                                  padding: EdgeInsets.all(2.r),
                                                  constraints: BoxConstraints(
                                                    minWidth: 10.w,
                                                    minHeight: 15.h,
                                                  ),
                                                ),
                                                iconButtonSelectedData: IconButtonData(
                                                  iconSize: 10.sp,
                                                  padding: EdgeInsets.all(2.r),
                                                  constraints: BoxConstraints(
                                                    minWidth: 10.w,
                                                    minHeight: 15.h,
                                                  ),
                                                  style: ButtonStyle(
                                                    backgroundColor: MaterialStateProperty.all(
                                                      AppColors.main.withOpacity(0.5),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _toolbarExpanded ? Icons.arrow_drop_up_sharp : Icons.arrow_drop_down_sharp,
                                        size: 25.sp,
                                        color: _toolbarExpanded ? AppColors.grayMain : AppColors.main,
                                      ),
                                      onPressed: () {
                                        setState(() => _toolbarExpanded = !_toolbarExpanded);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),
                            Container(
                              constraints: BoxConstraints(
                                minHeight: 0.3.sh,
                                maxHeight: 0.45.sh,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: Colors.white,
                                border: Border.all(
                                  color: _contentFocusNode.hasFocus ? AppColors.main : Colors.grey.shade300,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                child: QuillEditor.basic(
                                  controller: _contentController,
                                  focusNode: _contentFocusNode,
                                  config: QuillEditorConfig(
                                    placeholder: AppLocalizations.of(context)!.noteContent,
                                    customStyles: DefaultStyles(
                                      paragraph: DefaultTextBlockStyle(
                                        currentStyle,
                                        const HorizontalSpacing(12, 12),
                                        const VerticalSpacing(6, 6),
                                        const VerticalSpacing(4, 4),
                                        null,
                                      ),
                                      placeHolder: DefaultTextBlockStyle(
                                        TextStyle(
                                          fontSize: 12.sp,
                                          fontFamily: isArabic ? 'Cairo' : 'Montserrat',
                                          color: Colors.grey[400],
                                        ),
                                        const HorizontalSpacing(12, 12),
                                        const VerticalSpacing(6, 6),
                                        const VerticalSpacing(4, 4),
                                        null,
                                      ),
                                    ),
                                  ),
                                ),

                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Button fixed at bottom
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: Text(
                            widget.existingNote == null ? locale.addNote : locale.save,
                            style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

}
