import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/text_styles.dart';
import 'dart:async';
import 'package:docsera/screens/search_advanced_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:docsera/models/banner_model.dart'; // ✅ Import BannerModel
import 'package:docsera/screens/home/banners/banner_details_page.dart'; // ✅ Import BannerDetailsPage


/// **🔹 Top Section (Now Correctly Positioned with Search Bar)**
class TopSection extends StatelessWidget {
  const TopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      clipBehavior: Clip.none, // Allows elements to overflow
      children: [
        // ✅ Green Background with Shapes
        ClipPath(
          clipper: CustomTopBarClipper(),
          child: Container(
            height: screenHeight * 0.3,
            color: AppColors.main,
            child: Stack(
              children: [
                // ✅ Background Shapes
                Positioned(
                  top: 20,
                  left: 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 60,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 80,
                  left: 120,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: ClipPath(
                      clipper: OrganicCircleClipper(),
                      child: Container(
                        width: 100,
                        height: 120,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 150,
                  right: -70,
                  child: Transform.rotate(
                    angle: -0.9,
                    child: ClipPath(
                      clipper: OrganicCircleClipper(),
                      child: Container(
                        width: 200,
                        height: 150,
                        color: AppColors.mainDark.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  left: -60,
                  child: Transform.rotate(
                    angle: -0.1,
                    child: ClipPath(
                      clipper: OrganicCircleClipper(),
                      child: Container(
                        width: 120,
                        height: 200,
                        color: AppColors.whiteText.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ✅ Centered Text Over Shapes
        Positioned(
          top: screenHeight * 0.06,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context)!.yourDoctor,
                style: AppTextStyles.getTitle2(context).copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.anytime,
                style: AppTextStyles.getTitle4(context).copyWith(
                  color: AppColors.orangeText,
                  fontWeight: FontWeight.w800
                ),
              ),
            ],
          ),
        ),


        // ✅ Search Bar Positioned Closer to Text
        Positioned(
          top: screenHeight * 0.17, // Adjusted to be higher
          left: (screenWidth - 150) / 2, // Centered
          child: const SearchBarSection(),
        ),
      ],
    );
  }
}

/// **🔹 Search Bar Section (Updated for Navigation)**
class SearchBarSection extends StatelessWidget {
  const SearchBarSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            const SearchAdvancedPage(mode: "search"),
          ),
        );
      },
      child: Container(
        height: 40,
        width: 150,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.whiteText,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: AppColors.main, size: 18.sp),
            const SizedBox(width: 5),
            Text(
              AppLocalizations.of(context)!.search,
              style: AppTextStyles.getText2(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 كاش للألوان المستخرجة لتجنب إعادة حسابها كل مرة
/// **🔹 Global cache for storing banner colors**
class BannerColorCache {
  static final Map<String, Color> _cache = {};

  /// **🔹 Seed cache for testing**
  static void seedCache(Map<String, Color> values) {
    _cache.addAll(values);
  }

  /// **🔹 Get color from cache or extract if not available**
  static Future<Color> getColor(String imagePath) async {

    if (_cache.containsKey(imagePath)) {
      return _cache[imagePath]!; // ✅ Return cached color instantly
    }

    try {
      final ImageProvider imageProvider;
      if (imagePath.startsWith('http')) {
        imageProvider = NetworkImage(imagePath);
      } else {
        imageProvider = AssetImage(imagePath);
      }

      final PaletteGenerator paletteGenerator =
      await PaletteGenerator.fromImageProvider(
        ResizeImage(imageProvider, width: 100), // ✅ MEMORY FIX: Downsample for palette
      );

      Color extractedColor = paletteGenerator.dominantColor?.color ?? Colors.teal.shade50;
      Color adjustedColor = _adjustColor(extractedColor);

      _cache[imagePath] = adjustedColor; // ✅ Save color for future use
      return adjustedColor;
    } catch (e) {
      return Colors.blue.shade100;
    }
  }

  /// **🔹 Adjust extracted color: Reduce saturation & increase lightness**
  static Color _adjustColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    
    // 1. Reduce Saturation (Make it less vibrant)
    final desaturated = hsl.withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0));

    // 2. Increase Lightness (Make it much lighter/pastel)
    // We want the lightness to be high, so we push it towards 0.95
    final lightened = desaturated.withLightness((desaturated.lightness + (1.0 - desaturated.lightness) * 0.85).clamp(0.0, 1.0));

    return lightened.toColor();
  }
}

/// 🔹 **Optimized Banners Section**
class BannersSection extends StatefulWidget {
  final List<BannerModel> banners;
  final VoidCallback onColorsLoaded;

  const BannersSection({super.key, required this.banners, required this.onColorsLoaded});

  @override
  _BannersSectionState createState() => _BannersSectionState();
}

class _BannersSectionState extends State<BannersSection> {
  final Map<String, Color> _bannerColors = {}; // Local state for instant UI update

  @override
  void initState() {
    super.initState();
    _loadBannerColors();
  }

  /// **🔹 Load banner colors from cache or extract if missing**
  Future<void> _loadBannerColors() async {
    debugPrint("🎯 Starting to load banner colors...");

    int loadedCount = 0;

    if (mounted) {
       // ✅ Wait for the first frame to render before starting heavy work
       WidgetsBinding.instance.addPostFrameCallback((_) async {
          for (var banner in widget.banners) {
            // Check if mounted in loop
            if (!mounted) return;
            
            String imagePath = banner.imagePath;
            debugPrint("🔄 Loading color for: $imagePath");
      
            if (BannerColorCache._cache.containsKey(imagePath)) {
              setState(() {
                  _bannerColors[imagePath] = BannerColorCache._cache[imagePath]!;
              });
              loadedCount++;
            } else {
              // ✅ Yield control to the UI thread for a moment
              await Future.delayed(const Duration(milliseconds: 50));
              
              Color color = await BannerColorCache.getColor(imagePath);
              
              if (mounted) {
                  setState(() {
                    _bannerColors[imagePath] = color;
                  });
              }
              debugPrint("🎨 Extracted color for: $imagePath");
              loadedCount++;
            }
          }
      
          if (mounted && loadedCount == widget.banners.length) {
            debugPrint("🚀 All banner colors ready, triggering onColorsLoaded...");
            widget.onColorsLoaded();
          }
       });
    }
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final String currentLang = Localizations.localeOf(context).languageCode;

    return SizedBox(
      height: screenWidth * 0.32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.banners.length,
        itemBuilder: (context, index) {
          final banner = widget.banners[index];
          String imagePath = banner.imagePath;
          String? logoPath = banner.logoPath;
          Color? logoContainerColor = banner.logoContainerColor != null 
              ? Color(int.parse(banner.logoContainerColor!.replaceFirst('#', '0xFF'))) 
              : null;
          Color backgroundColor = _bannerColors[imagePath] ?? Colors.teal.shade50;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BannerDetailsPage(
                      banner: banner,
                      themeColor: backgroundColor,
                    ),
                  ),
                );
              },
              child: BannerCard(
                title: banner.getTitle(currentLang).isEmpty ? null : banner.getTitle(currentLang),
                text: banner.getText(currentLang),
                imagePath: imagePath,
                logoPath: logoPath, 
                isSponsored: banner.isSponsored,
                backgroundColor: backgroundColor,
                logoContainerColor: logoContainerColor,
                showTitle: banner.showTitle,
              ),
            ),
          );
        },
      ),
    );
  }
}

