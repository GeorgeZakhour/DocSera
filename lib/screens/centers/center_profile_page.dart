import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/services/supabase/supabase_center_service.dart';
import 'package:docsera/services/supabase/repositories/favorites_repository.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/rotating_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:docsera/screens/map_results_page.dart';

class CenterProfilePage extends StatefulWidget {
  final String centerId;
  final bool fromProfile;
  final String? fromDoctorId;
  const CenterProfilePage({super.key, required this.centerId, this.fromProfile = false, this.fromDoctorId});

  @override
  State<CenterProfilePage> createState() => _CenterProfilePageState();
}

class _CenterProfilePageState extends State<CenterProfilePage> {
  Map<String, dynamic>? _centerData;
  List<Map<String, dynamic>> _teamDoctors = [];

  /// Raw map representation (mirrors what the doctor profile uses), so
  /// the promotion renderer can share the exact same look + claim flow.
  List<Map<String, dynamic>> _promotions = const [];
  bool _isLoading = true;
  bool _isFavorite = false; // Add favorite tracker
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = false;

  Future<void> _loadCenterPromotions() async {
    try {
      // Call the RPC directly and keep the JSON shape so the promotion
      // renderer (copied from the doctor profile) can consume the same
      // keys it already knows how to read.
      final response = await Supabase.instance.client.rpc(
        'get_public_center_promotions',
        params: {'p_center_id': widget.centerId},
      );
      if (!mounted) return;
      if (response is List) {
        final all = List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        // Hide promotions that have hit their global cap — matches the
        // doctor profile's filtering so the two UIs behave consistently.
        final visible = all.where((p) {
          final maxClaims = p['max_claims'] as int?;
          final currentClaims = p['current_claims'] as int? ?? 0;
          if (maxClaims != null && currentClaims >= maxClaims) return false;
          return true;
        }).toList();
        setState(() => _promotions = visible);
      }
    } catch (_) {
      // Silent failure — promotions are optional content.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCenterData();
    _loadCenterPromotions();
    _scrollController.addListener(() {
      final show =
          _scrollController.offset > MediaQuery.of(context).size.height * 0.18;
      if (show != _showAppBar) setState(() => _showAppBar = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _expandedImageOverlay = false;
  List<String> _expandedImageUrls = [];
  int _initialImageIndex = 0;
  final TransformationController _transformationController =
      TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  final Map<String, ImageProvider> _imageCache = {};
  bool _isOpeningImageOverlay = false;

  void _showImageOverlayWithIndex(List<String> urls, int index) {
    if (_isOpeningImageOverlay) return;
    _isOpeningImageOverlay = true;

    setState(() {
      _expandedImageUrls = urls;
      _initialImageIndex = index;
      _expandedImageOverlay = true;
    });

    for (final url in urls) {
      _preloadImage(url);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isOpeningImageOverlay = false;
    });
  }

  void _hideImageOverlay() {
    setState(() {
      _expandedImageOverlay = false;
      _expandedImageUrls = [];
    });
  }

  Future<void> _preloadImage(String url) async {
    if (_imageCache.containsKey(url)) return;

    final completer = Completer<ImageInfo>();
    final stream =
        CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info);
    });

    stream.addListener(listener);
    final imageInfo = await completer.future;
    final byteData =
        await imageInfo.image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    if (mounted) {
      setState(() {
        _imageCache[url] = MemoryImage(bytes);
      });
    }
  }

  Future<void> _loadCenterData() async {
    final service = SupabaseCenterService();
    final data = await service.getCenterData(widget.centerId);
    debugPrint('🏥 CenterProfile: getCenterData returned ${data != null ? 'data' : 'null'} for ${widget.centerId}');
    final team = await service.fetchCenterTeam(widget.centerId);
    debugPrint('🏥 CenterProfile: fetchCenterTeam returned ${team.length} doctors');

    // Check Favorites Status natively
    final userId = Supabase.instance.client.auth.currentUser?.id;
    bool isFav = false;
    if (userId != null) {
      final favRepo = FavoritesRepository();
      final favList = await favRepo.getUserFavorites(userId);
      isFav = favList.contains(widget.centerId);
    }

    if (mounted) {
      setState(() {
        _centerData = data;
        _teamDoctors = team;
        _isFavorite = isFav;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red.withOpacity(0.8),
          content: Text(AppLocalizations.of(context)!.loginFirst),
        ),
      );
      return;
    }

    final res = await Supabase.instance.client.rpc(
      'toggle_favorite_doctor',
      params: {'p_doctor_id': widget.centerId},
    );

    if (res is bool) {
      if (mounted) {
        setState(() {
          _isFavorite = res;
        });
      }
    }
  }

  String _getCenterImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    try {
      if (imagePath.startsWith('http')) return imagePath;
      final url = Supabase.instance.client.storage
          .from('center-images')
          .getPublicUrl(imagePath);
      return url;
    } catch (_) {
      return '';
    }
  }

