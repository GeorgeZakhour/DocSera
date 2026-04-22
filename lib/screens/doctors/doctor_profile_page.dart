import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/centers/center_profile_page.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/text_styles.dart';

// ✅ استيراد صفحة نتائج الخرائط
import 'package:docsera/screens/map_results_page.dart';

import '../../utils/full_page_loader.dart';

class DoctorProfilePage extends StatefulWidget {
  final String doctorId; // ✅ Make non-nullable
  final Map<String, dynamic>? doctor;
  final bool fromProfile;

  const DoctorProfilePage({
    super.key,
    required this.doctorId,
    this.doctor,
    this.fromProfile = false,
  });

  @override
  _DoctorProfilePageState createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  bool _showAppBar = false;
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _doctorData;
  String? _userId;

  List<Map<String, dynamic>> _centerMemberships = [];

  bool _expandedImageOverlay = false;
  List<String> _expandedImageUrls = [];
  int _initialImageIndex = 0;
  final TransformationController _transformationController = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  final Map<String, ImageProvider> _imageCache = {};
  double _buttonTopOffset = 0.0;
  bool _isOpeningImageOverlay = false;
  List<Map<String, dynamic>> _promotions = [];

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
    final stream = CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info);
    });

    stream.addListener(listener);
    final imageInfo = await completer.future;
    final byteData = await imageInfo.image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    if (mounted) {
      setState(() {
        _imageCache[url] = MemoryImage(bytes);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _userId = Supabase.instance.client.auth.currentUser?.id;

    debugPrint("🩺 DoctorProfilePage INIT - doctorId: ${widget.doctorId}");
    if (widget.doctor != null && widget.doctor!.isNotEmpty) {
      _doctorData = {...widget.doctor!};
    }
    _loadFavoriteStatus();
    _loadDoctorProfile();
    _loadCenterMemberships();
    _loadPromotions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _buttonTopOffset = _calculateButtonOffset();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorProfile() async {
    final doctorId = widget.doctorId.trim();
    if (doctorId.isEmpty) return;

    // 1️⃣ استخدم البيانات الممررة إن وُجدت
    if (widget.doctor != null && widget.doctor!.isNotEmpty) {
      _doctorData = Map<String, dynamic>.from(widget.doctor!);
    }

    // 2️⃣ fetch واحد فقط (authoritative)
    final response = await Supabase.instance.client
        .from('doctors')
        .select()
        .eq('id', doctorId)
        .maybeSingle();

    if (response != null && mounted) {
      setState(() {
        _doctorData = response;
      });
    }
  }

  Future<void> _loadCenterMemberships() async {
    final doctorId = widget.doctorId.trim();
    if (doctorId.isEmpty) return;
    try {
      final result = await Supabase.instance.client
          .rpc('get_doctor_centers', params: {'p_doctor_id': doctorId});

      final List<Map<String, dynamic>> centers =
          (result as List).cast<Map<String, dynamic>>();
      if (mounted && centers.isNotEmpty) {
        setState(() => _centerMemberships = centers);
      }
    } catch (_) {}
  }

  Future<void> _loadPromotions() async {
    final doctorId = widget.doctorId.trim();
    if (doctorId.isEmpty) return;
    try {
      final response = await Supabase.instance.client
          .from('doctor_promotions')
          .select()
          .eq('doctor_id', doctorId)
          .eq('is_active', true)
          .or('end_date.is.null,end_date.gt.${DateTime.now().toUtc().toIso8601String()}');

      if (mounted && response is List && response.isNotEmpty) {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (_) {}
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    double triggerOffset = MediaQuery.of(context).size.height * 0.30 - kToolbarHeight;

    if (offset >= triggerOffset && !_showAppBar) {
      setState(() => _showAppBar = true);
    } else if (offset < triggerOffset && _showAppBar) {
      setState(() => _showAppBar = false);
    }

    setState(() {
      _buttonTopOffset = _calculateButtonOffset();
    });
  }

  double _calculateButtonOffset() {
    double expandedHeight = MediaQuery.of(context).size.height * 0.30 + 24.h;
    double scroll = _scrollController.hasClients ? _scrollController.offset : 0.0;
    return expandedHeight - scroll;
  }

  String languageLabelFromCode(AppLocalizations l, String code) {
    switch (code) {
      case 'ar': return l.languageArabic;
      case 'en': return l.languageEnglish;
      case 'fr': return l.languageFrench;
      case 'de': return l.languageGerman;
      case 'es': return l.languageSpanish;
      case 'tr': return l.languageTurkish;
      case 'ru': return l.languageRussian;
      case 'ku': return l.languageKurdish;
      default:   return code;
    }
  }

  /// 🔹 Open phone dialer when clicking the phone number
  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _sendEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    await launchUrl(emailLaunchUri);
  }


  void _showGalleryBottomSheet(List<dynamic> galleryUrls, String doctorId) {
    final cleanedGalleryUrls = galleryUrls.map((e) => e.toString().split('/').last).toList();

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
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      itemCount: cleanedGalleryUrls.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8.w,
                        mainAxisSpacing: 8.h,
                      ),
                      itemBuilder: (_, index) {
                        final imageName = cleanedGalleryUrls[index];
                        final imagePath = '$doctorId/$imageName';
                        return GestureDetector(
                          onTap: () {
                            final fullUrls = cleanedGalleryUrls.map((name) => Supabase.instance.client.storage.from('doctor').getPublicUrl('$doctorId/$name')).toList();
                            _showImageOverlayWithIndex(fullUrls, index);
                            Navigator.pop(context);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: Image.network(
                              Supabase.instance.client.storage.from('doctor').getPublicUrl(imagePath),
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                          '${_initialImageIndex + 1} ${AppLocalizations.of(context)!.ofText} ${_expandedImageUrls.length}',
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
                          final zoomed = _transformationController.value != Matrix4.identity();
                          if (zoomed) {
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

  // ✅ تجهيز عنصر واحد لصفحة الخرائط من بيانات هذا الطبيب
  Map<String, dynamic>? _singleMapResultForDoctor() {
    final d = _doctorData;
    if (d == null) return null;

    final loc = d['location'] as Map<String, dynamic>?;
    final lat = loc?['lat'];
    final lng = loc?['lng'];

    if (lat == null || lng == null) return null;

    return {
      'id': d['id'],
      'first_name': d['first_name'],
      'last_name': d['last_name'],
      'title': d['title'],
      'gender': d['gender'],        // ← ADD THIS LINE
      'specialty': d['specialty'],
      'doctor_image': d['doctor_image'],
      'address': d['address'],
      'location': {'lat': lat, 'lng': lng},
    };
  }


  // ✅ يفتح صفحة الخرائط لعنصر واحد فقط
  void _openSingleOnMap() {
    final item = _singleMapResultForDoctor();
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.locationError)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullMapResultsPage(results: [item], fromDoctorProfile: true)),
    );
  }

  void _showLocationDetails(
      String? clinic,
      String? street,
      String? buildingNr,
      String? city,
      String? country,
      String? details,
      ) {
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

              if (clinic != null)
                Text(
                  clinic,
                  style: AppTextStyles.getTitle1(context),
                ),

              if (street != null)
                Text(
                  buildingNr != null ? "$street, $buildingNr" : street,
                  style: AppTextStyles.getText2(context),
                ),
              if (city != null && country != null)
                Text(
                  "$city, $country",
                  style: AppTextStyles.getText2(context),
                ),

              SizedBox(height: 12.h),

              // ✅ نفس صورة الخريطة المستخدمة في البحث المتقدّم + إطار رفيع Main
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
                  onPressed: _openSingleOnMap,
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.openInMaps,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              if (details != null)
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
                        border: Border.all(color: AppColors.main.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              details,
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

  void _showProfileDetails(String? profileDescription, List<String>? specialties, String? website) {
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
                    AppLocalizations.of(context)!.profile,
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
                      if (profileDescription != null && profileDescription.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Builder(
                            builder: (context) {
                              try {
                                final decoded = jsonDecode(profileDescription);
                                
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
                      SizedBox(height: 16.h),

                      if (website != null && website.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.website,
                              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _openWebsite(website),
                              child: Text(
                                AppLocalizations.of(context)!.openWebsite,
                                style: AppTextStyles.getTitle1(context).copyWith(
                                  fontSize: 14.sp,
                                  color: AppColors.main,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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

  void _openWebsite(String url) async {
    Uri websiteUri = Uri.parse(url);
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildPromotionsSection(List<Map<String, dynamic>> promotions) {
    if (promotions.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.main.withOpacity(0.2), width: 0.8),
      ),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                  l.offers,
                  style: AppTextStyles.getTitle1(context)
                      .copyWith(fontSize: 11.sp),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Offer items
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: promotions.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final promo = promotions[index];
                return _buildPromotionItem(promo, l, isAr);
              },
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
    final customTitle = promo['custom_title'] as String?;
    final customTitleAr = promo['custom_title_ar'] as String?;
    final description = promo['description'] as String?;
    final descriptionAr = promo['description_ar'] as String?;
    final audience = promo['audience'] as String? ?? 'all_patients';
    final endDate = promo['end_date'] as String?;
    final currency = l.currency;

    // Localized title
    String title;
    if (offerType == 'custom') {
      if (isAr && customTitleAr != null && customTitleAr.isNotEmpty) {
        title = customTitleAr;
      } else if (customTitle != null && customTitle.isNotEmpty) {
        title = customTitle;
      } else {
        title = customTitleAr ?? l.offers;
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
          title = '${discountValue?.toInt() ?? 0} $currency ${l.fixedDiscount}';
          break;
        case 'free_followup':
          title = l.freeFollowup;
          break;
        default:
          title = l.specialOffer;
      }
    }

    // Description
    final desc = isAr
        ? (descriptionAr ?? description)
        : (description ?? descriptionAr);

    // Icon and color per type
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

    // Check if limited time
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showClaimPromotionDialog(promo, title, desc, color, icon),
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              color: color.withOpacity(0.05),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.85),
                        color.withOpacity(0.45),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18.sp),
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
                    if (desc != null && desc.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        desc,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection:
                            isAr ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ],
                    if (audience == 'new_patients_only' || expiryText != null) ...[
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [
                          if (audience == 'new_patients_only')
                            _promoTag(l.newPatientsOnly, Colors.blue),
                          if (expiryText != null)
                            _promoTag(expiryText, Colors.orange),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
        // Eligibility info text
        Padding(
          padding: EdgeInsets.only(top: 6.h, left: 4.w, right: 4.w, bottom: 4.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 13.sp, color: Colors.grey[400]),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  _getPromotionInfoText(promo, l),
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
    );
  }

  String _getPromotionInfoText(Map<String, dynamic> promo, AppLocalizations l) {
    final offerType = promo['offer_type'] as String? ?? '';
    final maxPerPatient = promo['max_claims_per_patient'] as int?;

    if (offerType == 'free_first_consultation') {
      return '${l.promotionFirstVisitOnly} ${l.promotionPressHereToClaim}';
    }
    if (maxPerPatient != null && maxPerPatient == 1) {
      return '${l.promotionSingleUse} ${l.promotionPressHereToClaim}';
    }
    if (maxPerPatient != null && maxPerPatient > 1) {
      return '${l.promotionMultiUse(maxPerPatient)} ${l.promotionPressHereToClaim}';
    }
    return l.promotionPressHereToClaim;
  }

  void _showClaimPromotionDialog(
    Map<String, dynamic> promo,
    String title,
    String? description,
    Color color,
    IconData icon,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showLoginPromptDialog();
      return;
    }

    final l = AppLocalizations.of(context)!;
    final promoId = promo['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClaimPromotionSheet(
        promoId: promoId,
        title: title,
        description: description,
        color: color,
        icon: icon,
        local: l,
      ),
    );
  }

  Widget _promoTag(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.20)),
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

  Widget _buildPricingSection(List<dynamic> pricingList) {
    if (pricingList.isEmpty) return const SizedBox.shrink();

    final validItems = pricingList
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money_rounded, color: AppColors.mainDark, size: 16.sp),
                SizedBox(width: 5.w),
                Text(
                  l.pricing,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: validItems.length,
              separatorBuilder: (_, __) => Divider(
                height: 16.h,
                color: Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final item = validItems[index];
                final serviceName = (item['service'] ?? '').toString();
                final amount = (item['amount'] ?? '').toString();
                final currencyCode = (item['currency'] ?? '').toString();

                final currencyLabel = currencyCode == 'SYP'
                    ? l.currencySYPName
                    : (currencyCode == 'USD' ? l.currencyUSDName : currencyCode);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.main, size: 16.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            amount,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.main,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            currencyLabel,
                            style: AppTextStyles.getText3(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.mainDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection(List<dynamic> galleryUrls) {
    final String? doctorId = _doctorData?['id']?.toString();
    if (doctorId == null) return const SizedBox.shrink();

    final cleanedGalleryUrls = galleryUrls.map((e) => e.toString().split('/').last).toList();
    final previewImages = cleanedGalleryUrls.take(4).toList();
    final extraCount = cleanedGalleryUrls.length > 4 ? cleanedGalleryUrls.length - 3 : 0;

    final fullUrls = cleanedGalleryUrls
        .map((name) => Supabase.instance.client.storage.from('doctor').getPublicUrl('$doctorId/$name'))
        .toList();

    return GestureDetector(
      onTap: () => _showGalleryBottomSheet(galleryUrls, doctorId),
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
                  Icon(Icons.photo_library_outlined, color: AppColors.mainDark, size: 16.sp),
                  SizedBox(width: 5.w),
                  Text(
                    AppLocalizations.of(context)!.gallery,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
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
                  final imageName = previewImages[index];
                  final imagePath = '$doctorId/$imageName';

                  return GestureDetector(
                    onTap: () {
                      if (index < 3 || extraCount == 0) {
                        _showImageOverlayWithIndex(fullUrls, index);
                      } else {
                        _showGalleryBottomSheet(galleryUrls, doctorId);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.network(
                            Supabase.instance.client.storage.from('doctor').getPublicUrl(imagePath),
                            fit: BoxFit.cover,
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
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp),
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

  Widget _buildLocationSection(
      String? street,
      String? buildingNr,
      String? city,
      String? country,
      String? addressDetails,
      Map<String, dynamic>? address,
      String? clinic,
      ) {
    return GestureDetector(
      onTap: () => _showLocationDetails(clinic, street, buildingNr, city, country, addressDetails),
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
              // العنوان + "المزيد"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        AppLocalizations.of(context)!.location,
                        style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  if (address != null)
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

              if (clinic != null && clinic.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 2.h, right: 4.w, left: 4.w),
                  child: Text(
                    clinic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              if (street != null)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    buildingNr != null ? "$street, $buildingNr" : street,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                  ),
                ),
              if (city != null && country != null)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w, left: 8.w),
                  child: Text(
                    "$city, $country",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                  ),
                ),

              SizedBox(height: 12.h),

              // صورة الخريطة + زر "افتح في الخرائط"
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
                  onPressed: _openSingleOnMap,
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.openInMaps,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildProfileSection(String? profileDescription, List<String>? specialties, String? website) {
    if (profileDescription == null || profileDescription.isEmpty) {
      if ((specialties == null || specialties.isEmpty) && (website == null || website.isEmpty)) {
        return const SizedBox.shrink(); // Hide if completely empty
      }
    }

    // 🔹 Parse Profile Description (Check for v3)
    String plainTextSummary = '';
    bool isV3 = false;

    if (profileDescription != null && profileDescription.isNotEmpty) {
      try {
        final decoded = jsonDecode(profileDescription);
         if (decoded is Map && decoded['version'] == 3 && decoded['parts'] is List) {
           isV3 = true;
           final parts = decoded['parts'] as List;
           if (parts.isNotEmpty) {
             // Try to get text from the first part for the summary
             final firstPart = parts[0];
             if (firstPart['delta'] != null) {
                final doc = quill.Document.fromJson(firstPart['delta']);
                plainTextSummary = doc.toPlainText().trim();
             }
           }
         } else {
           // Legacy (v1/v2 - single delta)
           final doc = quill.Document.fromJson(decoded);
           plainTextSummary = doc.toPlainText().trim();
         }
      } catch (e) {
         plainTextSummary = AppLocalizations.of(context)!.notProvided;
      }
    }


    List<String> visibleSpecialties = [];
    String moreSpecialties = '';

    if (specialties != null && specialties.isNotEmpty) {
      if (specialties.length > 3) {
        visibleSpecialties = specialties.take(3).toList();
        moreSpecialties = "+${specialties.length - 3}";
      } else {
        visibleSpecialties = specialties;
      }
    }

    return GestureDetector(
      onTap: () => _showProfileDetails(profileDescription, specialties, website),
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
                  // العنوان + "عرض المزيد"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: AppColors.mainDark, size: 16.sp),
                          SizedBox(width: 5.w),
                          Text(
                            AppLocalizations.of(context)!.profile,
                            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
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

                  if (plainTextSummary.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h, right: 12.w, left: 12.w, bottom: 8.h),
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

  Widget _buildServicesSection(dynamic servicesInput) {
    if (servicesInput == null) return const SizedBox.shrink();

    List<Map<String, dynamic>> servicesList = [];
    
    try {
      if (servicesInput is List) {
         servicesList = servicesInput.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (servicesInput is String) {
        // Try parsing JSON string
        final decoded = jsonDecode(servicesInput);
         if (decoded is Map) {
          decoded.forEach((key, value) {
             servicesList.add({'title': key.toString(), 'description': value?.toString() ?? ''});
          });
        } else if (decoded is List) {
           servicesList = List<Map<String, dynamic>>.from(decoded);
        }
      } else if (servicesInput is Map) {
         servicesInput.forEach((key, value) {
           servicesList.add({'title': key.toString(), 'description': value?.toString() ?? ''});
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
              // العنوان
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services_outlined, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        AppLocalizations.of(context)!.offeredServices,
                        style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.viewMore,
                        style: AppTextStyles.getText3(context)
                            .copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
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
                  child: Text(
                    "• $title",
                    style: AppTextStyles.getText3(context),
                  ),
                );
              }),
              if (servicesList.length > 2)
                Text(
                  "+${servicesList.length - 2} ${AppLocalizations.of(context)!.showMore}",
                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark),
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

                        final bullet =
                        Icon(Icons.check_circle_outline, color: AppColors.main, size: 18.sp);

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
                                    style: AppTextStyles.getText2(context)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return _CustomExpandableServiceTile(
                            title: title, description: description);
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

  /// تحويل رقم الهاتف إلى صيغة 09XXXXXXXX
  String _displayPhone(String raw) {
    if (raw.startsWith('00963')) {
      final rest = raw.substring(5);
      return '0$rest';
    }
    if (raw.startsWith('+963')) {
      final rest = raw.substring(4);
      return '0$rest';
    }
    return raw;
  }

  /// 🔹 Card for Contact Info + Opening Hours + Languages
  String _getCenterImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    try {
      return Supabase.instance.client.storage
          .from('center-images')
          .getPublicUrl(path);
    } catch (_) {
      return '';
    }
  }

  Widget _buildWorksAtSection(List<Map<String, dynamic>> centers) {
    final l = AppLocalizations.of(context)!;
    return Card(
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
            Row(
              children: [
                Icon(Icons.business, color: AppColors.mainDark, size: 16.sp),
                SizedBox(width: 5.w),
                Text(
                  l.worksAt,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...centers.map((center) {
              final name = center['name'] ?? '';
              final imagePath = (center['center_image'] ?? '').toString();
              final imageUrl = _getCenterImageUrl(imagePath);
              final addr = center['address'] as Map<String, dynamic>?;
              final city = addr?['city'] ?? '';
              return InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: () {
                  if (widget.fromProfile) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CenterProfilePage(
                          centerId: center['id'],
                          fromProfile: true,
                          fromDoctorId: widget.doctorId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CenterProfilePage(
                          centerId: center['id'],
                          fromProfile: true,
                          fromDoctorId: widget.doctorId,
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: AppColors.main.withValues(alpha: 0.1),
                        backgroundImage: imageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(imageUrl)
                            : null,
                        child: imageUrl.isEmpty
                            ? Icon(Icons.business, color: AppColors.main, size: 20.sp)
                            : null,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                            ),
                            if (city.isNotEmpty)
                              Text(
                                city,
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: Colors.grey,
                                  fontSize: 10.sp,
                                ),
                              ),
                          ],
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
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Public contact fields (set by doctor in DocSera Pro's contact section).
  /// Falls back to auth fields only if public ones are empty.
  String? get _publicPhone {
    final pub = (_doctorData?['contact_mobile'] ?? '').toString().trim();
    return pub.isNotEmpty ? pub : null;
  }

  String? get _publicEmail {
    final pub = (_doctorData?['contact_email'] ?? '').toString().trim();
    return pub.isNotEmpty ? pub : null;
  }

  String? get _publicWebsite {
    final w = (_doctorData?['contact_website'] ?? '').toString().trim();
    return w.isNotEmpty ? w : null;
  }

  List<String> get _publicLandlines {
    final phones = _doctorData?['contact_phones'];
    if (phones is! List || phones.isEmpty) return [];
    final result = <String>[];
    for (final p in phones) {
      if (p is Map) {
        final cc = (p['city_code'] ?? '').toString().trim();
        final num = (p['number'] ?? '').toString().trim();
        if (num.isNotEmpty) {
          result.add(cc.isNotEmpty ? '\u200E($cc) $num' : num);
        }
      }
    }
    return result;
  }

  bool get _hasAnyContactInfo =>
      (_publicPhone ?? '').isNotEmpty ||
      (_publicEmail ?? '').isNotEmpty ||
      _publicLandlines.isNotEmpty ||
      _publicWebsite != null ||
      _centerPhoneNumber != null;

  /// Returns the first non-empty phone number from the doctor's centers.
  /// Prefers mobile_number → phone_number → first landline from phones array.
  String? get _centerPhoneNumber {
    for (final c in _centerMemberships) {
      final mobile = (c['mobile_number'] ?? '').toString().trim();
      if (mobile.isNotEmpty) return mobile;
      final phone = (c['phone_number'] ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;
      // Fallback to first landline from phones array
      final phones = c['phones'];
      if (phones is List && phones.isNotEmpty) {
        final first = phones[0];
        if (first is Map) {
          final cc = (first['city_code'] ?? '').toString().trim();
          final num = (first['number'] ?? '').toString().trim();
          if (num.isNotEmpty) return cc.isNotEmpty ? '\u200E($cc) $num' : num;
        }
      }
    }
    return null;
  }

  Widget _buildInfoSection(
      String? phoneNumber,
      Map<String, dynamic> openingHours,
      List<dynamic> languages,
      {String? email, String? centerPhone,
       List<String> landlines = const [], String? website}
      ) {
    final l = AppLocalizations.of(context)!;

    final hasContact = _hasAnyContactInfo;
    final hasHours = openingHours.isNotEmpty;
    final hasLanguages = languages.isNotEmpty;

    final visibleCount = [hasContact, hasHours, hasLanguages].where((v) => v).length;
    if (visibleCount == 0) return const SizedBox.shrink();

    // Scale vertical spacing based on how many sections are visible
    final double rowVerticalPadding = visibleCount == 1 ? 6.h : 4.h;
    final double cardVerticalPadding = visibleCount == 1 ? 14.w : 12.w;

    Widget buildRow(IconData icon, String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: rowVerticalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.mainDark, size: 16.sp),
                  SizedBox(width: 5.w),
                  Text(
                    label,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
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
      );
    }

    final rows = <Widget>[];
    if (hasContact) {
      rows.add(buildRow(Icons.phone, l.contactInformation,
          () => _showContactDetails(phoneNumber, email: email, centerPhone: centerPhone, landlines: landlines, website: website)));
    }
    if (hasHours) {
      rows.add(buildRow(Icons.access_time, l.openingHours,
          () => _showOpeningHoursDetails(openingHours)));
    }
    if (hasLanguages) {
      rows.add(buildRow(Icons.language, l.languagesSpoken,
          () => _showLanguagesDetails(languages)));
    }

    // Interleave dividers between rows
    final children = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(Divider(color: Colors.grey[200], thickness: 1));
      }
    }

    return Card(
      color: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200, width: 0.8),
      ),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: cardVerticalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }


  void _showContactDetails(String? phoneNumber, {
    String? email, String? centerPhone,
    List<String> landlines = const [], String? website,
  }) {
    final l = AppLocalizations.of(context)!;

    String formatPhone(String raw) {
      if (raw.startsWith('00963')) return '0${raw.substring(5)}';
      if (raw.startsWith('+963')) return '0${raw.substring(4)}';
      return raw;
    }

    final formattedPhone = phoneNumber != null && phoneNumber.isNotEmpty
        ? formatPhone(phoneNumber)
        : null;
    final formattedCenterPhone = centerPhone != null && centerPhone.isNotEmpty
        ? formatPhone(centerPhone)
        : null;
    final formattedEmail = (email ?? '').trim();

    final hasDirectPhone = formattedPhone != null && formattedPhone.isNotEmpty;
    final hasCenterPhone = formattedCenterPhone != null && formattedCenterPhone.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
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

              // Doctor's mobile
              if (hasDirectPhone)
                GestureDetector(
                  onTap: () => _makePhoneCall(formattedPhone),
                  child: Row(
                    children: [
                      Icon(Icons.smartphone, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        formattedPhone,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                    ],
                  ),
                ),

              if (hasDirectPhone)
                SizedBox(height: 16.h),

              // Landline numbers
              ...landlines.map((line) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: GestureDetector(
                  onTap: () => _makePhoneCall(line),
                  child: Row(
                    children: [
                      Icon(Icons.phone_outlined, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        line,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                    ],
                  ),
                ),
              )),

              // Center phone
              if (hasCenterPhone && (!hasDirectPhone || formattedCenterPhone != formattedPhone))
                GestureDetector(
                  onTap: () => _makePhoneCall(formattedCenterPhone),
                  child: Row(
                    children: [
                      Icon(Icons.business, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        formattedCenterPhone,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '(${l.centerPhone})',
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              if (hasCenterPhone && (!hasDirectPhone || formattedCenterPhone != formattedPhone))
                SizedBox(height: 16.h),

              // Email
              if (formattedEmail.isNotEmpty)
                GestureDetector(
                  onTap: () => _sendEmail(formattedEmail),
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        formattedEmail,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                    ],
                  ),
                ),

              if (formattedEmail.isNotEmpty)
                SizedBox(height: 16.h),

              // Website
              if (website != null && website.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final url = website.startsWith('http') ? website : 'https://$website';
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.language, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        website,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
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


  void _showOpeningHoursDetails(Map<String, dynamic> openingHours) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l = AppLocalizations.of(context)!;

    final daysMap = {
      "mon": isArabic ? "الإثنين" : "Monday",
      "tue": isArabic ? "الثلاثاء" : "Tuesday",
      "wed": isArabic ? "الأربعاء" : "Wednesday",
      "thu": isArabic ? "الخميس" : "Thursday",
      "fri": isArabic ? "الجمعة" : "Friday",
      "sat": isArabic ? "السبت" : "Saturday",
      "sun": isArabic ? "الأحد" : "Sunday",
    };

    final days = daysMap.keys.toList();
    final currentDay = days[DocSeraTime.nowSyria().weekday - 1];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    children: List.generate(days.length, (index) {
                      final day = days[index];
                      final slots = openingHours[day] as List<dynamic>?;
                      final isToday = (day == currentDay);
                      final color = isToday ? AppColors.main : Colors.black87;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  daysMap[day] ?? day,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: color,
                                  ),
                                ),
                                const Spacer(),
                                (slots != null && slots.isNotEmpty)
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: slots.map((slot) {
                                    final slotMap = slot as Map<String, dynamic>;
                                    final from = _pretty12(context, slotMap["from"] ?? '');
                                    final to   = _pretty12(context, slotMap["to"] ?? '');
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                                      child: Text(
                                        "$from - $to",
                                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                                    : Text(
                                  l.closed,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < days.length - 1)
                            Divider(
                              thickness: 0.3,
                              height: 6,
                              color: Colors.grey[400],
                            ),
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

  String _pretty12(BuildContext ctx, String hhmm) {
    try {
      // أزل أي إضافات مثل "ص" أو "م" لو كانت موجودة
      hhmm = hhmm.trim().split(' ').first;

      final parts = hhmm.split(':');
      if (parts.length != 2) return hhmm;

      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);

      final tod = TimeOfDay(hour: h, minute: m);
      return MaterialLocalizations.of(ctx).formatTimeOfDay(
        tod,
        alwaysUse24HourFormat: false,
      );
    } catch (_) {
      return hhmm;
    }
  }


  void _showLanguagesDetails(List<dynamic> languages) {
    final l = AppLocalizations.of(context)!;

    // تحويل أكواد اللغات إلى نصوص محلية من ARB
    final translatedLanguages = languages.map((code) => languageLabelFromCode(l, code.toString())).toList();

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
                  AppLocalizations.of(context)!.languagesSpoken,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                ),
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: translatedLanguages.map((language) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.main.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    child: Text(
                      language,
                      style: AppTextStyles.getText2(context)
                          .copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 15.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFAQsSection(dynamic faqsInput) {
    if (faqsInput == null) return const SizedBox.shrink();

    List<Map<String, dynamic>> faqsList = [];

    try {
      if (faqsInput is List) {
        faqsList = faqsInput.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (faqsInput is String) {
        // Try parsing JSON string
        final decoded = jsonDecode(faqsInput);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            faqsList.add({'question': key.toString(), 'answer': value?.toString() ?? ''});
          });
        } else if (decoded is List) {
          faqsList = List<Map<String, dynamic>>.from(decoded);
        }
      } else if (faqsInput is Map) {
        faqsInput.forEach((key, value) {
          faqsList.add({'question': key.toString(), 'answer': value?.toString() ?? ''});
        });
      }
    } catch (e) {
      debugPrint("❌ Error parsing FAQs: $e");
    }

    if (faqsList.isEmpty) return const SizedBox.shrink();

    return Card(
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
                Icon(Icons.help_outline, color: AppColors.mainDark, size: 16.sp),
                SizedBox(width: 5.w),
                Text(
                  AppLocalizations.of(context)!.faq,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
            SizedBox(height: 15.h),
            ...List.generate(faqsList.length, (index) {
              final question = faqsList[index]['question'] ?? '';
              final answer = faqsList[index]['answer'] ?? '';

              return _ExpandableFAQTile(
                question: question,
                answer: answer,
                showDivider: index < faqsList.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .rpc('rpc_get_my_favorite_doctors');

    if (res is! List) {
      setState(() => _isFavorite = false);
      return;
    }

    final isFav = res.any(
          (d) => d['id'] == widget.doctorId,
    );

    setState(() {
      _isFavorite = isFav;
    });
  }

  Future<void> _toggleFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showLoginPromptDialog();
      return;
    }

    final res = await Supabase.instance.client.rpc(
      'toggle_favorite_doctor',
      params: {'p_doctor_id': widget.doctorId},
    );

    if (res is bool) {
      setState(() {
        _isFavorite = res;
      });
    }
  }


  void _showLoginPromptDialog() {
    final l = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.background2,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 10.h),
                    Icon(Icons.login, color: AppColors.main, size: 32.sp),
                    SizedBox(height: 10.h),

                    // العنوان
                    Text(
                      l.pleaseLoginToContinue,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20.h),

                    // زر تسجيل الدخول
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        minimumSize: Size(double.infinity, 48.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LogInPage()),
                        );
                      },
                      child: Text(
                        l.login,
                        style: TextStyle(fontSize: 12.sp, color: Colors.white),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // النص + الزر في نفس السطر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.noAccountQuestion, // "ليس لديك حساب؟"
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SignUpFirstPage(signUpInfo: SignUpInfo()),
                              ),
                            );
                          },
                          child: Text(
                            l.signUp, // "أنشئ حساباً الآن"
                            style: TextStyle(fontSize: 11.sp, color: AppColors.main),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // زر الإغلاق (أقرب للزاوية)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, size: 20.sp, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDoctorQrSheet() {
    final token = _doctorData?['public_token'];
    if (token == null || token.isEmpty) return;

    final deepLink = 'docsera://doctor/$token';
    final l = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.background2.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(
                color: AppColors.main.withOpacity(0.25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 20.h),

                // ── Title
                Text(
                  l.shareDoctorProfile,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp),
                ),
                SizedBox(height: 20.h),

                // ── QR
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: QrImageView(
                    data: deepLink,
                    version: QrVersions.auto,
                    size: 200.w,
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Hint
                Text(
                  l.scanToOpenInApp,
                  style: AppTextStyles.getText3(context),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 20.h),

                // ── Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.copy, size: 16.sp, color: AppColors.mainDark),
                        label: Text(l.copyLink, style: const TextStyle(color: AppColors.mainDark),),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: deepLink));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                backgroundColor: AppColors.main.withOpacity(0.8),
                                content: Text(l.linkCopied)
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.share, size: 16.sp),
                        label: Text(l.share),
                        onPressed: () {
                          _shareDoctorLink();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareDoctorLink() {
    if (_doctorData == null) return;

    final l = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final token = _doctorData?['public_token'];
    if (token == null || token.isEmpty) return;

    final deepLink = 'docsera://doctor/$token';

    final doctorName =
    "${_doctorData?['title'] ?? ''} ${_doctorData?['first_name'] ?? ''} ${_doctorData?['last_name'] ?? ''}"
        .trim();

    final specialty =
        _doctorData?['specialty'] ?? l.unknownSpecialty;

    final text = isArabic
        ? '''
👨‍⚕️ $doctorName
💼 $specialty

افتح ملف الطبيب مباشرة على تطبيق DocSera:
$deepLink
'''
        : '''
👨‍⚕️ $doctorName
💼 $specialty

Open the doctor profile directly in DocSera:
$deepLink
''';

    // 🔴 الحل هنا
    final box = context.findRenderObject() as RenderBox?;

    Share.share(
      text,
      subject: isArabic
          ? 'ملف الطبيب على DocSera'
          : 'Doctor Profile on DocSera',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 1, 1),
    );
  }


  @override
  Widget build(BuildContext context) {
    final doctor = _doctorData ?? {};
    String gender = doctor['gender']?.toLowerCase() ?? 'male';
    String title = doctor['title']?.toLowerCase() ?? '';
    Map<String, dynamic>? address = doctor['address'];
    String? street = address?['street'];
    String? buildingNr = address?['buildingNr']?.toString();
    String? city = address?['city'];
    String? country = address?['country'];
    String? addressDetails = address?['details'];
    String? clinic = doctor['clinic'];
    final String? Reason;
    final String? ReasonId;
    final Map<String, dynamic>? location;


    String? imagePath = doctor['doctor_image'];
    debugPrint('📷 RAW doctor_image = "$imagePath"');

    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final doctorAvatarWidget = imageResult.widget;

    final String? profileDescription = doctor['profile_description'];
    final List<String>? specialties = (doctor['specialties'] as List<dynamic>?)?.cast<String>();
    final String? website = doctor['website'];

    if (widget.doctorId.isEmpty) {
      debugPrint("❌ ERROR: doctorId is unexpectedly empty inside DoctorProfilePage");
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Doctor ID is missing. Cannot load profile.")),
      );
    }

    final doctorId = widget.doctorId;
    final doctorFirstName = _doctorData?['first_name'] ?? '';
    final doctorLastName = _doctorData?['last_name'] ?? '';
    final doctorGender = _doctorData?['gender'] ?? '';
    final doctorTitle = _doctorData?['title'] ?? '';
    final doctorSpecialty = _doctorData?['specialty'] ?? '';
    final clinicName = _doctorData?['clinic'] ?? '';
    // final clinicAddress = _doctorData?['address'] ?? {};


// --- Address (could be a JSON string or a Map) ---
    final Map<String, dynamic> clinicAddress = (() {
      final raw = _doctorData?['address'];
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {
          return <String, dynamic>{};
        }
      } else if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      } else {
        return <String, dynamic>{};
      }
    })();

// --- Location (lat/lng) (could be a JSON string or a Map) ---
// --- Location (lat/lng) (could be a JSON string or a Map) ---
    final Map<String, dynamic> clinicLocation = (() {
      final raw = _doctorData?['location'];
      Map<String, dynamic> out;
      if (raw is String) {
        try {
          out = Map<String, dynamic>.from(jsonDecode(raw));
          debugPrint("🌍 [DoctorProfilePage] Location raw (String) decoded = $out");
        } catch (_) {
          debugPrint("❌ [DoctorProfilePage] Failed to decode location JSON: $raw");
          out = <String, dynamic>{};
        }
      } else if (raw is Map) {
        out = Map<String, dynamic>.from(raw);
        debugPrint("🌍 [DoctorProfilePage] Location raw (Map) = $out");
      } else {
        debugPrint("⚠️ [DoctorProfilePage] No location data found (raw=$raw)");
        out = <String, dynamic>{};
      }

      // Normalize types to double if present
      double? lat;
      double? lng;
      final rawLat = out['lat'];
      final rawLng = out['lng'];
      if (rawLat is num) lat = rawLat.toDouble();
      if (rawLng is num) lng = rawLng.toDouble();
      lat ??= double.tryParse(rawLat?.toString() ?? '');
      lng ??= double.tryParse(rawLng?.toString() ?? '');

      final normalized = {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

      debugPrint("✅ [DoctorProfilePage] Normalized clinicLocation = $normalized");
      return normalized;
    })();



    double offset = _scrollController.hasClients ? _scrollController.offset : 0;
    double fadeStart = 100;
    double fadeEnd = MediaQuery.of(context).size.height * 0.15;
    double opacity = 1.0;
    int visibleSections = 0;

    if (_doctorData?['gallery'] != null && (_doctorData!['gallery'] as List).isNotEmpty) {
      visibleSections++;
    }
    if (profileDescription != null || (specialties != null && specialties.isNotEmpty)) {
      visibleSections++;
    }
    if (_doctorData?['offered_services'] != null) {
      // Basic check, _buildServicesSection handles empty/invalid types gracefully
      visibleSections++;
    }
    if (street != null || city != null || country != null) {
      visibleSections++;
    }
    if (_doctorData?['opening_hours'] != null || _doctorData?['languages'] != null || _hasAnyContactInfo) {
      visibleSections++;
    }
    if (_doctorData?['faqs'] != null) {
      visibleSections++;
    }


    if (offset <= fadeStart) {
      opacity = 1.0;
    } else if (offset >= fadeEnd) {
      opacity = 0.0;
    } else {
      opacity = 1.0 - ((offset - fadeStart) / (fadeEnd - fadeStart));
    }

    double bottomButtonOpacity = (1.0 - opacity).clamp(0.0, 1.0);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background4,
      body: Stack(
        children: [
          Text("Doctor ID: ${widget.doctorId ?? 'No ID'}"),
          (_doctorData == null || _doctorData!.isEmpty)
              ? const Center(child: FullPageLoader())
              : CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.30,
                pinned: true,
                floating: false,
                elevation: 0,
                backgroundColor: AppColors.main,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: AppColors.whiteText, size: 16.sp),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  if (_userId != null)
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.star : Icons.star_border,
                        color: AppColors.whiteText,
                      ),
                      onPressed: _toggleFavoriteStatus,
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_rounded, color: AppColors.whiteText),
                    onPressed: _showDoctorQrSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: AppColors.whiteText),
                    onPressed: _shareDoctorLink,
                  ),
                ],


                flexibleSpace: FlexibleSpaceBar(
                  title: Opacity(
                    opacity: _showAppBar ? 1.0 : 0.0,
                    child: Text(
                      "${_doctorData?['title'] ?? ''} ${_doctorData?['first_name'] ?? ''} ${_doctorData?['last_name'] ?? ''}".trim(),
                      style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.whiteText),
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/doctor_header_pattern.webp',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: AppColors.background2.withOpacity(0.15),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 70.h),
                          GestureDetector(
                            onTap: () {
                              if (avatarPath.startsWith('http')) {
                                _showImageOverlayWithIndex([avatarPath], 0);
                              }
                            },
                            child: CircleAvatar(
                              backgroundColor: AppColors.background2.withOpacity(0.2),
                              radius: 40.r,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: doctorAvatarWidget,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "${_doctorData?['title'] ?? ''} ${_doctorData?['first_name'] ?? ''} ${_doctorData?['last_name'] ?? ''}".trim(),
                            style: AppTextStyles.getTitle2(context)
                                .copyWith(color: AppColors.whiteText),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            _doctorData?['specialty'] ?? "Specialty not provided",
                            style: AppTextStyles.getText2(context)
                                .copyWith(fontWeight: FontWeight.w500, color: Colors.white70),
                          ),
                          SizedBox(height: 15.h),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [

                        SizedBox(height: 25.h),
                        if (_doctorData?['gallery'] != null &&
                            (_doctorData!['gallery'] as List).isNotEmpty)
                          SizedBox(height: 10.h),
                        if (_doctorData?['gallery'] != null &&
                            (_doctorData!['gallery'] as List).isNotEmpty)
                          _buildGallerySection(_doctorData!['gallery']),
                        if (_doctorData?['pricing'] != null &&
                            (_doctorData!['pricing'] as List).isNotEmpty)
                          SizedBox(height: 10.h),
                        if (_doctorData?['pricing'] != null &&
                            (_doctorData!['pricing'] as List).isNotEmpty)
                          _buildPricingSection(_doctorData!['pricing'] as List),
                        if (_promotions.isNotEmpty)
                          SizedBox(height: 10.h),
                        if (_promotions.isNotEmpty)
                          _buildPromotionsSection(_promotions),
                        if (profileDescription != null ||
                            (specialties != null && specialties.isNotEmpty))
                          SizedBox(height: 10.h),
                        if (profileDescription != null ||
                            (specialties != null && specialties.isNotEmpty))
                          _buildProfileSection(profileDescription, specialties, website),
                        if (_doctorData?['offered_services'] != null) SizedBox(height: 10.h),
                        if (_doctorData?['offered_services'] != null)
                          _buildServicesSection(_doctorData!['offered_services']),
                        if (_centerMemberships.isNotEmpty)
                          SizedBox(height: 10.h),
                        if (_centerMemberships.isNotEmpty)
                          _buildWorksAtSection(_centerMemberships),
                        if (street != null || city != null || country != null)
                          SizedBox(height: 10.h),
                        if (street != null || city != null || country != null)
                          _buildLocationSection(
                            street,
                            buildingNr,
                            city,
                            country,
                            addressDetails,
                            address,
                            _doctorData?['clinic'],
                          ),
                        if (_doctorData?['opening_hours'] != null ||
                            _doctorData?['languages'] != null ||
                            _hasAnyContactInfo)
                          SizedBox(height: 10.h),
                        if (_doctorData?['opening_hours'] != null ||
                            _doctorData?['languages'] != null ||
                            _hasAnyContactInfo)
                          _buildInfoSection(
                            _publicPhone,
                            _doctorData?['opening_hours'] ?? {},
                            _doctorData?['languages'] ?? [],
                            email: _publicEmail,
                            centerPhone: _centerPhoneNumber,
                            landlines: _publicLandlines,
                            website: _publicWebsite,
                          ),
                        if (_doctorData?['faqs'] != null) SizedBox(height: 10.h),
                        if (_doctorData?['faqs'] != null)
                          _buildFAQsSection(_doctorData!['faqs']),

                        if (visibleSections < 4) SizedBox(height: 250.h),

                        SizedBox(height: 60.h),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          Positioned(
            top: _buttonTopOffset,
            left: 32.w,
            right: 32.w,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      AppColors.background4,
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: _userId == doctorId ? _buildOwnAccountBanner() : ElevatedButton.icon(
                  onPressed: () {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user == null) {
                      _showLoginPromptDialog();
                      return;
                    }
                    debugPrint("➡️ [DoctorProfilePage] Navigating to SelectPatientPage with:");
                    debugPrint("- doctorId: $doctorId");
                    debugPrint("- clinicLocation: $clinicLocation");

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelectPatientPage(
                          doctorId: doctorId,
                          doctorName: "$doctorFirstName $doctorLastName",
                          doctorGender: doctorGender,
                          doctorTitle: doctorTitle,
                          specialty: doctorSpecialty,
                          image: avatarPath,
                          clinicName: clinicName,
                          clinicAddress: clinicAddress,
                          clinicLocation: clinicLocation,
                        ),
                      ),
                    );
                  },


                  icon: Icon(Icons.calendar_today, color: AppColors.mainDark, size: 18.sp),
                  label: Text(
                    AppLocalizations.of(context)!.bookAppointment,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 12.sp, color: AppColors.mainDark),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16.h,
            left: 32.w,
            right: 32.w,
            child: Opacity(
              opacity: bottomButtonOpacity.clamp(0.0, 1.0),
              child: _userId == doctorId ? _buildOwnAccountBanner() : ElevatedButton.icon(
                onPressed: () async {
                  final user = Supabase.instance.client.auth.currentUser;

                  if (user == null) {
                    _showLoginPromptDialog();
                    return;
                  } else {
                    debugPrint("➡️ [DoctorProfilePage] Navigating to SelectPatientPage with:");
                    debugPrint("- doctorId: $doctorId");
                    debugPrint("- clinicLocation: $clinicLocation");

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectPatientPage(
                          doctorId: doctorId,
                          doctorName: "$doctorFirstName $doctorLastName",
                          doctorGender: doctorGender,
                          doctorTitle: doctorTitle,
                          specialty: doctorSpecialty,
                          image: avatarPath,
                          clinicName: clinicName,
                          clinicAddress: clinicAddress,
                          clinicLocation: clinicLocation,
                        ),
                      ),
                    );
                  }
                },

                icon: Icon(Icons.calendar_today, color: Colors.white, size: 18.sp),
                label: Text(
                  AppLocalizations.of(context)!.bookAppointment,
                  style:
                  AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          if (_expandedImageOverlay) _buildImageOverlay(),
        ],
      ),
    );
  }

  Widget _buildOwnAccountBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade400, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.ownAccountWarning,
              style: AppTextStyles.getText2(context).copyWith(
                color: Colors.red.shade500,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableFAQTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool showDivider;

  const _ExpandableFAQTile({
    required this.question,
    required this.answer,
    this.showDivider = true,
  });

  @override
  State<_ExpandableFAQTile> createState() => _ExpandableFAQTileState();
}

class _ExpandableFAQTileState extends State<_ExpandableFAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // سؤال
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppTextStyles.getText2(context)
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 11.sp),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20.sp,
                  color: AppColors.main,
                ),
              ],
            ),
            if (_expanded)
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  widget.answer,
                  style: AppTextStyles.getText3(context),
                ),
              ),
            if (widget.showDivider)
              Padding(
                padding: EdgeInsets.only(top: 3.h),
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
          ],
        ),
      ),
    );
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

// ─── Claim Promotion Bottom Sheet ───────────────────────────────────────────

class _ClaimPromotionSheet extends StatefulWidget {
  final String promoId;
  final String title;
  final String? description;
  final Color color;
  final IconData icon;
  final AppLocalizations local;

  const _ClaimPromotionSheet({
    required this.promoId,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.local,
  });

  @override
  State<_ClaimPromotionSheet> createState() => _ClaimPromotionSheetState();
}

class _ClaimPromotionSheetState extends State<_ClaimPromotionSheet>
    with TickerProviderStateMixin {
  bool _isClaiming = false;
  String? _voucherCode;
  String? _error;

  // Animation controllers
  late AnimationController _celebrationController;
  late AnimationController _checkController;
  late AnimationController _codeRevealController;
  late Animation<double> _checkAnimation;
  late Animation<double> _codeFadeAnimation;
  late Animation<double> _codeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _codeRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _codeFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _codeRevealController, curve: Curves.easeOut),
    );
    _codeScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _codeRevealController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _checkController.dispose();
    _codeRevealController.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() {
      _isClaiming = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .rpc('claim_doctor_promotion', params: {
        'p_promotion_id': widget.promoId,
      });

      final result = response as Map<String, dynamic>;
      if (result['success'] == true) {
        setState(() {
          _voucherCode = result['voucher_code'] as String?;
          _isClaiming = false;
        });
        // Trigger celebration animations sequentially
        _celebrationController.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        _checkController.forward();
        await Future.delayed(const Duration(milliseconds: 400));
        _codeRevealController.forward();
      } else {
        final errorCode = result['error'] as String? ?? 'unknown';
        setState(() {
          _error = _mapError(errorCode);
          _isClaiming = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isClaiming = false;
      });
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'already_claimed':
        return widget.local.alreadyClaimed;
      case 'promotion_expired':
        return widget.local.offerExpired;
      case 'promotion_full':
        return widget.local.offerFull;
      case 'promotion_not_found':
        return widget.local.offerExpired;
      case 'max_claims_per_patient_reached':
        return widget.local.promotionMaxClaimsReached;
      case 'not_new_patient':
        return widget.local.promotionAlreadyUsed;
      case 'insufficient_points':
        return widget.local.promotionAlreadyUsed;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.local;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // ── Success state with animations ──
          if (_voucherCode != null) ...[
            SizedBox(
              height: 320.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Confetti particles
                  AnimatedBuilder(
                    animation: _celebrationController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(300.w, 300.h),
                        painter: _ConfettiPainter(
                          progress: _celebrationController.value,
                          colors: [
                            AppColors.main,
                            const Color(0xFF4CAF50),
                            const Color(0xFFFF9800),
                            const Color(0xFF2196F3),
                            const Color(0xFFE91E63),
                            AppColors.main.withOpacity(0.6),
                          ],
                        ),
                      );
                    },
                  ),
                  // Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated check circle
                      ScaleTransition(
                        scale: _checkAnimation,
                        child: Container(
                          width: 64.r,
                          height: 64.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.main,
                                AppColors.main.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.main.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 32.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Success text
                      FadeTransition(
                        opacity: _codeFadeAnimation,
                        child: Text(
                          l.claimSuccess,
                          style: AppTextStyles.getTitle2(context).copyWith(
                            color: AppColors.mainDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // Voucher code card
                      FadeTransition(
                        opacity: _codeFadeAnimation,
                        child: ScaleTransition(
                          scale: _codeScaleAnimation,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 16.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.main.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: AppColors.main.withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  l.voucherCode,
                                  style: AppTextStyles.getText3(context).copyWith(
                                    color: Colors.grey[500],
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _voucherCode!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l.codeCopied),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        backgroundColor: AppColors.main,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _voucherCode!,
                                        style: AppTextStyles.getTitle1(context).copyWith(
                                          fontSize: 22.sp,
                                          letterSpacing: 3,
                                          color: AppColors.mainDark,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 16.sp,
                                        color: AppColors.main.withOpacity(0.6),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  l.voucherExpiry,
                                  style: AppTextStyles.getText3(context).copyWith(
                                    color: Colors.grey[400],
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Show to doctor hint
                      FadeTransition(
                        opacity: _codeFadeAnimation,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14.sp,
                              color: Colors.grey[400],
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              l.showCodeToDoctor,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]

          // ── Error message ──
          else if (_error != null) ...[
            // Icon
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 22.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              widget.title,
              style: AppTextStyles.getTitle2(context).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: const Color(0xFFE53935), size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]

          // ── Claim prompt (initial state) ──
          else ...[
            // Small accent icon
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 22.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              widget.title,
              style: AppTextStyles.getTitle2(context).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (widget.description != null && widget.description!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                widget.description!,
                style: AppTextStyles.getText3(context).copyWith(
                  color: Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 6.h),
            // Divider
            Divider(color: Colors.grey.shade200, height: 24.h),
            // Claim description
            Text(
              l.claimOfferDesc,
              style: AppTextStyles.getText2(context).copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            // Elegant claim button
            GestureDetector(
              onTap: _isClaiming ? null : _claim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: _isClaiming ? AppColors.main.withOpacity(0.6) : AppColors.main,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: _isClaiming
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.main.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: _isClaiming
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.redeem_rounded, color: Colors.white, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            l.claimOffer,
                            style: AppTextStyles.getText1(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Confetti particle painter for claim celebration
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _ConfettiPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final random = [
      0.1, 0.3, 0.5, 0.7, 0.9, 0.15, 0.35, 0.55, 0.75, 0.95,
      0.2, 0.4, 0.6, 0.8, 0.05, 0.25, 0.45, 0.65, 0.85,
    ];

    for (int i = 0; i < 18; i++) {
      final angle = (i / 18) * 3.14159 * 2;
      final distance = 40 + random[i] * 100;
      final particleProgress = (progress * 2 - random[i]).clamp(0.0, 1.0);
      final fadeOut = progress > 0.7 ? (1.0 - (progress - 0.7) / 0.3) : 1.0;

      if (particleProgress <= 0) continue;

      final x = center.dx + distance * particleProgress * math.cos(angle);
      final y = center.dy + distance * particleProgress * math.sin(angle) + 20 * particleProgress * particleProgress;

      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(fadeOut * 0.8)
        ..style = PaintingStyle.fill;

      // Alternate between circles and small rectangles
      if (i % 3 == 0) {
        canvas.drawCircle(Offset(x, y), 3 * (1 - particleProgress * 0.3), paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle + progress * 6);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 6, height: 3),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => progress != oldDelegate.progress;
}