class BannerCard extends StatelessWidget {
  final String? title;
  final String text;
  final String imagePath;
  final String? logoPath;
  final bool isSponsored;
  final Color backgroundColor;
  final Color? logoContainerColor; // ✅ New parameter for logo background
  final bool showTitle;

  const BannerCard({
    super.key,
    this.title,
    required this.text,
    required this.imagePath,
    this.logoPath,
    this.isSponsored = false,
    required this.backgroundColor,
    this.logoContainerColor,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;

    // ✅ حساب الإضاءة الخاصة بلون الخلفية لتحديد إذا كان فاتحًا
    final double backgroundLightness = HSLColor
        .fromColor(backgroundColor)
        .lightness;
    final double referenceLightness = HSLColor
        .fromColor(AppColors.background2)
        .lightness;

    // ✅ أضف الحدود فقط إذا كان اللون قريبًا من الأبيض أو لون الخلفية العامة
    bool shouldAddBorder = backgroundLightness > 0.85 ||
        (backgroundLightness - referenceLightness).abs() < 0.1;

    return Container(
      width: screenWidth * 0.75,
      height: screenWidth * 0.4,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18.r),
        border: shouldAddBorder
            ? Border.all(
          color: Colors.grey.shade300,
          width: 0.8, // ✅ سمك الحدود الرفيعة
        )
            : null, // ✅ عدم إضافة حدود إذا كان اللون داكنًا
      ),
      child: Stack(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              // ✅ Text Section
              Expanded(
                flex: 3,
                child: Column(
                  textDirection: TextDirection.ltr,
                  mainAxisSize: title == null && logoPath == null ? MainAxisSize
                      .min : MainAxisSize.max,
                  crossAxisAlignment: logoPath != null ? CrossAxisAlignment
                      .start : CrossAxisAlignment.center, // ✅ تحديث ديناميكي
                  children: [
                    // ✅ Logo in the top-left corner inside a small rounded container
                    if (logoPath != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 3.w),
                        child: Container(
                          width: screenWidth * 0.28,
                          // ✅ Small container for the logo
                          height: screenWidth * 0.11,
                          decoration: BoxDecoration(
                            color: logoContainerColor ?? Colors.white,
                            // ✅ Configurable background
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30.r),
                              topRight: Radius.circular(1.r),
                              bottomLeft: Radius.circular(35.r),
                              bottomRight: Radius.circular(70.r),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(left: 8.w,
                                top: 8.w,
                                right: 20.w,
                                bottom: 12.w),
                            child: Center(
                              child: SizedBox(
                                  width: screenWidth * 0.18, // ✅ Even smaller
                                  height: screenWidth * 0.18, // ✅ Maintain aspect ratio
                                  child: BannerLogo(path: logoPath!, size: screenWidth * 0.14)),
                            ),
                          ), // Adjusted size
                        ),
                      ),
                  if (title != null && showTitle)
                      Padding(
                        padding: EdgeInsets.only(
                          top: logoPath != null ? 0.w : 9.w, // ✅ Reduced top padding if logo exists
                          left: 12.w,
                          bottom: 3.w,
                          right: 12.w,
                        ),
                        child: SizedBox(
                          width: Localizations.localeOf(context).languageCode == 'ar' ? double.infinity : null,
                          child: Text(
                              title!,
                              textAlign: Localizations.localeOf(context).languageCode == 'ar' ? TextAlign.right : null,
                              style: AppTextStyles.getTitle1(context)
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: ((title == null || !showTitle) && logoPath != null) ? 0.w : 3.w, // ✅ Adjust top padding
                        left: 12.w,
                        bottom: 9.w,
                        right: 12.w,
                      ),
                      child: SizedBox(
                        width: Localizations.localeOf(context).languageCode == 'ar' ? double.infinity : null,
                        child: Text(
                            text,
                            textAlign: Localizations.localeOf(context).languageCode == 'ar' ? TextAlign.right : null,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: Colors.black87,)
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Image Section (Right)
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(18.r),
                    bottomRight: Radius.circular(18.r),
                    bottomLeft: Radius.circular(100.r),
                  ),
                  child: imagePath.startsWith('http') 
                    ? Image.network(
                        imagePath,
                        width: screenWidth * 0.3,
                        height: screenWidth * 0.4,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: screenWidth * 0.3,
                            height: screenWidth * 0.4,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      )
                    : Image.asset(
                        imagePath,
                        width: screenWidth * 0.3,
                        height: screenWidth * 0.4,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: screenWidth * 0.3,
                            height: screenWidth * 0.4,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),


          // ✅ Sponsored Tag (bottom-right)
          if (isSponsored)
            Positioned(
              bottom: 9.w,
              right: 6.w,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  6.w,
                  0.6.w,
                  6.w,
                  0.6.w,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Text(
                    AppLocalizations.of(context)!.sponsored,
                    style: AppTextStyles.getText4(context).copyWith(
                      color: Colors.black54,)

                ),
              ),
            ),
        ],
      ),
    );
  }
}



