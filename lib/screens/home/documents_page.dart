import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_state.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/notes.dart';
import 'package:docsera/screens/home/Document/document_options_bottom_sheet.dart';
import 'package:docsera/screens/home/Document/document_preview_page.dart';
import 'package:docsera/screens/home/Document/multi_page_upload_screen.dart';
import 'package:docsera/screens/home/note/note_editor_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';
import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/screens/auth/identification_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Document/add_image_preview_sheet.dart';
import 'Document/document_info_screen.dart';
import 'note/note_preview_sheet.dart';
import 'package:path/path.dart' as path;


extension WidgetKeyExtension on Widget {
  Widget withKey(Key key) => KeyedSubtree(key: key, child: this);
}


class DocumentsPage extends StatefulWidget {
  const DocumentsPage({Key? key}) : super(key: key);

  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;






  int? _selectedTab; // ✅ Nullable until loaded
  bool _isLoading = true; // ✅ Prevents flickering
  bool _isGridView = true;
  bool _isNotesGridView = true;
  static const String _viewModeKey = 'documentViewMode'; // 0 = grid, 1 = list
  static const String _notesViewModeKey = 'notesViewMode'; // 0 = grid, 1 = list
  bool _isFabExpanded = false;



  @override
  void initState() {
    super.initState();

    _loadInitialPreferences(); // ✅ الجديدة بدلاً من القديمة
    context.read<DocumentsCubit>().listenToDocuments(context);
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // re-listen if needed
    context.read<DocumentsCubit>().listenToDocuments(context);
  }


  void _loadInitialPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int lastTab = prefs.getInt('selectedDocumentsTab') ?? 0;
    bool isGrid = (prefs.getInt(_viewModeKey) ?? 1) == 0;
    bool isNotesGrid = (prefs.getInt(_notesViewModeKey) ?? 1) == 0;


