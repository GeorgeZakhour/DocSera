import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/notes.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? existingNote;
  final ScrollController scrollController;

  const NoteEditorPage({
    super.key,
    this.existingNote,
    required this.scrollController,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late QuillController _contentController;
  bool _toolbarExpanded = false;
  late FocusNode _contentFocusNode;

  bool _titleError = false;
  bool _contentError = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentFocusNode = FocusNode();
    _contentFocusNode.addListener(() => setState(() {}));

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
    final locale = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final isContentEmpty =
        _contentController.document.toPlainText().trim().isEmpty;

    setState(() {
      _titleError = title.isEmpty;
      _contentError = isContentEmpty;
    });

    // ✅ إذا واحد من الاثنين ناقص → لا يتم الحفظ
    if (_titleError || _contentError) return;

    final content = _contentController.document.toDelta().toJson();

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
    final contentEmpty =
        _contentController.document.toPlainText().trim().isEmpty;

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
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
              SizedBox(height: 20.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  elevation: 0,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveNote();
                },
                child: Center(
                  child: Text(
                    locale.save,
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  side: const BorderSide(color: AppColors.main),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
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
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: false).pop();
                  Navigator.of(context, rootNavigator: false).pop();
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
      onNotification: (_) => true,
      child: SafeArea(
        bottom: false,
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
                    Expanded(
                      child: SingleChildScrollView(
                        controller: widget.scrollController,
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          top: 10.h,
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom + 100.h,
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
                                  Positioned(
                                    right: 0,
                                    child: TextButton(
                                      onPressed: _saveNote,
                                      child: Text(
                                        locale.save,
                                        style: AppTextStyles.getText2(context)
                                            .copyWith(
                                          color: AppColors.main,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 18.h),
                            // ===== Title Field =====
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  style: AppTextStyles.getText2(context),
                                  decoration: InputDecoration(
                                    hintText: locale.noteTitle,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                      borderSide: BorderSide(
                                        color: _titleError
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                      borderSide: BorderSide(
                                        color: _titleError
                                            ? Colors.red
                                            : AppColors.main,
                                        width: 1.5,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                                if (_titleError)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h, left: 4.w),
                                    child: Text(
                                      locale.fillRequiredFields,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Divider(
                                height: 20.h,
                                color: AppColors.grayMain.withOpacity(0.5)),
                            // ===== Toolbar =====
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.main.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(25.r),
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        canvasColor:
                                            Colors.white.withOpacity(0.95),
                                        cardColor:
                                            Colors.white.withOpacity(0.95), dialogTheme: DialogThemeData(backgroundColor: Colors.white.withOpacity(0.95)),
                                      ),
                                      child: QuillSimpleToolbar(
                                        controller: _contentController,
                                        config: QuillSimpleToolbarConfig(
                                          multiRowsDisplay: true,
                                          showFontFamily: false,
                                          showCenterAlignment:
                                              _toolbarExpanded,
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
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _toolbarExpanded
                                            ? Icons.arrow_drop_up_sharp
                                            : Icons.arrow_drop_down_sharp,
                                        size: 25.sp,
                                        color: _toolbarExpanded
                                            ? AppColors.grayMain
                                            : AppColors.main,
                                      ),
                                      onPressed: () {
                                        setState(() =>
                                            _toolbarExpanded =
                                                !_toolbarExpanded);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),
                            // ===== Content Field =====
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    minHeight: 0.3.sh,
                                    maxHeight: 0.45.sh,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(8.r),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: _contentError
                                          ? Colors.red
                                          : _contentFocusNode.hasFocus
                                              ? AppColors.main
                                              : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.w, vertical: 10.h),
                                    child: QuillEditor.basic(
                                      controller: _contentController,
                                      focusNode: _contentFocusNode,
                                      config: QuillEditorConfig(
                                        placeholder:
                                            AppLocalizations.of(context)!
                                                .noteContent,
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
                                              fontFamily: isArabic
                                                  ? 'Cairo'
                                                  : 'Montserrat',
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
                                if (_contentError)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h, left: 4.w),
                                    child: Text(
                                      locale.fillRequiredFields,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