class BannerLogo extends StatefulWidget {
  final String path;
  final double size;

  const BannerLogo({super.key, required this.path, required this.size});

  @override
  _BannerLogoState createState() => _BannerLogoState();
}

class _BannerLogoState extends State<BannerLogo> {
  bool _isLoaded = false;
  bool _isValid = true;
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  /// ✅ **Handle Both SVG and PNG/JPG Properly**
  void _loadImage() async {
    if (widget.path.toLowerCase().endsWith('.svg')) {
      _loadSvg();
    } else {
      _preloadAssetImage();
    }
  }

  /// ✅ **Preload PNG/JPG**
  void _preloadAssetImage() async {
    try {
      _imageProvider = AssetImage(widget.path);
      await precacheImage(_imageProvider, context);
      if (mounted) {
        setState(() => _isLoaded = true);
      }
    } catch (e) {
      debugPrint("❌ Image preload failed: $e");
      if (mounted) {
        setState(() => _isValid = false);
      }
    }
  }

  /// ✅ **Load and Verify SVG**
  void _loadSvg() async {
    try {
      String rawSvg = await rootBundle.loadString(widget.path);
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _imageProvider = MemoryImage(Uint8List.fromList(rawSvg.codeUnits));
        });
      }
    } catch (e) {
      debugPrint("❌ SVG Load Error: $e");
      if (mounted) {
        setState(() => _isValid = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValid) return const SizedBox(); // ✅ Avoid errors if the image is invalid

    // Check if it's a network URL
    final isNetwork = widget.path.startsWith('http');
    final isSvg = widget.path.toLowerCase().endsWith('.svg');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isLoaded ? 1.0 : 0.0,
      child: isSvg
          ? (isNetwork 
              ? SvgPicture.network(
                  widget.path,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => const SizedBox(),
                ) 
              : SvgPicture.asset(
                  widget.path,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ))
          : (isNetwork
              ? Image.network(
                  widget.path,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                )
              : Image(
                  image: _imageProvider,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                )),
    );
  }
}


