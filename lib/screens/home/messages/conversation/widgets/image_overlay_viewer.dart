import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageOverlayViewer extends StatefulWidget {
  /// All images in this overlay.
  final List<String> imageUrls;

  /// Index to start from.
  final int initialIndex;

  /// Optional preloaded image cache (same structure you already use).
  final Map<String, ImageProvider>? imageCache;

  /// Called when the user taps "Add to Documents" (single or multi).
  /// You receive local file paths; you can then navigate to DocumentInfoScreen.
  final Future<void> Function(List<String> localPaths) onAddToDocuments;

  /// Called when the overlay should be closed.
  final VoidCallback onClose;

  const ImageOverlayViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.imageCache,
    required this.onAddToDocuments,
    required this.onClose,
  });

  @override
  State<ImageOverlayViewer> createState() => _ImageOverlayViewerState();
}

class _ImageOverlayViewerState extends State<ImageOverlayViewer> {
  late int _currentIndex;
  bool _showAsGrid = false;
  bool _showImageDownloadOptions = false;
  bool _isZoomed = false;

  final TransformationController _transformationController =
  TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  bool _isProcessingAddToDocument = false;
  bool _isProcessingSave = false;

  Future<String> _downloadAndGetLocalPath(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image: ${response.statusCode}');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${path.basename(url)}');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Map<String, ImageProvider> get _cache =>
      widget.imageCache ?? <String, ImageProvider>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily ?? 'Cairo',
        decoration: TextDecoration.none,   // يمنع أي خط أصفر أو underlines
        color: Colors.white,               // كل النصوص ستكون بنفس اللون
      ),
      child: Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_showImageDownloadOptions) {
              setState(() => _showImageDownloadOptions = false);
            }
          },
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Close button
                        Align(
                          alignment: lang == 'ar'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24.r),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24.r),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                  onPressed: widget.onClose,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Center text
                        if (!_showAsGrid && !_showImageDownloadOptions)
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              '${_currentIndex + 1} ${local.ofText} ${widget.imageUrls.length}',
                              style: AppTextStyles.getText1(context)
                                  .copyWith(color: Colors.white),
                            ),
                          ),

                        // Right side buttons
                        Align(
                          alignment: lang == 'ar'
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_showAsGrid)
                                _buildSingleImageDownloadControls(context, local),
                              if (!_showAsGrid) SizedBox(width: 6.w),
                              if (!_showAsGrid)
                                _buildGridSwitchButton(),
                              if (_showAsGrid) SizedBox(width: 6.w),
                              if (_showAsGrid)
                                _buildMultiDownloadControls(context, local),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _showAsGrid
                        ? _buildGridView()
                        : _buildPageView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top-right controls in single-image mode
  Widget _buildSingleImageDownloadControls(
      BuildContext context, AppLocalizations local) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _showImageDownloadOptions
          ? Container(
        key: const ValueKey('single-expanded'),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add to documents (single)
            Tooltip(
              message: local.addToDocuments,
              waitDuration: const Duration(milliseconds: 500),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return GestureDetector(
                    onTap: _isProcessingAddToDocument
                        ? null
                        : () {
                      setLocalState(
                              () => _isProcessingAddToDocument = true);

                      Future.delayed(
                          const Duration(milliseconds: 50),
                              () async {
                            try {
                              final url =
                              widget.imageUrls[_currentIndex];
                              final localPath =
                              await _downloadAndGetLocalPath(url);
                              await widget
                                  .onAddToDocuments([localPath]);
                            } finally {
                              if (mounted) {
                                setLocalState(() =>
                                _isProcessingAddToDocument = false);
                              }
                            }
                          });
                    },
                    child: _isProcessingAddToDocument
                        ? SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : SvgPicture.asset(
                      'assets/icons/add2document_white.svg',
                      width: 22.sp,
                      height: 22.sp,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 20.w),
            // Save single
            Tooltip(
              message: local.save,
              waitDuration: const Duration(milliseconds: 500),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return GestureDetector(
                    onTap: _isProcessingSave
                        ? null
                        : () {
                      setLocalState(() => _isProcessingSave = true);

                      Future.delayed(
                          const Duration(milliseconds: 50),
                              () async {
                            try {
                              final url =
                              widget.imageUrls[_currentIndex];
                              await GallerySaver.saveImage(url);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      local.downloadCompleted,
                                    ),
                                    backgroundColor:
                                    AppColors.main.withOpacity(0.9),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content:
                                    Text(local.downloadFailed),
                                    backgroundColor:
                                    AppColors.red.withOpacity(0.9),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setLocalState(
                                        () => _isProcessingSave = false);
                              }
                            }
                          });
                    },
                    child: _isProcessingSave
                        ? SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(
                      Icons.save_alt,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : GestureDetector(
        key: const ValueKey('single-collapsed'),
        onTap: () {
          setState(() => _showImageDownloadOptions = true);
        },
        child: Container(
          padding:
          EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, color: Colors.white, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                local.download,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Button that switches to grid mode
  Widget _buildGridSwitchButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: IconButton(
            icon: Icon(Icons.grid_view, color: Colors.white, size: 16.sp),
            onPressed: () {
              setState(() {
                _showImageDownloadOptions = false;
                _showAsGrid = true;
              });
            },
          ),
        ),
      ),
    );
  }

  /// Top-right controls in grid mode
  Widget _buildMultiDownloadControls(
      BuildContext context, AppLocalizations local) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _showImageDownloadOptions
          ? Container(
        key: const ValueKey('grid-expanded'),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add all to documents
            Tooltip(
              message: local.addToDocuments,
              waitDuration: const Duration(milliseconds: 500),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return GestureDetector(
                    onTap: _isProcessingAddToDocument
                        ? null
                        : () {
                      setLocalState(
                              () => _isProcessingAddToDocument = true);

                      Future.delayed(
                          const Duration(milliseconds: 50),
                              () async {
                            try {
                              final localPaths = <String>[];
                              for (final url in widget.imageUrls) {
                                final p =
                                await _downloadAndGetLocalPath(url);
                                localPaths.add(p);
                              }
                              await widget.onAddToDocuments(localPaths);
                            } finally {
                              if (mounted) {
                                setLocalState(
                                        () => _isProcessingAddToDocument =
                                    false);
                              }
                            }
                          });
                    },
                    child: _isProcessingAddToDocument
                        ? SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : SvgPicture.asset(
                      'assets/icons/add2document_white.svg',
                      width: 22.sp,
                      height: 22.sp,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 20.w),
            // Save all
            Tooltip(
              message: local.save,
              waitDuration: const Duration(milliseconds: 500),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return GestureDetector(
                    onTap: _isProcessingSave
                        ? null
                        : () async {
                      setLocalState(() => _isProcessingSave = true);

                      try {
                        for (final url in widget.imageUrls) {
                          await GallerySaver.saveImage(url);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.imageUrls.length} ${local.imagesDownloadedSuccessfully}',
                              ),
                              backgroundColor:
                              AppColors.main.withOpacity(0.9),
                            ),
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content:
                              Text(local.imagesDownloadFailed),
                              backgroundColor:
                              AppColors.red.withOpacity(0.9),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setLocalState(
                                  () => _isProcessingSave = false);
                          setState(
                                  () => _showImageDownloadOptions =
                              false);
                        }
                      }
                    },
                    child: _isProcessingSave
                        ? SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(
                      Icons.save_alt,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : GestureDetector(
        key: const ValueKey('grid-collapsed'),
        onTap: () {
          setState(() => _showImageDownloadOptions = true);
        },
        child: Container(
          padding:
          EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, color: Colors.white, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                local.downloadAll,
                style: AppTextStyles.getText3(context).copyWith(
                  color: Colors.white,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
      ),
      padding: EdgeInsets.all(16.w),
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        final url = widget.imageUrls[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _showImageDownloadOptions = false;
              _currentIndex = index;
              _showAsGrid = false;
              _transformationController.value = Matrix4.identity();
              _isZoomed = false;
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: _cache.containsKey(url)
                ? Image(image: _cache[url]!, fit: BoxFit.cover)
                : FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: CachedNetworkImageProvider(url),
              fadeInDuration: const Duration(milliseconds: 100),
              fit: BoxFit.cover,
              placeholderFit: BoxFit.cover,
              imageErrorBuilder: (_, __, ___) => const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: PageController(initialPage: _currentIndex),
      physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
      onPageChanged: (index) {
        setState(() {
          _showImageDownloadOptions = false;
          _currentIndex = index;
          _transformationController.value = Matrix4.identity();
          _isZoomed = false;
        });
      },
      itemCount: widget.imageUrls.length,
      itemBuilder: (_, index) {
        final url = widget.imageUrls[index];
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onDoubleTapDown: (details) {
                _doubleTapPosition = details.localPosition;
              },
              onDoubleTap: () {
                final isZoomed =
                    _transformationController.value != Matrix4.identity();
                if (isZoomed) {
                  _transformationController.value = Matrix4.identity();
                } else {
                  final tap = _doubleTapPosition;
                  const scale = 2.5;
                  final x = -tap.dx * (scale - 1);
                  final y = -tap.dy * (scale - 1);

                  _transformationController.value = Matrix4.identity()
                    ..translate(x, y)
                    ..scale(scale);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1,
                maxScale: 4,
                onInteractionUpdate: (details) {
                  final scale =
                  _transformationController.value.getMaxScaleOnAxis();
                  if (mounted) {
                    setState(() {
                      _isZoomed = scale > 1.0;
                    });
                  }
                },
                onInteractionEnd: (details) {
                  final scale =
                  _transformationController.value.getMaxScaleOnAxis();
                  if (mounted) {
                    setState(() {
                      _isZoomed = scale > 1.0;
                    });
                  }
                },
                child: Center(
                  child: _cache.containsKey(url)
                      ? Image(image: _cache[url]!, fit: BoxFit.cover)
                      : FadeInImage(
                    placeholder: MemoryImage(kTransparentImage),
                    image: CachedNetworkImageProvider(url),
                    fadeInDuration: const Duration(milliseconds: 100),
                    fit: BoxFit.cover,
                    placeholderFit: BoxFit.cover,
                    imageErrorBuilder: (_, __, ___) =>
                    const Icon(Icons.error),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
