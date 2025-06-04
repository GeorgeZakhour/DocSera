import 'dart:io';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/Document/document_info_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'add_image_preview_sheet.dart';

class MultiPageUploadScreen extends StatefulWidget {
  final List<String> images;

  const MultiPageUploadScreen({super.key, required this.images});

  @override
  State<MultiPageUploadScreen> createState() => _MultiPageUploadScreenState();
}

class _MultiPageUploadScreenState extends State<MultiPageUploadScreen> {
  late List<String> _pages;
  final PageController _pageController = PageController(viewportFraction: 0.7);
  int _currentPageIndex = 0;
  bool _showAddOptions = false;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.images);
    _pageController.addListener(() {
      final index = _pageController.page?.round() ?? 0;
      if (_currentPageIndex != index) {
        setState(() {
          _currentPageIndex = index;
        });
      }
    });
  }

  Future<String?> _pickImageFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    return picked.files.first.path;
  }

  void _addPage() {
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
              SizedBox(height: 20.h),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 250),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _showAddOptions
                    ? Container(
                  key: ValueKey('options'),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Row(
                    children: [
                      _buildMiniFabOption(
                        icon: Icons.camera_alt,
                        onPressed: () async {
                          final pickedImage = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (pickedImage != null && pickedImage.files.isNotEmpty) {
                            _handlePickedImage(pickedImage.files.first.path!);
                            setState(() => _showAddOptions = false);
                          }
                        },
                      ),
                      SizedBox(width: 12.w),
                      _buildMiniFabOption(
                        icon: Icons.photo_library,
                        onPressed: () async {
                          final pickedImage = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (pickedImage != null && pickedImage.files.isNotEmpty) {
                            _handlePickedImage(pickedImage.files.first.path!);
                            setState(() => _showAddOptions = false);
                          }
                        },
                      ),
                    ],
                  ),
                )
                    : _buildActionButton(
                  key: ValueKey('add'),
                  icon: Icons.add,
                  label: AppLocalizations.of(context)!.addPage,
                  onTap: () {
                    setState(() => _showAddOptions = true);
                  },
                ),
              ),

              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniFabOption({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: AppColors.main.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.main, size: 20.sp),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _handlePickedImage(String imagePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddImagePreviewSheet(
          imagePath: imagePath,
          onAdd: () {
            Navigator.pop(context);
            setState(() {
              _pages.add(imagePath);
              _currentPageIndex = _pages.length - 1;
            });
            Future.delayed(Duration(milliseconds: 100), () {
              _pageController.animateToPage(
                _currentPageIndex,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
        );
      },
    );
  }


  void _deleteCurrentPage() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_currentPageIndex);
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
    });
    Future.delayed(Duration(milliseconds: 100), () {
      _pageController.animateToPage(
        _currentPageIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showAddOptions) {
            setState(() => _showAddOptions = false);
          }
        },
        child: Column(
          children: [
            // ✅ Top Title
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: isRTL ? Alignment.centerLeft : Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.grayMain),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.addNewDocument,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.mainDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ PageView with image previews
            Expanded(
              flex: 7,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (_, index) {
                  final image = _pages[index];
                  final isSelected = index == _currentPageIndex;

                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: isSelected ? 4.w : 12.w, vertical: isSelected ? 0 : 20.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27.r),
                        border: Border.all(
                          color: isSelected ? AppColors.main : AppColors.main.withOpacity(0.3),
                          width: isSelected ? 4 : 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23.r),
                        child: Image.file(
                          File(image),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 12.h),

            // ✅ Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isSelected = index == _currentPageIndex;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: isSelected ? 12.w : 8.w,
                  height: isSelected ? 12.w : 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.main : AppColors.main.withOpacity(0.5),
                  ),
                );
              }),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  "${AppLocalizations.of(context)!.page} ${_currentPageIndex + 1}/${_pages.length}",
                  style: AppTextStyles.getText2(context),
                  textDirection: TextDirection.ltr, // لضمان عرض الأرقام بشكل صحيح
                ),

              ),
            ),

            // ✅ Controls
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 24.h),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    topRight: Radius.circular(20.r),
                  ),
                ),
                child: Column(
                  children: [
                    // Add/Delete
                    Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: _showAddOptions
                                  ? Container(
                                key: ValueKey('options'),
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  borderRadius: BorderRadius.circular(30.r),
                                  border: Border.all(color: Colors.grey.shade100),

                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildMiniFabOption(
                                      icon: Icons.camera_alt,
                                      onPressed: () async {
                                        final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
                                        if (pickedImage != null) {
                                          _handlePickedImage(pickedImage.path);
                                          setState(() => _showAddOptions = false);
                                        }
                                      },
                                    ),

                                    SizedBox(width: 12.w),
                                    _buildMiniFabOption(
                                      icon: Icons.photo_library,
                                      onPressed: () async {
                                        final pickedImage = await FilePicker.platform.pickFiles(
                                          type: FileType.image,
                                          allowMultiple: false,
                                        );
                                        if (pickedImage != null && pickedImage.files.isNotEmpty) {
                                          _handlePickedImage(pickedImage.files.first.path!);
                                          setState(() => _showAddOptions = false);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              )
                                  : _buildActionButton(
                                key: ValueKey('add'),
                                icon: Icons.add,
                                label: AppLocalizations.of(context)!.addPage,
                                onTap: () {
                                  setState(() => _showAddOptions = true);
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child:_buildActionButton(
                              icon: Icons.delete,
                              label: AppLocalizations.of(context)!.deletePage,
                              onTap: _deleteCurrentPage,
                              enabled: _pages.length > 1,
                            ),

                          ),
                        ),
                      ],
                    ),



                    const Spacer(),

                    // Continue
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentInfoScreen(images: _pages, cameFromMultiPage: true),
                          ),
                        );                    },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.continueText,
                        style: AppTextStyles.getText1(context).copyWith(color: Colors.white),
                      ),
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

  Widget _buildActionButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Column(
      key: key,
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.mainDark : Colors.grey,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: AppTextStyles.getText2(context).copyWith(
            color: enabled ? AppColors.blackText : Colors.grey,
          ),
        ),
      ],
    );
  }
}