/// **🔹 Features Section (Restored)**
class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFeatureTile(
          context,
          'assets/images/calander.png',
          AppLocalizations.of(context)!.fasterAccess,
          AppLocalizations.of(context)!.fasterAccessDescription,
          width: 70.w,
          height: 70.h,
        ),
        _buildFeatureTile(
          context,
          'assets/images/message.png',
          AppLocalizations.of(context)!.receiveCare,
          AppLocalizations.of(context)!.receiveCareDescription,
          width: 80.w,
          height: 80.h,
        ),
        _buildFeatureTile(
          context,
          'assets/images/heart.png',
          AppLocalizations.of(context)!.manageHealth,
          AppLocalizations.of(context)!.manageHealthDescription,
          width: 70.w,
          height: 70.h,
        ),
      ],
    );
  }

  /// **🔹 Feature Tile Widget**
  Widget _buildFeatureTile(
      BuildContext context,
      String imagePath,
      String title,
      String description, {
        required double width,
        required double height,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 12.h),
      child: Column(
        children: [
          Image.asset(imagePath, width: width, height: height),
          SizedBox(height: 20.h),
          Text(title, style: AppTextStyles.getTitle1(context).copyWith(fontWeight: FontWeight.bold, color: Colors.black87 ,fontSize: 13.sp), textAlign: TextAlign.center),
          SizedBox(height: 5.h),
          Text(description, style: AppTextStyles.getText1(context).copyWith(color: Colors.grey, fontSize: 11.sp), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class DecorativeImageCard extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final Color backgroundColor;
  final Color buttonColor;
  final int shapeNumber;
  final int imageShapeNumber;
  final int? secondShapeNumber;
  final String imagePath;
  final bool showSecondShape;
  final Color shapeColor;
  final Color? secondShapeColor;
  final Color textColor;

  const DecorativeImageCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    required this.backgroundColor,
    required this.buttonColor,
    required this.shapeNumber,
    required this.imageShapeNumber,
    this.secondShapeNumber,
    required this.imagePath,
    this.showSecondShape = false,
    required this.shapeColor,
    this.secondShapeColor,
    this.textColor = Colors.white,
  });

  /// **🔹 اختيار `CustomClipper` المناسب بناءً على `shapeNumber`**
  // CustomClipper<Path> getClipper(int shapeNumber) {
  //   switch (shapeNumber) {
  //     case 1:
  //       return Asset1Clipper();
  //   // ✨ أضف المزيد من `Clippers` هنا لكل `SVG`
  //     default:
  //       return Asset1Clipper(); // افتراضيًا استخدم `Asset1Clipper`
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // 1) Retrieve the path string from the map
    final String? svgPathData = kSvgPaths[imageShapeNumber];
    // fallback if the shapeNumber isn't in the map
    final String fallbackData = kSvgPaths[1]!;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 30),
            SizedBox(
              height: 220.h,
              width: double.infinity.w,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                   // ✅ Shape 1
                  Positioned(
                    top: 10.h,
                    left: 40.w,
                    child: SvgPicture.asset(
                      'assets/shapes/Asset $shapeNumber.svg',
                      width: 160.w,
                      height: 190.h,
                      colorFilter: ColorFilter.mode(
                        shapeColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                  // ✅ Image Clipper
                  Align(
                    alignment: Alignment.center,
                    child: ClipPath(
                      clipper: SvgPathClipper(svgPathData ?? fallbackData),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double imageWidth = 220.w;
                          double imageHeight = 220.h;
                          final cleanPath = imagePath.trim();
                          
                          if (cleanPath.startsWith('http')) {
                             return SizedBox(
                               width: imageWidth,
                               height: imageHeight,
                               child: Image.network(
                                 cleanPath,
                                 fit: BoxFit.cover,
                                 alignment: Alignment.center,
                                 errorBuilder: (context, error, stackTrace) {
                                   return const Center(child: Icon(Icons.error));
                                 },
                               ),
                             );
                          } else {
                             return SizedBox(
                               width: imageWidth,
                               height: imageHeight,
                               child: Image.asset(
                                 cleanPath,
                                 fit: BoxFit.cover,
                                 alignment: Alignment.center,
                               ),
                             );
                          }
                        },
                      ),
                    ),
                  ),



                  // ✅ الشكل الثاني (اختياري)
                  if (showSecondShape && secondShapeNumber != null)
                    Positioned(
                      top: 180.h,
                      left: 170.w,
                      child: SvgPicture.asset(
                        'assets/shapes/Asset $secondShapeNumber.svg',
                        width: 90.w,
                        height: 100.h,
                        colorFilter: ColorFilter.mode(
                          secondShapeColor ?? Colors.white.withOpacity(0.3),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // ✅ النصوص
            Padding(
              padding:  EdgeInsets.all(10.w),
              child: Text(
                title,
                style: AppTextStyles.getTitle3(context).copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 35.w),
              child: Text(
                description,
                style: AppTextStyles.getText2(context).copyWith(color: textColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20.h),

            // ✅ الزر
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                buttonText,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}



class CompactDecorativeCard extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final Color backgroundColor;
  final Color buttonColor;
  final int shapeNumber;
  final int imageShapeNumber;
  final int? secondShapeNumber;
  final String imagePath;
  final bool showSecondShape;
  final Color shapeColor;
  final Color? secondShapeColor;
  final Color textColor;

  const CompactDecorativeCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    required this.backgroundColor,
    required this.buttonColor,
    required this.shapeNumber,
    required this.imageShapeNumber,
    this.secondShapeNumber,
    required this.imagePath,
    this.showSecondShape = false,
    required this.shapeColor,
    this.secondShapeColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // 1) Retrieve the path string from the map
    final String? svgPathData = kSvgPaths[imageShapeNumber];
    // fallback if the shapeNumber isn't in the map
    final String fallbackData = kSvgPaths[1]!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Container(
        height: 120.h, // Compact height (~55% of original)
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // ✅ Left Side: Text & Button
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.getTitle3(context).copyWith(
                        color: textColor,
                        fontSize: 16.sp, // Slightly smaller font
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: textColor.withOpacity(0.7),
                        fontSize: 11.sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 32.h,
                      child: ElevatedButton(
                        onPressed: onButtonPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          buttonText,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Right Side: Image & Shapes
            Expanded(
              flex: 2,
              child: Stack(
                clipBehavior: Clip.hardEdge, // Clip content to container bounds
                alignment: Alignment.center,
                children: [
                   // Background Shape
                  PositionedDirectional(
                    end: 40.w, // Moves shape inwards (Left in EN, Right in AR)
                    top: 15.h, 
                    child: SvgPicture.asset(
                      'assets/shapes/Asset $shapeNumber.svg',
                      width: 70.w,
                      height: 85.h,
                      colorFilter: ColorFilter.mode(
                        shapeColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                  // Image Clipper
                  PositionedDirectional(
                    end: 5.w,
                    child: SizedBox(
                      width: 110.w,
                      height: 110.h,
                      child: ClipPath(
                        clipper: SvgPathClipper(svgPathData ?? fallbackData),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cleanPath = imagePath.trim();
                            if (cleanPath.startsWith('http')) {
                               return Image.network(
                                 cleanPath,
                                 fit: BoxFit.cover,
                                 errorBuilder: (context, error, stackTrace) =>
                                     const Center(child: Icon(Icons.error, size: 20)),
                               );
                            } else {
                               return Image.asset(
                                 cleanPath,
                                 fit: BoxFit.cover,
                               );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//     path.quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width, size.height * 0.1);
//     path.lineTo(size.width, size.height);
//     path.lineTo(0, size.height);
//     path.close();
//
//     return path;
//   }
//
//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }
//
// CustomClipper<Path> getClipper(int shapeNumber) {
//   switch (shapeNumber) {
//     case 1:
//       return Asset1Clipper();
//     // case 2:
//     //   return Asset2Clipper();
//     // case 3:
//     //   return Asset3Clipper();
//   // ✨ أضف بقية الـ Clippers حسب الحاجة
//     default:
//       return Asset1Clipper(); // افتراضيًا استخدم `Asset1Clipper`
//   }
// }