  String _getGalleryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    try {
      if (path.startsWith('http')) return path;
      return Supabase.instance.client.storage
          .from(
              'center-images') // Changed from center-assets to center-images to match _getCenterImageUrl bucket
          .getPublicUrl(path);
    } catch (_) {
      return '';
    }
  }

  /// Safely parse a value that may be a List, a JSON string, or null.
  List? _parseList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String) {
      try {
        final d = jsonDecode(raw);
        if (d is List) return d;
      } catch (_) {}
    }
    return null;
  }

  /// Safely parse a value that may be a Map, a JSON string, or null.
  Map<String, dynamic>? _parseMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  /// Parse a value as Map/List from JSON string or return as-is.
  dynamic _parseMapOrRaw(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  void _shareCenterLink() {
    if (_centerData == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final token = _centerData?['public_token'] ?? widget.centerId;
    if (token == null || token.toString().isEmpty) return;
    final deepLink = 'docsera://center/$token';
    final name = _centerData?['name'] ?? '';
    final text = isArabic
        ? '🏥 $name\n\nافتح ملف المركز مباشرة على تطبيق DocSera:\n$deepLink'
        : '🏥 $name\n\nOpen the center profile directly in DocSera:\n$deepLink';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      text,
      subject:
          isArabic ? 'ملف المركز على DocSera' : 'Center Profile on DocSera',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  void _showCenterQrSheet() {
    final token = _centerData?['public_token'] ?? widget.centerId;
    if (token == null || token.toString().isEmpty) return;
    final deepLink = 'docsera://center/$token';
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.background2.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: AppColors.main.withOpacity(0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10))),
            SizedBox(height: 20.h),
            Text(l.shareCenterProfile,
                style:
                    AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r)),
              child: QrImageView(
                  data: deepLink, version: QrVersions.auto, size: 200.w),
            ),
            SizedBox(height: 16.h),
            Text(l.scanToOpenCenterInApp,
                style: AppTextStyles.getText3(context),
                textAlign: TextAlign.center),
            SizedBox(height: 20.h),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon:
                      Icon(Icons.copy, size: 16.sp, color: AppColors.mainDark),
                  label: Text(l.copyLink,
                      style: const TextStyle(color: AppColors.mainDark)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: deepLink));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: AppColors.main.withOpacity(0.8),
                        content: Text(l.linkCopied)));
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.share, size: 16.sp),
                  label: Text(l.share),
                  onPressed: _shareCenterLink,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageOverlay() {
    final lang = AppLocalizations.of(context)!.localeName;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideImageOverlay,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
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
                                icon: Icon(Icons.close,
                                    color: Colors.white, size: 18.sp),
                                onPressed: _hideImageOverlay,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_expandedImageUrls.length > 1)
                        Text(
                          '${_initialImageIndex + 1} ${AppLocalizations.of(context)!.ofText ?? "Of"} ${_expandedImageUrls.length}',
                          style: AppTextStyles.getText1(context)
                              .copyWith(color: Colors.white),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: PageController(initialPage: _initialImageIndex),
                    itemCount: _expandedImageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _initialImageIndex = index;
                        _transformationController.value = Matrix4.identity();
                      });
                    },
                    itemBuilder: (_, index) {
                      final url = _expandedImageUrls[index];
                      final image = _imageCache[url];
                      return GestureDetector(
                        onDoubleTapDown: (details) {
                          _doubleTapPosition = details.localPosition;
                        },
                        onDoubleTap: () {
                          final zoomed = _transformationController.value !=
                              Matrix4.identity();
                          if (zoomed) {
                            _transformationController.value =
                                Matrix4.identity();
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
                          child: Center(
                            child: image != null
                                ? Image(image: image, fit: BoxFit.contain)
                                : CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.background4,
          body: Center(child: RotatingLogoLoader()));
    }
    final center = _centerData ?? {};
    final name = (center['name'] ?? '').toString().trim();
    final imagePath = center['center_image']?.toString() ?? '';
    final imageUrl = _getCenterImageUrl(imagePath);

    // Data fields — many may arrive as JSON strings from Supabase
    final specialties = _parseList(center['specialties'])?.cast<String>() ?? [];
    final description = (center['description'] ?? '').toString().trim();
    final gallery = _parseList(center['gallery'])?.cast<String>() ?? [];
    final services = _parseMap(center['offered_services']) ?? {};
    final languages = _parseList(center['languages'])?.cast<String>() ?? [];
    final insurance =
        _parseList(center['insurance_accepted'])?.cast<String>() ?? [];
    final facilities = _parseList(center['facilities'])?.cast<String>() ?? [];
    final socialMedia = _parseMap(center['social_media']);
    final openingHours = _parseMapOrRaw(center['opening_hours']);
    final email = (center['email'] ?? '').toString().trim();
    final mobile = (center['mobile_number'] ?? '').toString().trim();
    final website = (center['website'] ?? '').toString().trim();
    final phonesArray = _parseList(center['phones']) ?? [];
    final faqs = _parseMapOrRaw(center['faqs']);
    final address = _parseMap(center['address']) ?? {};
    final location = _parseMapOrRaw(center['location']) ?? {};

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background4,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── SliverAppBar (same style as doctor profile)
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.28,
                pinned: true,
                floating: false,
                elevation: 0,
                backgroundColor: AppColors.main,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new,
                      color: AppColors.whiteText, size: 16.sp),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.star : Icons.star_border,
                      color: _isFavorite ? AppColors.whiteText : Colors.white70,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                  IconButton(
                      icon: const Icon(Icons.qr_code_rounded,
                          color: AppColors.whiteText),
                      onPressed: _showCenterQrSheet),
                  IconButton(
                      icon: const Icon(Icons.share, color: AppColors.whiteText),
                      onPressed: _shareCenterLink),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Opacity(
                    opacity: _showAppBar ? 1.0 : 0.0,
                    child: Text(name,
                        style: AppTextStyles.getTitle2(context)
                            .copyWith(color: AppColors.whiteText)),
                  ),
                  background: Stack(fit: StackFit.expand, children: [
                    Image.asset('assets/images/doctor_header_pattern.webp',
                        fit: BoxFit.cover),
                    Container(color: AppColors.background2.withOpacity(0.15)),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(height: 60.h),
                      GestureDetector(
                        onTap: () {
                          if (imageUrl.startsWith('http'))
                            _showImageOverlayWithIndex([imageUrl], 0);
                        },
                        child: CircleAvatar(
                          backgroundColor: AppColors.main.withOpacity(0.3),
                          radius: 40.r,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50.r),
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 80.r,
                                    height: 80.r,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                        Icons.local_hospital_rounded,
                                        size: 35.r,
                                        color: Colors.white70))
                                : Icon(Icons.local_hospital_rounded,
                                    size: 35.r, color: Colors.white70),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(name,
                          style: AppTextStyles.getTitle2(context)
                              .copyWith(color: AppColors.whiteText)),
                      if (specialties.isNotEmpty) ...[
                        SizedBox(height: 5.h),
                        Text(
                          specialties.take(3).join(' • '),
                          style: AppTextStyles.getText2(context).copyWith(
                              fontWeight: FontWeight.w500, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),

              // ── Content sections
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(children: [
                      SizedBox(height: 15.h),

                      // 1. Promotions (FIRST section — strong "reason to book" signal)
                      if (_promotions.isNotEmpty) ...[
                        _buildPromotionsSection(_promotions),
                        SizedBox(height: 10.h),
                      ],

                      // 2. Description
                      if (description.isNotEmpty) ...[
                        _buildDescriptionSection(description),
                        SizedBox(height: 10.h),
                      ],

                      // 3. Gallery
                      if (gallery.isNotEmpty) ...[
                        _buildGallerySection(gallery),
                        SizedBox(height: 10.h),
                      ],

                      // 4. Specialties
                      if (specialties.isNotEmpty) ...[
                        _buildSpecialtiesSection(specialties),
                        SizedBox(height: 10.h),
                      ],

                      // 5. Services
                      if (services.isNotEmpty) ...[
                        _buildServicesSection(services),
                        SizedBox(height: 10.h),
                      ],

                      // 6. FAQs
                      if (faqs != null) ...[
                        _buildFAQsSection(faqs),
                        SizedBox(height: 10.h),
                      ],

                      // 7. Contact + Opening Hours + Languages
                      if (mobile.isNotEmpty ||
                          email.isNotEmpty ||
                          website.isNotEmpty ||
                          phonesArray.isNotEmpty ||
                          openingHours != null ||
                          languages.isNotEmpty) ...[
                        _buildInfoSection(mobile, email, website, phonesArray,
                            openingHours, languages),
                        SizedBox(height: 10.h),
                      ],

                      // 8. Location
                      if (address.isNotEmpty) ...[
                        _buildLocationSection(address, location),
                        SizedBox(height: 10.h),
                      ],

                      // 9. Insurance
                      if (insurance.isNotEmpty) ...[
                        _buildInsuranceSection(insurance),
                        SizedBox(height: 10.h),
                      ],

                      // 10. Facilities
                      if (facilities.isNotEmpty) ...[
                        _buildFacilitiesSection(facilities),
                        SizedBox(height: 10.h),
                      ],

                      // 11. Social Media
                      if (socialMedia != null &&
                          socialMedia.values.any(
                              (v) => (v ?? '').toString().trim().isNotEmpty)) ...[
                        _buildSocialMediaSection(socialMedia),
                        SizedBox(height: 10.h),
                      ],

                      // 12. Team section (Last — Doctors & Specialists)
                      if (_teamDoctors.isNotEmpty) ...[
                        _buildTeamSection(),
                        SizedBox(height: 10.h),
                      ],

                      SizedBox(height: 80.h),
                    ]),
                  ),
                ]),
              ),
            ],
          ),

          // ── Image Overlay (displayed on top of everything)
          if (_expandedImageOverlay) _buildImageOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── TEAM SECTION (full doctor cards)
  // ═══════════════════════════════════════════════════════
  Widget _buildTeamSection() {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.people_alt_outlined,
              color: AppColors.mainDark, size: 16.sp),
          SizedBox(width: 5.w),
          Text(l.medicalTeam,
              style:
                  AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp)),
        ]),
        SizedBox(height: 12.h),
        SizedBox(
          height: 200.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _teamDoctors.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final doc = _teamDoctors[index];
              return _buildDoctorCard(doc);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarWidget = imageResult.widget;
    final title = doctor['title'] ?? '';
    final firstName = doctor['first_name'] ?? '';
    final lastName = doctor['last_name'] ?? '';
    final specialty = doctor['specialty'] ?? '';
    final doctorId = doctor['id'] ?? '';

    return GestureDetector(
      onTap: () {
        if (doctorId.isNotEmpty) {
          if (widget.fromDoctorId == doctorId) {
            // Same doctor we came from — just go back
            Navigator.pop(context);
          } else if (widget.fromProfile) {
            // Different doctor, but already deep — replace to prevent loop
            Navigator.pushReplacement(
                context, fadePageRoute(DoctorProfilePage(doctorId: doctorId, fromProfile: true)));
          } else {
            // First hop — push normally so back works
            Navigator.push(
                context, fadePageRoute(DoctorProfilePage(doctorId: doctorId, fromProfile: true)));
          }
        }
      },
      child: Container(
        width: 150.w,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.background2,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35.r,
              backgroundColor: AppColors.main.withOpacity(0.1),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(35.r),
                  child:
                      SizedBox(width: 70.r, height: 70.r, child: avatarWidget)),
            ),
            SizedBox(height: 10.h),
            Text(
              '$title $firstName $lastName'.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 10.sp),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                specialty,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.mainDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── PROMOTIONS SECTION (FIRST)
  //
  // Mirrors the doctor profile's promotions section so the visual
  // language is identical across both pages: gradient icon header,
  // colored offer-type cards, "Show all" sheet, claim sheet reused
  // via showPromotionClaimSheet (defined in doctor_profile_page.dart).
  // ═══════════════════════════════════════════════════════
  Widget _buildPromotionsSection(List<Map<String, dynamic>> promotions) {
    if (promotions.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
            color: AppColors.main.withValues(alpha: 0.20), width: 0.8),
      ),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — gradient icon + "Promotions" title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.main, Color(0xFF00B4B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.local_offer_rounded,
                      color: Colors.white, size: 14.sp),
                ),
                SizedBox(width: 8.w),
                Text(
                  l.promotions,
                  style: AppTextStyles.getTitle1(context)
                      .copyWith(fontSize: 11.sp),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            ...promotions.take(2).map((promo) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _buildPromotionItem(promo, l, isAr),
                )),
            if (promotions.length > 2)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        _showAllPromotionsSheet(promotions, l, isAr),
                    icon: Icon(Icons.expand_more_rounded,
                        size: 16.sp, color: AppColors.main),
                    label: Text(
                      '${l.showAll} (${promotions.length})',
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 4.h),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 6.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13.sp, color: Colors.grey[400]),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    l.promotionPressHereToClaim,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: Colors.grey[500],
                      fontSize: 10.sp,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAllPromotionsSheet(
    List<Map<String, dynamic>> promotions,
    AppLocalizations l,
    bool isAr,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 16.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.main, Color(0xFF00B4B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.local_offer_rounded,
                        color: Colors.white, size: 14.sp),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${l.promotions} (${promotions.length})',
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 13.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                shrinkWrap: true,
                itemCount: promotions.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (ctx, index) =>
                    _buildPromotionItem(promotions[index], l, isAr),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13.sp, color: Colors.grey[400]),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      l.promotionPressHereToClaim,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.grey[500],
                        fontSize: 10.sp,
                        height: 1.4,
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

  Widget _buildPromotionItem(
    Map<String, dynamic> promo,
    AppLocalizations l,
    bool isAr,
  ) {
    final offerType = promo['offer_type'] as String? ?? 'custom';
    final discountValue = (promo['discount_value'] as num?)?.toDouble();
    final discountType = promo['discount_type'] as String?;
    final customTitle = promo['custom_title'] as String?;
    final customTitleAr = promo['custom_title_ar'] as String?;
    final description = promo['description'] as String?;
    final descriptionAr = promo['description_ar'] as String?;
    final audience = promo['audience'] as String? ?? 'all_patients';
    final maxPerPatient = promo['max_claims_per_patient'] as int?;
    final endDate = promo['end_date'] as String?;
    final currency = l.currency;

    String title;
    if (offerType == 'custom') {
      String baseTitle;
      if (isAr && customTitleAr != null && customTitleAr.isNotEmpty) {
        baseTitle = customTitleAr;
      } else if (customTitle != null && customTitle.isNotEmpty) {
        baseTitle = customTitle;
      } else {
        baseTitle = customTitleAr ?? l.promotions;
      }
      if (discountValue != null && discountValue > 0) {
        final valuePart = discountType == 'fixed'
            ? '⁨${discountValue.toInt()} $currency⁩'
            : '⁨${discountValue.toInt()}%⁩';
        title = '$baseTitle • $valuePart';
      } else {
        title = baseTitle;
      }
    } else {
      switch (offerType) {
        case 'free_first_consultation':
          title = l.freeFirstConsultation;
          break;
        case 'percentage_discount':
          title = '${discountValue?.toInt() ?? 0}% ${l.percentageDiscount}';
          break;
        case 'fixed_discount':
          title =
              '${discountValue?.toInt() ?? 0} $currency ${l.fixedDiscount}';
          break;
        case 'free_followup':
          title = l.freeFollowup;
          break;
        default:
          title = l.specialOffer;
      }
    }

    final desc = isAr
        ? (descriptionAr ?? description)
        : (description ?? descriptionAr);

    IconData icon;
    Color color;
    switch (offerType) {
      case 'free_first_consultation':
        icon = Icons.medical_services_outlined;
        color = const Color(0xFF3BB273);
        break;
      case 'percentage_discount':
        icon = Icons.percent_rounded;
        color = const Color(0xFF5B8DEF);
        break;
      case 'fixed_discount':
        icon = Icons.attach_money_rounded;
        color = const Color(0xFFE8A838);
        break;
      case 'free_followup':
        icon = Icons.repeat_rounded;
        color = const Color(0xFF9B59B6);
        break;
      default:
        icon = Icons.auto_awesome_rounded;
        color = AppColors.main;
    }

    String? expiryText;
    if (endDate != null) {
      final end = DateTime.tryParse(endDate);
      if (end != null) {
        final daysLeft = end.difference(DateTime.now()).inDays;
        if (daysLeft > 0 && daysLeft <= 30) {
          expiryText = '$daysLeft ${l.daysRemaining}';
        }
      }
    }

    String? eligibilityTag;
    if (offerType == 'free_first_consultation') {
      eligibilityTag = l.promotionFirstVisitOnly;
    } else if (maxPerPatient != null && maxPerPatient == 1) {
      eligibilityTag = l.promotionSingleUse;
    } else if (maxPerPatient != null && maxPerPatient > 1) {
      eligibilityTag = l.promotionMultiUse(maxPerPatient);
    }

    final hasActiveVoucher = promo['has_active_voucher'] == true;
    final bgColor = hasActiveVoucher
        ? color.withValues(alpha: 0.12)
        : color.withValues(alpha: 0.05);
    final borderColor = hasActiveVoucher
        ? color.withValues(alpha: 0.45)
        : color.withValues(alpha: 0.15);
    final borderWidth = hasActiveVoucher ? 1.2 : 1.0;

    return GestureDetector(
      onTap: () {
        // Reuse the doctor profile's claim sheet — same QR / status /
        // reuse-on-existing-voucher flow as a doctor-owned promotion.
        showPromotionClaimSheet(
          context,
          promoId: promo['id'] as String,
          title: title,
          description: desc,
          color: color,
          icon: icon,
        );
      },
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: bgColor,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: hasActiveVoucher
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38.r,
              height: 38.r,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.85),
                          color.withValues(alpha: 0.45),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18.sp),
                  ),
                  if (hasActiveVoucher)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14.r,
                        height: 14.r,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(Icons.qr_code_rounded,
                            color: color, size: 10.sp),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.getTitle2(context).copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (eligibilityTag != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      eligibilityTag,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.grey[500],
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
                  // Scope + audience tags row.
                  // ALL promos shown on the center profile are
                  // center-owned, so we always have a scope to show:
                  // "All doctors at the center" OR "Selected doctors".
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      _promoTag(
                        _centerProfileScopeLabel(promo, l),
                        const Color(0xFF00B4B6),
                      ),
                      if (audience == 'new_patients')
                        _promoTag(l.newPatientsOnly, Colors.blue),
                      if (expiryText != null)
                        _promoTag(expiryText, Colors.orange),
                    ],
                  ),
                  // For "Selected doctors" offers — list the eligible
                  // doctors so the patient knows who to book with
                  // (otherwise they may book Dr. Y, claim, then get
                  // "voucher doesn't apply" at billing).
                  if (_isSelectedDoctorsScope(promo)) ...[
                    SizedBox(height: 6.h),
                    _buildEligibleDoctorsLine(promo, l),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// All promos on the center profile are center-owned. The scope
  /// distinguishes "any doctor at the center" from "narrowed to a
  /// specific doctor list" (via promotion_target_doctors).
  String _centerProfileScopeLabel(
    Map<String, dynamic> promo,
    AppLocalizations l,
  ) {
    final raw = promo['target_doctor_ids'];
    final ids = raw is List ? raw : const <dynamic>[];
    return ids.isEmpty
        ? l.centerScopeAllDoctors
        : l.centerScopeSelectedDoctors;
  }

  bool _isSelectedDoctorsScope(Map<String, dynamic> promo) {
    final raw = promo['target_doctor_ids'];
    return raw is List && raw.isNotEmpty;
  }

  /// Renders "Valid with: Dr. A, Dr. B" for a selected-doctors offer.
  /// Names are resolved against `_teamDoctors` (already loaded for the
  /// Team section), so this needs no extra backend lookup. When a
  /// target_doctor_id can't be matched (rare — would mean a doctor
  /// removed from the center after the promo was created), the row
  /// falls back to showing the count only.
  Widget _buildEligibleDoctorsLine(
    Map<String, dynamic> promo,
    AppLocalizations l,
  ) {
    final raw = promo['target_doctor_ids'];
    final targetIds = raw is List
        ? raw.map((e) => e.toString()).toSet()
        : const <String>{};
    if (targetIds.isEmpty) return const SizedBox.shrink();

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final names = <String>[];
    for (final d in _teamDoctors) {
      final id = d['id']?.toString();
      if (id == null || !targetIds.contains(id)) continue;
      final title = (d['title'] as String?)?.trim() ?? '';
      final first = (d['first_name'] as String?)?.trim() ?? '';
      final last = (d['last_name'] as String?)?.trim() ?? '';
      // Prefer Arabic name fields when running RTL if the team data
      // exposes them; otherwise compose from the basic first/last.
      final firstAr = (d['first_name_ar'] as String?)?.trim() ?? '';
      final lastAr = (d['last_name_ar'] as String?)?.trim() ?? '';
      final composed = isAr && (firstAr.isNotEmpty || lastAr.isNotEmpty)
          ? [title, firstAr, lastAr]
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim()
          : [title, first, last]
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim();
      if (composed.isNotEmpty) names.add(composed);
    }

    if (names.isEmpty) {
      // Fallback — show just the count if we couldn't resolve names.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline_rounded,
              size: 12.sp, color: Colors.grey[500]),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              '${l.appliesToDoctors}: ${targetIds.length} ${l.doctorsLowercase}',
              style: AppTextStyles.getText3(context).copyWith(
                color: Colors.grey[600],
                fontSize: 9.5.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.person_outline_rounded,
            size: 12.sp, color: Colors.grey[500]),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            '${l.appliesToDoctors}: ${names.join('، ')}',
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.grey[600],
              fontSize: 9.5.sp,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _promoTag(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── DESCRIPTION SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildDescriptionSection(String? description) {
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    String plainTextSummary = '';
    try {
      final decoded = jsonDecode(description);
      if (decoded is Map &&
          decoded['version'] == 3 &&
          decoded['parts'] is List) {
        final parts = decoded['parts'] as List;
        if (parts.isNotEmpty) {
          final firstPart = parts[0];
          if (firstPart['delta'] != null) {
            final doc = quill.Document.fromJson(firstPart['delta']);
            plainTextSummary = doc.toPlainText().trim();
          }
        }
      } else {
        final doc = quill.Document.fromJson(decoded);
        plainTextSummary = doc.toPlainText().trim();
      }
    } catch (e) {
      plainTextSummary = AppLocalizations.of(context)!.notProvided;
    }

    if (plainTextSummary.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showCenterDetails(description),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Card(
            color: AppColors.background2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: Colors.grey.shade200, width: 0.8),
            ),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.mainDark, size: 16.sp),
                          SizedBox(width: 5.w),
                          Text(
                            AppLocalizations.of(context)!.aboutCenter,
                            style: AppTextStyles.getTitle1(context)
                                .copyWith(fontSize: 11.sp),
                          ),
                        ],
                      ),
                      if (plainTextSummary.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.viewMore,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.main,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Localizations.localeOf(context).languageCode ==
                                      'ar'
                                  ? Icons.keyboard_arrow_left
                                  : Icons.keyboard_arrow_right,
                              color: AppColors.main,
                              size: 18.sp,
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (plainTextSummary.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                          top: 4.h, right: 12.w, left: 12.w, bottom: 8.h),
                      child: Text(
                        plainTextSummary,
                        style: AppTextStyles.getText3(context),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── GALLERY SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildGallerySection(List<String> galleryUrls) {
    if (galleryUrls.isEmpty) return const SizedBox.shrink();

    final urls = galleryUrls
        .map((p) => _getGalleryImageUrl(p))
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final previewImages = urls.take(4).toList();
    final extraCount = urls.length > 4 ? urls.length - 3 : 0;

    return GestureDetector(
      onTap: () => _showImageOverlayWithIndex(urls, 0),
      child: Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: AppColors.mainDark, size: 16.sp),
                  SizedBox(width: 5.w),
                  Text(
                    AppLocalizations.of(context)!.gallery,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 11.sp),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: previewImages.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 6.w,
                  mainAxisSpacing: 6.h,
                ),
                itemBuilder: (_, index) {
                  return GestureDetector(
                    onTap: () {
                      if (index < 3 || extraCount == 0) {
                        _showImageOverlayWithIndex(urls, index);
                      } else {
                        // Open full gallery modal if clicking on the +X image
                        _showGallerySheet(urls);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: CachedNetworkImage(
                            imageUrl: previewImages[index],
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey[400])),
                          ),
                        ),
                        if (index == 3 && extraCount > 0)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Text(
                                '+$extraCount',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGallerySheet(List<String> urls) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.8,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.gallery,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 12.sp),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      itemCount: urls.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8.w,
                        mainAxisSpacing: 8.h,
                      ),
                      itemBuilder: (_, index) {
                        return GestureDetector(
                          onTap: () {
                            _showImageOverlayWithIndex(urls, index);
                            Navigator.pop(context);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: CachedNetworkImage(
                              imageUrl: urls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── SPECIALTIES SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildSpecialtiesSection(List<String> specialties) {
    final l = AppLocalizations.of(context)!;
    return _buildSectionCard(
      icon: Icons.local_hospital_outlined,
      title: l.specialtiesDepartments,
      child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: specialties
              .map((s) => Container(
                    decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    child: Text(s,
                        style: AppTextStyles.getText2(context).copyWith(
                            color: AppColors.mainDark,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList()),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── SERVICES SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildServicesSection(dynamic servicesInput) {
    if (servicesInput == null) return const SizedBox.shrink();

    List<Map<String, dynamic>> servicesList = [];

    try {
      if (servicesInput is List) {
        servicesList =
            servicesInput.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (servicesInput is String) {
        final decoded = jsonDecode(servicesInput);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            servicesList.add({
              'title': key.toString(),
              'description': value?.toString() ?? ''
            });
          });
        } else if (decoded is List) {
          servicesList = List<Map<String, dynamic>>.from(decoded);
        }
      } else if (servicesInput is Map) {
        servicesInput.forEach((key, value) {
          servicesList.add({
            'title': key.toString(),
            'description': value?.toString() ?? ''
          });
        });
      }
    } catch (e) {
      debugPrint("❌ Error parsing services: $e");
    }

    if (servicesList.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showServicesBottomSheet(servicesList),
      child: Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services_outlined,
                          color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        AppLocalizations.of(context)!.offeredServices,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.viewMore,
                        style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.main, fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? Icons.keyboard_arrow_left
                            : Icons.keyboard_arrow_right,
                        color: AppColors.main,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ...servicesList.take(2).map((item) {
                final title = item['title'] ?? '';
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child:
                      Text("• $title", style: AppTextStyles.getText3(context)),
                );
              }),
              if (servicesList.length > 2)
                Text(
                  "+${servicesList.length - 2} ${AppLocalizations.of(context)!.showMore}",
                  style: AppTextStyles.getText3(context)
                      .copyWith(color: AppColors.mainDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServicesBottomSheet(List<Map<String, dynamic>> services) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.8,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.offeredServices,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: services.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey[200], thickness: 1),
                      itemBuilder: (context, index) {
                        final item = services[index];
                        final title = item['title'] ?? '';
                        final description = item['description']?.trim() ?? '';

                        final bullet = Icon(Icons.check_circle_outline, color: AppColors.main, size: 18.sp);

                        if (description.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
                            child: Row(
                              children: [
                                bullet,
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return _CustomExpandableServiceTile(title: title, description: description);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── FAQs SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildFAQsSection(dynamic faqsInput) {
    final l = AppLocalizations.of(context)!;
    List<Map<String, dynamic>> faqsList = [];
    try {
      if (faqsInput is List) {
        faqsList = faqsInput.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (faqsInput is String) {
        final decoded = jsonDecode(faqsInput);
        if (decoded is Map) {
          decoded.forEach((k, v) => faqsList
              .add({'question': k.toString(), 'answer': v?.toString() ?? ''}));
        } else if (decoded is List) {
          faqsList = List<Map<String, dynamic>>.from(decoded);
        }
      } else if (faqsInput is Map) {
        faqsInput.forEach((k, v) => faqsList
            .add({'question': k.toString(), 'answer': v?.toString() ?? ''}));
      }
    } catch (_) {}
    if (faqsList.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      icon: Icons.help_outline,
      title: l.faq,
      child: Column(
          children: List.generate(faqsList.length, (i) {
        final q = faqsList[i]['question'] ?? '';
        final a = faqsList[i]['answer'] ?? '';
        return _ExpandableFAQTile(
            question: q, answer: a, showDivider: i < faqsList.length - 1);
      })),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── INFO SECTION (Contact + Opening Hours + Languages)
  // ═══════════════════════════════════════════════════════
  Widget _buildInfoSection(String mobile, String email, String website,
      List phonesArray, dynamic openingHours, List<String> languages) {
    final l = AppLocalizations.of(context)!;
    final displayMobile =
        mobile.startsWith('00963') ? '0${mobile.substring(5)}' : mobile;

    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200, width: 0.8),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 Contact Information
          GestureDetector(
            onTap: () =>
                _showContactDetails(displayMobile, email, website, phonesArray),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.w, 12.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.contactInformation,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.viewMore,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.main,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? Icons.keyboard_arrow_left
                            : Icons.keyboard_arrow_right,
                        color: AppColors.main,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Divider(color: Colors.grey[200], thickness: 1),
          ),

          /// 🔹 Opening Hours
          GestureDetector(
            onTap: () => _showOpeningHoursSheet(openingHours),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.openingHours,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.viewMore,
                        style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.main, fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? Icons.keyboard_arrow_left
                            : Icons.keyboard_arrow_right,
                        color: AppColors.main,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Divider(color: Colors.grey[200], thickness: 1),
          ),

          /// 🔹 Languages
          GestureDetector(
            onTap: () => _showLanguagesSheet(languages),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language,
                          color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.languagesSpoken,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.viewMore,
                        style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.main, fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? Icons.keyboard_arrow_left
                            : Icons.keyboard_arrow_right,
                        color: AppColors.main,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDetails(
      String displayMobile, String email, String website, List phonesArray) {
    final l = AppLocalizations.of(context)!;
    final List<String> landlines = [];
    for (final p in phonesArray) {
      if (p is Map) {
        final cc = (p['city_code'] ?? '').toString().trim();
        final num = (p['number'] ?? '').toString().trim();
        if (num.isNotEmpty) landlines.add(cc.isNotEmpty ? '($cc) $num' : num);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  l.contactInformation,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                ),
              ),
              SizedBox(height: 25.h),
              if (displayMobile.isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('tel:$displayMobile')),
                  child: Row(
                    children: [
                      Icon(Icons.call, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(displayMobile, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main)),
                    ],
                  ),
                ),
              if (displayMobile.isNotEmpty) SizedBox(height: 16.h),
              if (landlines.isNotEmpty) ...[
                ...landlines.map((line) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$line')),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, color: AppColors.main, size: 16.sp),
                        SizedBox(width: 10.w),
                        Text(line, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main)),
                      ],
                    ),
                  ),
                )),
              ],
              if (email.isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('mailto:$email')),
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(email, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main)),
                    ],
                  ),
                ),
              if (email.isNotEmpty) SizedBox(height: 16.h),
              if (website.isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication),
                  child: Row(
                    children: [
                      Icon(Icons.language, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(website, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main)),
                    ],
                  ),
                ),
              SizedBox(height: 25.h),
            ],
          ),
        );
      },
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(children: [
        Icon(icon, size: 14.sp, color: AppColors.main),
        SizedBox(width: 8.w),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 2.h),
          Text(value,
              style: AppTextStyles.getText2(context)
                  .copyWith(fontWeight: FontWeight.w500),
              textDirection: TextDirection.ltr),
        ])),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(children: [
        Icon(icon, size: 14.sp, color: AppColors.mainDark),
        SizedBox(width: 6.w),
        Text(label,
            style: AppTextStyles.getText2(context)
                .copyWith(fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.main.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.main.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 14.sp, color: AppColors.mainDark),
          SizedBox(width: 6.w),
          Expanded(
              child: Text(label,
                  style: AppTextStyles.getText2(context)
                      .copyWith(fontWeight: FontWeight.w500))),
          Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
        ]),
      ),
    );
  }

  void _showOpeningHoursSheet(dynamic openingHours) {
    final l = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    Map<String, dynamic> hours = {};
    if (openingHours is Map)
      hours = Map<String, dynamic>.from(openingHours);
    else if (openingHours is String) {
      try {
        hours = Map<String, dynamic>.from(jsonDecode(openingHours));
      } catch (_) {}
    }

    final dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    // Also support full day names
    final fullDayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayNames = {
      'mon': isArabic ? 'الإثنين' : 'Monday',
      'tue': isArabic ? 'الثلاثاء' : 'Tuesday',
      'wed': isArabic ? 'الأربعاء' : 'Wednesday',
      'thu': isArabic ? 'الخميس' : 'Thursday',
      'fri': isArabic ? 'الجمعة' : 'Friday',
      'sat': isArabic ? 'السبت' : 'Saturday',
      'sun': isArabic ? 'الأحد' : 'Sunday',
      'monday': isArabic ? 'الإثنين' : 'Monday',
      'tuesday': isArabic ? 'الثلاثاء' : 'Tuesday',
      'wednesday': isArabic ? 'الأربعاء' : 'Wednesday',
      'thursday': isArabic ? 'الخميس' : 'Thursday',
      'friday': isArabic ? 'الجمعة' : 'Friday',
      'saturday': isArabic ? 'السبت' : 'Saturday',
      'sunday': isArabic ? 'الأحد' : 'Sunday',
    };

    // Determine which key set is used
    final useShortKeys = hours.keys.any((k) => dayOrder.contains(k));
    final keys = useShortKeys ? dayOrder : fullDayOrder;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      l.openingHours,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Column(
                    children: List.generate(keys.length, (index) {
                      final day = keys[index];
                      final val = hours[day];
                      String display = l.closed;
                      if (val is Map) {
                        final from = val['from'] ?? val['open'] ?? '';
                        final to = val['to'] ?? val['close'] ?? '';
                        if (from.toString().isNotEmpty && to.toString().isNotEmpty) {
                          display = '$from - $to';
                        }
                      } else if (val is List && val.isNotEmpty) {
                        display = val.map((slot) {
                          if (slot is Map) return '${slot['from'] ?? ''} - ${slot['to'] ?? ''}';
                          return slot.toString();
                        }).join(', ');
                      } else if (val is String && val.isNotEmpty) {
                        display = val;
                      }
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dayNames[day] ?? day,
                                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
                                Text(display,
                                    style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                        color: display == l.closed ? Colors.grey : AppColors.mainDark)),
                              ],
                            ),
                          ),
                          if (index < keys.length - 1)
                            Divider(thickness: 0.3, height: 6, color: Colors.grey[400]),
                        ],
                      );
                    }),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguagesSheet(List<String> languages) {
    final l = AppLocalizations.of(context)!;
    final langMap = {
      'Arabic': l.languageArabic,
      'English': l.languageEnglish,
      'French': l.languageFrench,
      'German': l.languageGerman,
      'Spanish': l.languageSpanish,
      'Turkish': l.languageTurkish,
      'Russian': l.languageRussian,
      'Kurdish': l.languageKurdish,
    };
    final translated = languages.map((lang) => langMap[lang] ?? lang).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  l.languagesSpoken,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                ),
              ),
              SizedBox(height: 20.h),
              Wrap(
                spacing: 12.w,
                runSpacing: 8.h,
                children: translated.map((lang) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, color: AppColors.main, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(lang, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500)),
                  ],
                )).toList(),
              ),
              SizedBox(height: 25.h),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── LOCATION SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildLocationSection(
      Map<String, dynamic> address, dynamic locationData) {
    final l = AppLocalizations.of(context)!;
    final street = (address['street'] ?? '').toString().trim();
    final buildingNr = (address['building_nr'] ?? address['buildingNr'] ?? '')
        .toString()
        .trim();
    final city = (address['city'] ?? '').toString().trim();
    final country = (address['country'] ?? '').toString().trim();
    final addressDetails = (address['details'] ?? '').toString().trim();
    final clinic = (_centerData?['name'] ?? '').toString().trim();

    double? lat, lng;
    if (locationData is Map) {
      lat = (locationData['lat'] as num?)?.toDouble();
      lng = (locationData['lng'] as num?)?.toDouble();
    }

    return GestureDetector(
      onTap: () => _showLocationDetails(
          clinic, street, buildingNr, city, country, addressDetails),
      child: Card(
        color: AppColors.background2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + "View More"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.location,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          l.viewMore,
                          style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.main,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? Icons.keyboard_arrow_left
                              : Icons.keyboard_arrow_right,
                          color: AppColors.main,
                          size: 18.sp,
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 8.h),

              if (clinic.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 2.h, right: 4.w, left: 4.w),
                  child: Text(
                    clinic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              if (street.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    buildingNr.isNotEmpty ? "$street, $buildingNr" : street,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.black87),
                  ),
                ),
              if (city.isNotEmpty && country.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    "$city, $country",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.black87),
                  ),
                ),

              SizedBox(height: 12.h),

              // Map Image + "Open in Maps" button
              if (lat != null && lng != null)
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.main, width: 1),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/map.webp'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mainDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                    ),
                    onPressed: () {
                      _openSingleOnMap();
                    },
                    icon: const Icon(Icons.location_on, color: Colors.white),
                    label: Text(
                      l.openInMaps,
                      style: AppTextStyles.getText2(context)
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Formats single map result for center
  Map<String, dynamic>? _singleMapResultForCenter() {
    final d = _centerData;
    if (d == null) return null;

    final loc = d['location'] as Map<String, dynamic>?;
    final lat = loc?['lat'];
    final lng = loc?['lng'];

    if (lat == null || lng == null) return null;

    return {
      'id': d['id'],
      'first_name': d['name'], // Centers just use name instead of first/last
      'last_name': '',
      'title': '',
      'gender': '',
      'specialty': '',
      'doctor_image': d['center_image'] ?? d['logo'],
      'address': d['address'],
      'location': {'lat': lat, 'lng': lng},
    };
  }

  // ✅ Opens built-in map page for center
  void _openSingleOnMap() {
    final item = _singleMapResultForCenter();
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.locationError)),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              FullMapResultsPage(results: [item], fromDoctorProfile: true)),
    );
  }

  void _showLocationDetails(String clinic, String street, String buildingNr,
      String city, String country, String addressDetails) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  AppLocalizations.of(context)!.location,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                ),
              ),
              SizedBox(height: 16.h),

              if (clinic.isNotEmpty)
                Text(
                  clinic,
                  style: AppTextStyles.getTitle1(context),
                ),

              if (street.isNotEmpty || buildingNr.isNotEmpty)
                Text(
                  buildingNr.isNotEmpty ? "$street, $buildingNr" : street,
                  style: AppTextStyles.getText2(context),
                ),
                
              if (city.isNotEmpty || country.isNotEmpty)
                Text(
                  [city, country].where((e) => e.isNotEmpty).join(", "),
                  style: AppTextStyles.getText2(context),
                ),

              SizedBox(height: 12.h),

              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.main, width: 1),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/map.webp'),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.center,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mainDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _openSingleOnMap();
                  },
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.openInMaps,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              if (addressDetails.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.additionalInformation,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.main,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.background3,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.main.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              addressDetails,
                              style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── INSURANCE SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildInsuranceSection(List<String> insurance) {
    final l = AppLocalizations.of(context)!;
    return _buildSectionCard(
      icon: Icons.verified_user_outlined,
      title: l.acceptedInsurance,
      child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: insurance
              .map((i) => Container(
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3))),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    child: Text(i,
                        style: AppTextStyles.getText2(context).copyWith(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500)),
                  ))
              .toList()),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── FACILITIES SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildFacilitiesSection(List<String> facilities) {
    final l = AppLocalizations.of(context)!;
    return _buildSectionCard(
      icon: Icons.local_parking_outlined,
      title: l.facilitiesAmenities,
      child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: facilities
              .map((f) => Container(
                    decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check, size: 12.sp, color: AppColors.mainDark),
                      SizedBox(width: 4.w),
                      Text(f,
                          style: AppTextStyles.getText2(context).copyWith(
                              color: AppColors.mainDark,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ))
              .toList()),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── SOCIAL MEDIA SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildSocialMediaSection(Map<String, dynamic> socialMedia) {
    final l = AppLocalizations.of(context)!;
    final icons = <String, IconData>{
      'facebook': Icons.facebook,
      'instagram': Icons.camera_alt_outlined,
      'twitter': Icons.close,
      'linkedin': Icons.link,
      'youtube': Icons.play_circle_outline,
      'tiktok': Icons.music_note,
      'whatsapp': Icons.chat_bubble_outline,
      'telegram': Icons.send,
    };

    final entries = socialMedia.entries
        .where((e) => (e.value ?? '').toString().trim().isNotEmpty)
        .toList();

    return _buildSectionCard(
      icon: Icons.share_outlined,
      title: l.socialMedia,
      child: Column(
          children: entries.map((e) {
        final url = e.value.toString().trim();
        return GestureDetector(
          onTap: () async {
            final uri =
                Uri.parse(url.startsWith('http') ? url : 'https://$url');
            if (await canLaunchUrl(uri))
              launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(children: [
              Icon(icons[e.key] ?? Icons.link,
                  size: 16.sp, color: AppColors.mainDark),
              SizedBox(width: 8.w),
              Expanded(
                  child: Text(e.key[0].toUpperCase() + e.key.substring(1),
                      style: AppTextStyles.getText2(context).copyWith(
                          color: AppColors.mainDark,
                          fontWeight: FontWeight.w500))),
              Icon(Icons.open_in_new, size: 12.sp, color: Colors.grey),
            ]),
          ),
        );
      }).toList()),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ── SHARED: Section Card Builder
  // ═══════════════════════════════════════════════════════
  Widget _buildSectionCard(
      {required IconData icon,
      required String title,
      required Widget child,
      VoidCallback? onViewMore}) {
    final l = AppLocalizations.of(context)!;
    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200, width: 0.8),
      ),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.mainDark, size: 16.sp),
            SizedBox(width: 5.w),
            Expanded(
                child: Text(title,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 11.sp))),
            if (onViewMore != null)
              GestureDetector(
                onTap: onViewMore,
                child: Text(l.viewMore,
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.main,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          SizedBox(height: 12.h),
          child,
        ]),
      ),
    );
  }

  void _showCenterDetails(String? description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.aboutCenter,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Builder(
                            builder: (context) {
                              try {
                                final decoded = jsonDecode(description);
                                
                                // ✅ Check for Version 3 (Multiple Sections)
                                if (decoded is Map && decoded['version'] == 3 && decoded['parts'] is List) {
                                  final parts = decoded['parts'] as List;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: parts.map<Widget>((part) {
                                      final title = part['title']?.toString() ?? '';
                                      final delta = part['delta'];
                                      
                                      if (delta == null) return const SizedBox.shrink();

                                      final doc = quill.Document.fromJson(delta);
                                      final controller = quill.QuillController(
                                        document: doc,
                                        selection: const TextSelection.collapsed(offset: 0),
                                        readOnly: true,
                                      );

                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 20.h),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (title.isNotEmpty)
                                              Padding(
                                                padding: EdgeInsets.only(bottom: 8.h),
                                                child: Text(
                                                  title,
                                                  style: AppTextStyles.getTitle1(context).copyWith(
                                                    fontSize: 14.sp,
                                                    color: AppColors.mainDark,
                                                  ),
                                                ),
                                              ),
                                            quill.QuillEditor.basic(
                                              controller: controller,
                                              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }

                                // ✅ Legacy (Simple Delta)
                                final doc = quill.Document.fromJson(decoded);
                                final controller = quill.QuillController(
                                  document: doc,
                                  selection: const TextSelection.collapsed(offset: 0),
                                  readOnly: true,
                                );

                                return quill.QuillEditor.basic(
                                  controller: controller,
                                  focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                                );
                              } catch (e) {
                                return Text(
                                  AppLocalizations.of(context)!.notProvided,
                                  style: AppTextStyles.getText3(context),
                                );
                              }
                            },
                          ),
                        ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════
// ── Expandable FAQ Tile
// ═══════════════════════════════════════════════════════
class _ExpandableFAQTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool showDivider;
  const _ExpandableFAQTile(
      {required this.question, required this.answer, this.showDivider = false});

  @override
  State<_ExpandableFAQTile> createState() => _ExpandableFAQTileState();
}

class _ExpandableFAQTileState extends State<_ExpandableFAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(children: [
          Expanded(
              child: Text(widget.question,
                  style: AppTextStyles.getText2(context)
                      .copyWith(fontWeight: FontWeight.w600))),
          Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18.sp, color: Colors.grey),
        ]),
      ),
      if (_expanded) ...[
        SizedBox(height: 6.h),
        Text(widget.answer,
            style: AppTextStyles.getText3(context)
                .copyWith(color: Colors.grey[600])),
      ],
      if (widget.showDivider)
        Divider(height: 20.h, color: Colors.grey.shade200),
    ]);
  }
}

class _CustomExpandableServiceTile extends StatefulWidget {
  final String title;
  final String description;

  const _CustomExpandableServiceTile({required this.title, required this.description});

  @override
  State<_CustomExpandableServiceTile> createState() => _CustomExpandableServiceTileState();
}

class _CustomExpandableServiceTileState extends State<_CustomExpandableServiceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.main, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.black45,
                  size: 20.sp,
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsetsDirectional.only(start: 36.w),
                child: Text(
                  widget.description,
                  style: AppTextStyles.getText3(context),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