    setState(() {
      _selectedTab = lastTab;
      _isGridView = isGrid;
      _isNotesGridView = isNotesGrid;
      _isLoading = false;
    });
  }

  Future<void> _saveViewMode(bool isGrid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_viewModeKey, isGrid ? 0 : 1);
  }

  Future<void> _saveNotesViewMode(bool isGrid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notesViewModeKey, isGrid ? 0 : 1);
  }

  /// ✅ **Save last selected tab**
  Future<void> _saveLastSelectedTab(int tabIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDocumentsTab', tabIndex);
  }

  void _pickAndUploadFile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.chooseAddDocumentMethod,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.grayMain),
              ),
              SizedBox(height: 10.h),
              Divider(height: 1.h, color: Colors.grey[200],),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconAction(
                    iconPath: 'assets/icons/camera.svg',
                    label: AppLocalizations.of(context)!.takePhoto,
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (pickedImage != null) {
                        _handleImagePicked(pickedImage.path);
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/gallery.svg',
                    label: AppLocalizations.of(context)!.chooseFromLibrary,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        _handleImagePicked(result.files.first.path!);
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/file.svg',
                    label: AppLocalizations.of(context)!.chooseFile,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        _handlePdfPicked(result.files.first.path!);
                      }
                    },
                  ),

                ],
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconAction({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.main.withOpacity(0.1),
            ),
            child: Center(
              child: SvgPicture.asset(
                iconPath,
                width: 22.w,
                height: 22.w,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(label, style: AppTextStyles.getText3(context)),
        ],
      ),
    );
  }

  Widget _buildSvgMiniFab({
    required String svgPath,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 7.w),
      child: Container(
        width: 44.w,
        height: 44.w,
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: AppColors.main.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: SvgPicture.asset(
            svgPath,
            width: 20.w,
            height: 20.w,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

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
  Widget build(BuildContext context) {
    super.build(context);
    final notesState = context.watch<NotesCubit>().state;
    final hasNotes = notesState is NotesLoaded && notesState.notes.isNotEmpty;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t.health_documents_title,
          style: AppTextStyles.getTitle1(context).copyWith(
            color: Colors.white,
            fontSize: 12.sp,
          ),
        ),
      ),
      body: BlocBuilder<DocumentsCubit, DocumentsState>(
        builder: (context, state) {
          final isLoggedIn = state is DocumentsLoaded;
          final hasDocuments = state is DocumentsLoaded && state.documents.isNotEmpty;

          return Stack(
            children: [
              // ✅ المحتوى الرئيسي
              Column(
                children: [
                  Container(
                    color: AppColors.main,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTabButton(AppLocalizations.of(context)!.documents, 0),
                        _buildTabButton(AppLocalizations.of(context)!.notes, 1),
                      ],
                    ),
                  ),
                  Expanded(
                    child: BlocBuilder<DocumentsCubit, DocumentsState>(
                      builder: (context, state) {
                        if (_isLoading) return SizedBox();
                        if (state is DocumentsLoading) return _buildShimmerLoading();
                        if (state is DocumentsNotLogged) return _buildLoginPrompt();
                        if (state is DocumentsError) return Center(child: Text(state.message));
                        if (state is DocumentsLoaded) {
                          final documents = state.documents.where((e) => e.previewUrl.isNotEmpty).toList();
                          return _buildDocumentsContent(documents);
                        }
                        return const Center(child: Text("Unexpected error"));
                      },
                    ),
                  ),
                ],
              ),

              // ✅ FABs حسب التبويب
              if ((_selectedTab == 0 && isLoggedIn && hasDocuments) ||
                  (_selectedTab == 1 && hasNotes))
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.w, bottom: 16.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedTab == 0) ...[
                          FutureBuilder(
                            future: Future.delayed(Duration(milliseconds: 0)),
                            builder: (_, snapshot) {
                              return AnimatedSlide(
                                offset: _isFabExpanded ? Offset.zero : Offset(0, 0.2),
                                duration: const Duration(milliseconds: 300),
                                child: AnimatedOpacity(
                                  opacity: _isFabExpanded ? 1 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Visibility(
                                    visible: _isFabExpanded,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: true,
                                    child: _buildSvgMiniFab(
                                      svgPath: 'assets/icons/camera.svg',
                                      onPressed: () async {
                                        final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
                                        if (pickedImage != null) _handleImagePicked(pickedImage.path);
                                        setState(() => _isFabExpanded = false);
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          FutureBuilder(
                            future: Future.delayed(Duration(milliseconds: 100)),
                            builder: (_, snapshot) {
                              return AnimatedSlide(
                                offset: _isFabExpanded ? Offset.zero : Offset(0, 0.2),
                                duration: const Duration(milliseconds: 300),
                                child: AnimatedOpacity(
                                  opacity: _isFabExpanded ? 1 : 0,
                                  duration: const Duration(milliseconds: 100),
                                  child: Visibility(
                                    visible: _isFabExpanded,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: true,
                                    child: _buildSvgMiniFab(
                                      svgPath: 'assets/icons/gallery.svg',
                                      onPressed: () async {
                                        final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                        if (result != null && result.files.isNotEmpty) {
                                          _handleImagePicked(result.files.first.path!);
                                        }
                                        setState(() => _isFabExpanded = false);
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          FutureBuilder(
                            future: Future.delayed(Duration(milliseconds: 150)),
                            builder: (_, snapshot) {
                              return AnimatedSlide(
                                offset: _isFabExpanded ? Offset.zero : Offset(0, 0.2),
                                duration: const Duration(milliseconds: 300),
                                child: AnimatedOpacity(
                                  opacity: _isFabExpanded ? 1 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Visibility(
                                    visible: _isFabExpanded,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: true,
                                    child: _buildSvgMiniFab(
                                      svgPath: 'assets/icons/file.svg',
                                      onPressed: () async {
                                        final result = await FilePicker.platform.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['pdf'],
                                        );
                                        if (result != null && result.files.isNotEmpty) {
                                          _handlePdfPicked(result.files.first.path!);
                                        }
                                        setState(() => _isFabExpanded = false);
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),




                        ],

                        // ✅ FAB الرئيسي
                        FloatingActionButton(
                          heroTag: 'mainFab',
                          onPressed: () {
                            if (_selectedTab == 0) {
                              setState(() => _isFabExpanded = !_isFabExpanded);
                            } else {
                              // تبويب الملاحظات: افتح مباشرة صفحة إنشاء ملاحظة
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                isDismissible: false,
                                enableDrag: false,
                                backgroundColor: Colors.transparent,
                                builder: (context) => DraggableScrollableSheet(
                                  initialChildSize: 0.9,
                                  minChildSize: 0.9,
                                  maxChildSize: 0.9,
                                  expand: false,
                                  builder: (context, scrollController) => NoteEditorPage(
                                    scrollController: scrollController,
                                  ),
                                ),
                              );
                            }
                          },
                          elevation: 0,
                          backgroundColor: AppColors.main,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 300),
                            turns: _isFabExpanded && _selectedTab == 0 ? 0.125 : 0,
                            child: Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildShimmerLoading() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 25.h, left: 16.w ,right: 16.w),
      child: _isGridView
          ? _buildGridShimmer()
          : _buildListShimmer(),
    );
  }

  Widget _buildGridShimmer() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ShimmerWidget(
              width: 60.w,
              height: 30.h,
              radius: 25.r
          ),
        ),

        SizedBox(height: 25.h,),
        // ✅ العناصر تحتها
        Expanded(
          child: GridView.builder(
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, __) {
              return Column(
                children: [
                  ShimmerWidget(width: double.infinity, height: 130.h, radius: 12.r),
                  SizedBox(height: 8.h),
                  ShimmerWidget(width: 100.w, height: 12.h, radius: 8.r),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListShimmer() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ShimmerWidget(
              width: 60.w,
              height: 30.h,
              radius: 25.r
          ),
        ),

        SizedBox(height: 25.h,),
        // ✅ العناصر تحتها
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
            itemCount: 8,
            separatorBuilder: (_, __) => SizedBox(height: 25.h),
            itemBuilder: (_, __) {
              return Row(
                children: [
                  ShimmerWidget(width: 50.w, height: 50.h, radius: 8.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerWidget(width: double.infinity, height: 12.h, radius: 8.r),
                        SizedBox(height: 12.h),
                        ShimmerWidget(width: double.infinity, height: 12.h, radius: 8.r),
                      ],
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }


  /// ✅ **Login Prompt UI**
  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/documents.png", width: 100, height: 100),
            SizedBox(height: 20.h),
            Text(AppLocalizations.of(context)!.manageDocuments,
                style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark)),
            SizedBox(height: 8.h),
            Text(
              AppLocalizations.of(context)!.manageDocumentsDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, fadePageRoute(const IdentificationPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
              ),
              child: Text(
                AppLocalizations.of(context)!.logInCapital,
                style: AppTextStyles.getText1(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ **Documents Content UI**
  Widget _buildDocumentsContent(List<UserDocument> documents) {
    final hasDocuments = documents.isNotEmpty;
    final notesState = context.watch<NotesCubit>().state;
    final hasNotes = notesState is NotesLoaded && notesState.notes.isNotEmpty;

    return Stack(
      children: [
        /// ✅ المحتوى (يمرّ خلف السويتشر)
        _selectedTab == 0
            ? _buildDocumentsTab(documents)
            : _buildNotesTab(),

        /// ✅ سويتشر الوثائق أو الملاحظات
        if ((_selectedTab == 0 && hasDocuments) ||
            (_selectedTab == 1 && hasNotes))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Align(
                alignment: Directionality.of(context) == TextDirection.RTL
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: _selectedTab == 0
                    ? Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildViewModeButton(Icons.grid_view, true),
                      SizedBox(width: 4.w),
                      _buildViewModeButton(Icons.view_list, false),
                    ],
                  ),
                )
                    : _buildNotesViewModeSwitcher(),
              ),
            ),
          ),
      ],
    );
  }



  Widget _buildViewModeButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _isGridView = isGrid;
        });
        _saveViewMode(isGrid);
      },

      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.main.withOpacity(0.7) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.grayMain,
          size: 15.sp,
        ),
      ),
    );
  }


  Widget _buildNotesViewModeSwitcher() {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNoteViewButton(Icons.grid_view, true),
          SizedBox(width: 4.w),
          _buildNoteViewButton(Icons.view_list, false),
        ],
      ),
    );
  }

  Widget _buildNoteViewButton(IconData icon, bool isGrid) {
    final isSelected = _isNotesGridView == isGrid;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _isNotesGridView = isGrid;
        });
        _saveNotesViewMode(isGrid);
      },
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.main.withOpacity(0.7) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.grayMain,
          size: 15.sp,
        ),
      ),
    );
  }

  /// ✅ **Tab Buttons**
  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
          _saveLastSelectedTab(index);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                title,
                style: AppTextStyles.getTitle1(context).copyWith(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                ),
              ),
              SizedBox(height: 4.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 60.w : 0,
                height: isSelected ? 3.h : 0,
                color: isSelected ? Colors.white : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ **Documents Tab**
  /// ✅ استبدال documents.isEmpty بـ documentList.isEmpty
  Widget _buildDocumentsTab(List<UserDocument> documents) {
    final displayDocs = documents
        .where((e) => e.previewUrl.isNotEmpty)
        .map((e) => {
      'name': e.name,
      'type': e.type,
      'previewUrl': e.previewUrl,
      'url': e.previewUrl,
      'pages': e.pages,
      'doc': e,
    })
        .toList();

    if (displayDocs.isEmpty) {
      return _buildEmptyState(
        AppLocalizations.of(context)!.manageDocuments,
        AppLocalizations.of(context)!.manageDocumentsDescription,
        "assets/images/documents.png",
        AppLocalizations.of(context)!.addDocument,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _isGridView
            ? _buildGridView(displayDocs).withKey(const ValueKey('grid'))
            : _buildListView(displayDocs).withKey(const ValueKey('list')),
      ),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> displayDocs) {
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // ✅ البانر كعنصر منفصل في الأعلى
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildDocumentsBannerCard(),
          ),
        ),

        // ✅ الشبكة الحقيقية
        SliverPadding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w,bottom: 70.h),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final doc = displayDocs[index];
                return _buildDocumentCard(doc);
              },
              childCount: displayDocs.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> displayDocs) {
    final groupedDocs = _groupDocumentsByYear(displayDocs);
    final isRTL = Directionality.of(context) == TextDirection.RTL;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ✅ البانر
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildDocumentsBannerCard(),
          ),
        ),

        // ✅ المستندات حسب السنوات
        ...groupedDocs.entries.map((entry) {
          final year = entry.key;
          final docs = entry.value;

          return SliverPadding(
            padding: EdgeInsets.only(bottom: 70.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ✅ عنوان السنة
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                  child: Row(
                    children: [
                      Text(
                        year.toString(),
                        style: AppTextStyles.getTitle1(context).copyWith(
                          color: AppColors.grayMain,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      const Expanded(
                        child: Divider(
                          color: AppColors.grayMain,
                          thickness: 1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ العناصر داخل السنة
                ...docs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final UserDocument userDoc = doc['doc'];
                  final appLocale = AppLocalizations.of(context)!;
                  final String subtitle = _documentTypeMap[userDoc.type]?.call(appLocale) ?? userDoc.type;

                  return Dismissible(
                    key: ValueKey(userDoc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        child: Container(
                          color: AppColors.red.withOpacity(0.7),
                          alignment: Alignment.center,
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.deleteTheDocument,
                                  style: AppTextStyles.getTitle2(context),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  AppLocalizations.of(context)!.areYouSureToDelete(userDoc.name),
                                  style: AppTextStyles.getText2(context),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context, true);
                                  },
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!.delete,
                                      style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
                                    style: AppTextStyles.getText2(context).copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.blackText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    onDismissed: (_) {
                      context.read<DocumentsCubit>().deleteDocument(context, userDoc);
                    },
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _openDocument(doc),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/pdf-file.svg',
                                      width: 24.sp,
                                      height: 24.sp,
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      '${userDoc.pages.length} '
                                          '${userDoc.pages.length == 1
                                          ? AppLocalizations.of(context)!.pageSingular
                                          : AppLocalizations.of(context)!.pagePlural}',
                                      style: AppTextStyles.getText3(context).copyWith(
                                        color: AppColors.grayMain,
                                        fontSize: 6.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userDoc.name,
                                        style: AppTextStyles.getText2(context),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        subtitle,
                                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.more_horiz, size: 20.sp),
                                  onPressed: () => _showEditOptions(doc),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (index != docs.length - 1)
                          Divider(color: Colors.grey.shade300, height: 1),
                      ],
                    ),
                  );
                }).toList(),
              ]),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDocumentsBannerCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.main.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/document_banner.png',
              width: 45.w,
              height: 45.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.documentAccessInfo,
                style: AppTextStyles.getText3(context).copyWith(color: AppColors.blackText),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesBannerCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.main.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/notes_banner.png', // 🖼️ صورة مختلفة للملاحظات
              width: 45.w,
              height: 45.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.notesAccessInfo, // 📝 نص مختلف من ARB
                style: AppTextStyles.getText3(context).copyWith(color: AppColors.blackText),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<int, List<Map<String, dynamic>>> _groupDocumentsByYear(List<Map<String, dynamic>> docs) {
    final Map<int, List<Map<String, dynamic>>> grouped = {};

    for (var doc in docs) {
      final UserDocument userDoc = doc['doc'];
      final int year = userDoc.uploadedAt.year;

      if (!grouped.containsKey(year)) {
        grouped[year] = [];
      }
      grouped[year]!.add(doc);
    }

    // ترتيب السنوات تنازلياً (الأحدث أولاً)
    final sorted = Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));

    return sorted;
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    return InkWell(
      onTap: () => _openDocument(doc),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r)),
                child: (doc['pages'] != null && doc['pages'].isNotEmpty)
                    ? Image.network(
                  doc['previewUrl'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image, size: 48.sp, color: Colors.grey),
                  ),
                )

                    : Center(
                  child: Icon(Icons.broken_image, size: 48.sp, color: Colors.grey),
                ),




              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        doc['name'],
                        style: AppTextStyles.getText2(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, size: 20.sp),
                      onPressed: () => _showEditOptions(doc),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocument(Map<String, dynamic> doc) {
    final UserDocument userDoc = doc['doc'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewPage(document: userDoc),
      ),
    );
  }

  void _showEditOptions(Map<String, dynamic> doc) {
    final UserDocument userDoc = doc['doc'];
    showDocumentOptionsSheet(context, userDoc);
  }

  void _handleImagePicked(String imagePath) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddImagePreviewSheet(
          imagePath: imagePath,
          onAdd: () {
            Navigator.pop(context); // نغلق الشيت
            _goToMultiImageUploadFlow(imagePath); // ننتقل للمرحلة التالية
          },
        );
      },
    );
  }

  void _goToMultiImageUploadFlow(String firstImagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiPageUploadScreen(images: [firstImagePath]),
      ),
    );
  }

  Future<int> getPdfPageCount(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final count = document.pages.count;
    document.dispose(); // لتفريغ الذاكرة
    return count;
  }

  void _handlePdfPicked(String pdfPath) async {
    final fileName = path.basenameWithoutExtension(pdfPath);
    final pageCount = await getPdfPageCount(pdfPath);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentInfoScreen(
          images: [pdfPath],
          initialName: fileName,
          pageCount: pageCount, // تأكد من إضافته في الشاشة واستقبال القيمة
        ),
      ),
    );
  }

  /// ✅ **Notes Tab**
  Widget _buildNotesTab() {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        if (state is NotesLoading) return _buildShimmerLoading();
        if (state is NotesNotLogged) return _buildLoginPrompt();
        if (state is NotesError) {
          return Center(child: Text(state.message));
        }
        if (state is NotesLoaded) {
          final notes = state.notes;
          if (notes.isEmpty) {
            return _buildEmptyState(
              AppLocalizations.of(context)!.takeNotesTitle,
              AppLocalizations.of(context)!.takeNotesDescription,
              "assets/images/notes.png",
              AppLocalizations.of(context)!.createNote,
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _isNotesGridView
                  ? _buildNotesGridView(notes).withKey(const ValueKey('notesGrid'))
                  : _buildNotesListView(notes).withKey(const ValueKey('notesList')),

            ),
          );
        }
        return const Center(child: Text("Unexpected error"));
      },
    );
  }

  Widget _buildNotesGridView(List<Note> notes) {
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // ✅ البانر
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildNotesBannerCard(), // تأكد من أن هذه الدالة موجودة
          ),
        ),

        // ✅ شبكة الملاحظات
        SliverPadding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 70.h),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final note = notes[index];
                return _buildNoteCard(note);
              },
              childCount: notes.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesListView(List<Note> notes) {
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // ✅ البانر
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildNotesBannerCard(), // تأكد من أن هذه الدالة موجودة
          ),
        ),

        // ✅ قائمة الملاحظات
        SliverPadding(
          padding: EdgeInsets.only(bottom: 70.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final note = notes[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: _buildNoteListTile(note),
                );
              },
              childCount: notes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteListTile(Note note) {
    final isArabic = Directionality.of(context) == TextDirection.RTL;

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          enableDrag: false,
          isDismissible: false,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => NotePreviewSheet(
              note: note,
              scrollController: scrollController,
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes, color: AppColors.mainDark.withOpacity(0.5), size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: AppTextStyles.getText2(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    Document.fromJson(note.content).toPlainText().trim(),
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              height: 30.h,
              child: VerticalDivider(color: Colors.grey.shade300, thickness: 1),
            ),
            SizedBox(width: 6.w),
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.grayMain.withOpacity(0.1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18.sp, color: AppColors.grayMain),
                onPressed: () => _showNoteOptionsSheet(note),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final isArabic = Directionality.of(context) == TextDirection.RTL;

    return Stack(
      children: [
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              enableDrag: false,
              isDismissible: false,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.9,
                maxChildSize: 0.9,
                minChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) => NotePreviewSheet(
                  note: note,
                  scrollController: scrollController,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  child: Text(
                    note.title,
                    style: AppTextStyles.getTitle1(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 4.h),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: List.generate(
                          5,
                              (_) => Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        child: Text(
                          Document.fromJson(note.content).toPlainText().trim(),
                          style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),

        // ✅ زر الخيارات "..."
        Positioned(
          top: 12.h,
          right: isArabic ? 6.w : null,
          left: isArabic ? null : 6.w,
          child: GestureDetector(
            onTap: () => _showNoteOptionsSheet(note),
            child: Icon(Icons.more_vert, size: 24.sp, color: AppColors.grayMain),
          ),
        ),
      ],
    );
  }


  void _showNoteOptionsSheet(Note note) {
    final locale = Localizations.localeOf(context).languageCode;
    final formattedDate = DateFormat('d MMM yyyy', locale).format(note.createdAt);
    final createdByText = AppLocalizations.of(context)!.createdByYou(formattedDate);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.notes, color: AppColors.grayMain, size: 30.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4.h),
                        Text(
                          createdByText,
                          style: AppTextStyles.getText3(context).copyWith(color: AppColors.grayMain),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 10.h, color: Colors.grey[300]),

              _buildOption(context, Icons.visibility_outlined, AppLocalizations.of(context)!.show, onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  enableDrag: false,
                  isDismissible: false,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.9,
                    maxChildSize: 0.9,
                    minChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) => NotePreviewSheet(
                      note: note,
                      scrollController: scrollController,
                    ),
                  ),
                );
              }),

              _buildOption(context, Icons.edit_outlined, AppLocalizations.of(context)!.edit, onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  enableDrag: true,
                  isDismissible: false,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.9,
                    maxChildSize: 0.9,
                    minChildSize: 0.75,
                    expand: false,
                    builder: (context, scrollController) => NoteEditorPage(
                      scrollController: scrollController,
                      existingNote: note,
                    ),
                  ),
                );
              }),

              _buildOption(context, Icons.delete_outline, AppLocalizations.of(context)!.delete, isRed: true, onTap: () {
                Navigator.pop(context);
                _confirmDeleteNote(note);
              }),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(BuildContext context, IconData icon, String title,
      {required VoidCallback onTap, bool isRed = false}) {
    return Column(
      children: [
        ListTile(
          dense: true,
          minVerticalPadding: 0,
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: 8.w, // 👈 هذا بيقلل المسافة بين الأيقونة والنص
          leading: Icon(icon, color: isRed ? AppColors.red : AppColors.main, size: 18.sp),
          title: Text(
            title,
            style: AppTextStyles.getText3(context).copyWith(color: isRed ? AppColors.red : AppColors.main, fontWeight: FontWeight.bold),
          ),
          onTap: onTap,
        ),
        Divider(height: 1.h, color: Colors.grey[300]),
      ],
    );
  }

  void _confirmDeleteNote(Note note) {
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
                AppLocalizations.of(context)!.deleteTheNote,
                style: AppTextStyles.getTitle2(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                AppLocalizations.of(context)!.areYouSureToDelete(note.title),
                style: AppTextStyles.getText2(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: () {
                  context.read<NotesCubit>().deleteNote(note);
                  Navigator.pop(context);
                },
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.delete,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold, color: AppColors.blackText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  /// ✅ **Empty State for Tabs**
  Widget _buildEmptyState(String title, String description, String imagePath, String buttonText) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 100.w, height: 100.h),
            SizedBox(height: 20.h),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.grayMain)),
            SizedBox(height: 8.h),
            Text(description,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.black54)),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _selectedTab == 0
                  ? _pickAndUploadFile
                  : () {
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
                    ),
                  ),
                );

              },

              icon: Icon(Icons.add, color: Colors.white, size: 18.sp),
              label: Text(
                buttonText,
                style: AppTextStyles.getText1(context).copyWith(color: AppColors.whiteText),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 12.h),
              ),
            ),

          ],
        ),
      ),
    );
  }
}


