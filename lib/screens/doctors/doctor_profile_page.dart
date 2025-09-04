import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/text_styles.dart';

// ✅ استيراد صفحة نتائج الخرائط
import 'package:docsera/screens/map_results_page.dart';

class DoctorProfilePage extends StatefulWidget {
  final String doctorId; // ✅ Make non-nullable
  final Map<String, dynamic>? doctor;

  const DoctorProfilePage({
    Key? key,
    required this.doctorId,
    this.doctor,
  }) : super(key: key);

  @override
  _DoctorProfilePageState createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  bool _showAppBar = false;
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _doctorChannel;
  Map<String, dynamic>? _doctorData;

  bool _expandedImageOverlay = false;
  List<String> _expandedImageUrls = [];
  int _initialImageIndex = 0;
  final TransformationController _transformationController = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  Map<String, ImageProvider> _imageCache = {};
  double _buttonTopOffset = 0.0;
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
    final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration());
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
    print("🩺 DoctorProfilePage INIT - doctorId: ${widget.doctorId}");
    if (widget.doctor != null && widget.doctor!.isNotEmpty) {
      _doctorData = {...widget.doctor!};
    }
    _loadFavoriteStatus();
    _loadDoctorProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _buttonTopOffset = _calculateButtonOffset();
      });
    });
  }

  @override
  void dispose() {
    _doctorChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorProfile() async {
    if (widget.doctorId.isEmpty) {
      print("❌ Error: Doctor ID is missing in DoctorProfilePage.");
      return;
    }

    print("✅ Loading Doctor Profile for ID: ${widget.doctorId}");
    final prefs = await SharedPreferences.getInstance();
    final String doctorId = widget.doctorId.trim();

    if (widget.doctor != null && widget.doctor!.isNotEmpty) {
      print("⚡ Using Passed Doctor Data for ID: $doctorId (FIRST CASE)");
      setState(() {
        _doctorData = Map<String, dynamic>.from(widget.doctor!);
      });
    } else {
      String? cachedData = prefs.getString('doctor_$doctorId');
      if (cachedData != null) {
        Map<String, dynamic> cachedDoctor = json.decode(cachedData);
        print("⚡ Loaded Cached Doctor Data: ${cachedDoctor['first_name']} ${cachedDoctor['last_name']} (SECOND CASE)");

        setState(() {
          _doctorData = {...cachedDoctor};
        });
      }
    }

    try {
      final response = await Supabase.instance.client
          .from('doctors')
          .select()
          .eq('id', doctorId)
          .maybeSingle();

      if (response != null) {
        print("📥 Loaded Fresh Doctor from Supabase: ${response['first_name']} ${response['last_name']} (THIRD CASE)");

        await prefs.setString('doctor_$doctorId', json.encode(response));

        setState(() {
          _doctorData = {...response};
        });
      } else {
        print("❌ Doctor not found in Supabase.");
      }

      final client = Supabase.instance.client;

      _doctorChannel = client
          .channel('public:doctors:profile')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'doctors',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.doctorId,
        ),
        callback: (payload) async {
          final updatedDoctor = payload.newRecord;
          print("📡 Supabase Realtime Update: $updatedDoctor");

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('doctor_${widget.doctorId}', json.encode(updatedDoctor));

          if (mounted) {
            setState(() {
              _doctorData = updatedDoctor;
            });
          }
        },
      )
          .subscribe();
    } catch (e) {
      print("❌ Error loading doctor from Supabase: $e");
    }
  }

  // ✅ Share Doctor Profile Function
  void _shareDoctorProfile() {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String doctorName = "${_doctorData?['first_name']} ${_doctorData?['last_name']}";
    String specialty = _doctorData?['specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty;
    String clinic = _doctorData?['clinic'] ?? AppLocalizations.of(context)!.clinicNotAvailable;
    Map<String, dynamic>? address = _doctorData?['address'];
    String fullAddress = address != null
        ? "${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['country'] ?? ''}"
        : AppLocalizations.of(context)!.addressNotEntered;

    String shareText = isArabic
        ? """
  👨‍⚕️ الطبيب: $doctorName
  💼 التخصص: $specialty
  🏥 العيادة: $clinic
  📍 العنوان: $fullAddress
  📞 الاتصال: ${_doctorData?['phone_number'] ?? AppLocalizations.of(context)!.notProvided}
  
  اكتشف هذا الطبيب على تطبيق DocSera!
  """
        : """
  👨‍⚕️ Doctor: $doctorName
  💼 Specialty: $specialty
  🏥 Clinic: $clinic
  📍 Address: $fullAddress
  📞 Contact: ${_doctorData?['phone_number'] ?? AppLocalizations.of(context)!.notProvided}
  
  Check out this doctor on the DocSera App!
  """;

    Share.share(shareText, subject: isArabic ? "ملف الطبيب - $doctorName" : "Doctor Profile - $doctorName");
    print("📤 Shared Doctor Profile as Text in ${isArabic ? "Arabic" : "English"}");
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


  /// 🔹 Open Google Maps with the given address (يُستخدم فقط عند الحاجة)
  void _openMaps(String address) async {
    String encodedAddress = Uri.encodeComponent(address);
    Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
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
                            final scale = 2.5;
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
      MaterialPageRoute(builder: (_) => FullMapResultsPage(results: [item])),
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
                    image: AssetImage('assets/images/map.png'),
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
                                final doc = quill.Document.fromJson(jsonDecode(profileDescription));
                                final controller = quill.QuillController(
                                  document: doc,
                                  selection: const TextSelection.collapsed(offset: 0),
                                  readOnly: true,
                                );

                                return quill.QuillEditor.basic(
                                  controller: controller,
                                  focusNode: FocusNode(skipTraversal: true, canRequestFocus: false), // ✅ يمنع المؤشر
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

  Widget _buildGallerySection(List<dynamic> galleryUrls) {
    final String? doctorId = _doctorData?['id']?.toString();
    if (doctorId == null) return SizedBox.shrink();

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
                physics: NeverScrollableScrollPhysics(),
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
                    image: AssetImage('assets/images/map.png'),
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
                      if (profileDescription != null && profileDescription.isNotEmpty)
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

                  if (profileDescription != null && profileDescription.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h, right: 12.w, left: 12.w, bottom: 8.h),
                      child: Builder(
                        builder: (context) {
                          try {
                            final doc = quill.Document.fromJson(jsonDecode(profileDescription));
                            final plainText = doc.toPlainText().trim();

                            return Text(
                              plainText,
                              style: AppTextStyles.getText3(context),
                              maxLines: 5, // تقريبًا 5 أسطر
                              overflow: TextOverflow.ellipsis, // ✅ لإظهار ...
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
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildServicesSection(List<dynamic>? services) {
    if (services == null || services.isEmpty) return SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showServicesBottomSheet(services),
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

              ...services.take(2).map((item) {
                final title = item['title'] ?? '';
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Text(
                    "• $title",
                    style: AppTextStyles.getText3(context),
                  ),
                );
              }),
              if (services.length > 2)
                Text(
                  "+${services.length - 2} ${AppLocalizations.of(context)!.showMore}",
                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServicesBottomSheet(List<dynamic> services) {
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
  Widget _buildInfoSection(
      String? phoneNumber,
      Map<String, dynamic> openingHours,
      List<dynamic> languages,
      {String? email}
      ) {
    final l = AppLocalizations.of(context)!;
    final List<String> languageLabels =
    languages.map((code) => languageLabelFromCode(l, code.toString())).toList();

    final String formattedPhone = phoneNumber != null ? _displayPhone(phoneNumber) : '';
    final String displayedPhone = formattedPhone.isNotEmpty ? formattedPhone : l.notProvided;
    final String displayedEmail = (email ?? '').isNotEmpty ? email! : l.notProvided;

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
            onTap: () => _showContactDetails(phoneNumber, email: email),
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
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Divider(color: Colors.grey[200], thickness: 1),
          ),

          /// 🔹 Opening Hours
          GestureDetector(
            onTap: () => _showOpeningHoursDetails(openingHours),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.openingHours,
                        style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.viewMore,
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
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Divider(color: Colors.grey[200], thickness: 1),
          ),

          /// 🔹 Languages
          GestureDetector(
            onTap: () => _showLanguagesDetails(languages),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        l.languagesSpoken,
                        style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.viewMore,
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
            ),
          ),
        ],
      ),
    );
  }


  void _showContactDetails(String? phoneNumber, {String? email}) {
    final l = AppLocalizations.of(context)!;

    String _formatPhone(String raw) {
      if (raw.startsWith('00963')) return '0${raw.substring(5)}';
      if (raw.startsWith('+963')) return '0${raw.substring(4)}';
      return raw;
    }

    final formattedPhone = phoneNumber != null ? _formatPhone(phoneNumber) : null;
    final formattedEmail = (email ?? '').trim();

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

              if (formattedPhone != null && formattedPhone.isNotEmpty)
                GestureDetector(
                  onTap: () => _makePhoneCall(formattedPhone),
                  child: Row(
                    children: [
                      Icon(Icons.call, color: AppColors.main, size: 16.sp),
                      SizedBox(width: 10.w),
                      Text(
                        formattedPhone,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                    ],
                  ),
                ),

              if (formattedPhone != null && formattedPhone.isNotEmpty)
                SizedBox(height: 16.h),

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

              SizedBox(height: 25.h),
            ],
          ),
        );
      },
    );
  }

  // void _showOpeningHoursDetails(Map<String, dynamic> openingHours) { bool isArabic = Localizations.localeOf(context).languageCode == 'ar'; Map<String, String> daysMap = { "mon": isArabic ? "الإثنين" : "Monday", "tue": isArabic ? "الثلاثاء" : "Tuesday", "wed": isArabic ? "الأربعاء" : "Wednesday", "thu": isArabic ? "الخميس" : "Thursday", "fri": isArabic ? "الجمعة" : "Friday", "sat": isArabic ? "السبت" : "Saturday", "sun": isArabic ? "الأحد" : "Sunday", }; List<String> days = daysMap.keys.toList(); String currentDay = days[DateTime.now().weekday - 1]; showModalBottomSheet( context: context, backgroundColor: AppColors.background2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), builder: (context) { return Padding( padding: EdgeInsets.all(16.w), child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [ Center( child: Text( AppLocalizations.of(context)!.openingHours, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp), ), ), SizedBox(height: 25.h), Column( children: days.map((day) { List<dynamic>? slots = openingHours[day] as List<dynamic>?; String formattedHours = (slots != null && slots.isNotEmpty) ? _formatOpeningHours(slots) : AppLocalizations.of(context)!.closed; bool isToday = (day == currentDay); return Padding( padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text( daysMap[day] ?? day, style: TextStyle( fontSize: 14.sp, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? AppColors.main : Colors.black87, ), ), Text( formattedHours, style: TextStyle( fontSize: 12.sp, fontWeight: FontWeight.bold, color: isToday ? AppColors.main : Colors.black87, ), textAlign: TextAlign.right, ), ], ), ); }).toList(), ), SizedBox(height: 25.h), ], ), ); }, ); }

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
    final currentDay = days[DateTime.now().weekday - 1];

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

  String _formatOpeningHours(List<dynamic> slots) {
    if (slots.isEmpty) return "Closed";

    List<Map<String, dynamic>> formatted = slots.map((slot) {
      final slotMap = slot as Map<String, dynamic>;
      final fromRaw = slotMap["from"] ?? '';
      final toRaw   = slotMap["to"] ?? '';

      return {
        "from": fromRaw,
        "to": toRaw,
        "label": "${_pretty12(context, fromRaw)} - ${_pretty12(context, toRaw)}"
      };
    }).toList();

    // ترتيب حسب وقت البدء الحقيقي (وليس النص)
    formatted.sort((a, b) {
      final fromA = TimeOfDay(
        hour: int.parse(a["from"]!.split(":")[0]),
        minute: int.parse(a["from"]!.split(":")[1]),
      );
      final fromB = TimeOfDay(
        hour: int.parse(b["from"]!.split(":")[0]),
        minute: int.parse(b["from"]!.split(":")[1]),
      );
      return fromA.hour.compareTo(fromB.hour) != 0
          ? fromA.hour.compareTo(fromB.hour)
          : fromA.minute.compareTo(fromB.minute);
    });

    return formatted.map((e) => e["label"]).join(", ");
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

  Widget _buildFAQsSection(List<dynamic>? faqs) {
    if (faqs == null || faqs.isEmpty) return SizedBox.shrink();

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
            ...List.generate(faqs.length, (index) {
              final question = faqs[index]['question'] ?? '';
              final answer = faqs[index]['answer'] ?? '';

              return _ExpandableFAQTile(
                question: question,
                answer: answer,
                showDivider: index < faqs.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<String?> _getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    print("🔥 Retrieved User ID in Doctor Profile: $userId");
    return userId;
  }

  void _loadFavoriteStatus() async {
    final String? userId = await _getCurrentUserId();
    final String? doctorId = widget.doctorId.toString();

    print("🔹 Checking Favorite Status");
    print("👤 User ID: $userId");
    print("🩺 Doctor ID: $doctorId");

    if (userId == null || userId.isEmpty || doctorId == null || doctorId.isEmpty) {
      print("❌ Error: Doctor ID or User ID is missing! Cannot check favorites.");
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .maybeSingle();

      List<dynamic> favorites = response?['favorites'] ?? [];

      setState(() {
        _isFavorite = favorites.contains(doctorId);
      });

      print("✅ Favorite status loaded: $_isFavorite");
    } catch (e) {
      print("❌ Error loading favorite status: $e");
    }
  }

  void _toggleFavoriteStatus() async {
    final String? userId = await _getCurrentUserId();
    final String? doctorId = _doctorData?['id']?.toString();

    print("🔹 Toggling Favorite");
    print("👤 User ID: $userId");
    print("🩺 Doctor ID: $doctorId");

    if (userId == null || userId.isEmpty || doctorId == null || doctorId.isEmpty) {
      print("❌ Error: Doctor ID or User ID is missing!");
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print("❌ User not found in Supabase.");
        return;
      }

      List<dynamic> favorites = response['favorites'] ?? [];

      if (favorites.contains(doctorId)) {
        favorites.remove(doctorId);
        await supabase.from('users').update({'favorites': favorites}).eq('id', userId);

        setState(() => _isFavorite = false);
        print("❌ Doctor removed from favorites");
      } else {
        favorites.add(doctorId);
        await supabase.from('users').update({'favorites': favorites}).eq('id', userId);

        setState(() => _isFavorite = true);
        print("⭐ Doctor added to favorites");
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('refreshFavorites', true);
    } catch (e) {
      print("❌ Error updating favorites: $e");
    }
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

    String? imagePath = doctor['doctor_image'];
    print('📷 RAW doctor_image = "$imagePath"');

    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final doctorAvatarWidget = imageResult.widget;

    final String? profileDescription = doctor['profile_description'];
    final List<String>? specialties = (doctor['specialties'] as List<dynamic>?)?.cast<String>();
    final String? website = doctor['website'];

    if (widget.doctorId.isEmpty) {
      print("❌ ERROR: doctorId is unexpectedly empty inside DoctorProfilePage");
      return Scaffold(
        appBar: AppBar(title: Text("Error")),
        body: Center(child: Text("Doctor ID is missing. Cannot load profile.")),
      );
    }

    final doctorId = widget.doctorId;
    final doctorFirstName = _doctorData?['first_name'] ?? '';
    final doctorLastName = _doctorData?['last_name'] ?? '';
    final doctorGender = _doctorData?['gender'] ?? '';
    final doctorTitle = _doctorData?['title'] ?? '';
    final doctorSpecialty = _doctorData?['specialty'] ?? '';
    final clinicName = _doctorData?['clinic'] ?? '';
    final clinicAddress = _doctorData?['address'] ?? {};

    double offset = _scrollController.hasClients ? _scrollController.offset : 0;
    double fadeStart = 100;
    double fadeEnd = MediaQuery.of(context).size.height * 0.15;
    double opacity = 1.0;
    int visibleSections = 0;

    if (_doctorData?['gallery'] != null && (_doctorData!['gallery'] as List).isNotEmpty)
      visibleSections++;
    if (profileDescription != null || (specialties != null && specialties.isNotEmpty))
      visibleSections++;
    if (_doctorData?['offered_services'] != null && _doctorData!['offered_services'] is Map<String, dynamic> && (_doctorData!['offered_services'] as Map).isNotEmpty)
      visibleSections++;
    if (street != null || city != null || country != null)
      visibleSections++;
    if (_doctorData?['opening_hours'] != null || _doctorData?['languages'] != null || _doctorData?['phone_number'] != null)
      visibleSections++;
    if (_doctorData?['faqs'] != null && _doctorData!['faqs'] is Map<String, dynamic>)
      visibleSections++;


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
              ? const Center(child: CircularProgressIndicator())
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
                  FutureBuilder<String?>(
                    future: _getCurrentUserId(),
                    builder: (context, snapshot) {
                      final userId = snapshot.data;
                      if (userId == null || userId.isEmpty) return SizedBox.shrink(); // 🔥 Hide icon if not logged in

                      return IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.star : Icons.star_border,
                          color: AppColors.whiteText,
                        ),
                        onPressed: _toggleFavoriteStatus,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: AppColors.whiteText, size: 18.sp),
                    onPressed: _shareDoctorProfile,
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
                        'assets/images/doctor_header_pattern.png',
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
                              if (avatarPath != null && avatarPath.startsWith('http')) {
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
                        if (profileDescription != null ||
                            (specialties != null && specialties.isNotEmpty))
                          SizedBox(height: 10.h),
                        if (profileDescription != null ||
                            (specialties != null && specialties.isNotEmpty))
                          _buildProfileSection(profileDescription, specialties, website),
                        if (_doctorData?['offered_services'] != null) SizedBox(height: 10.h),
                        if (_doctorData?['offered_services'] != null &&
                            _doctorData!['offered_services'] is Map<String, dynamic> &&
                            (_doctorData!['offered_services'] as Map).isNotEmpty)
                          _buildServicesSection(
                            (_doctorData!['offered_services'] as Map<String, dynamic>)
                                .entries
                                .map((entry) => {
                              'title': entry.key,
                              'description': entry.value?.toString() ?? '',
                            })
                                .toList(),
                          ),
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
                            _doctorData?['phone_number'] != null)
                          SizedBox(height: 10.h),
                        if (_doctorData?['opening_hours'] != null ||
                            _doctorData?['languages'] != null ||
                            _doctorData?['phone_number'] != null)
                          _buildInfoSection(
                            _doctorData?['phone_number']?.toString(),
                            _doctorData?['opening_hours'] ?? {},
                            _doctorData?['languages'] ?? [],
                            email: _doctorData?['email']?.toString(),
                          ),
                        if (_doctorData?['faqs'] != null) SizedBox(height: 10.h),
                        if (_doctorData?['faqs'] != null && _doctorData!['faqs'] is Map<String, dynamic>)
                          _buildFAQsSection(
                            (_doctorData!['faqs'] as Map<String, dynamic>)
                                .entries
                                .map((entry) => {
                              'question': entry.key,
                              'answer': entry.value?.toString() ?? '',
                            })
                                .toList(),
                          ),

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
                  gradient: LinearGradient(
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
                child: ElevatedButton.icon(
                  onPressed: () {
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
              child: ElevatedButton.icon(
                onPressed: () {
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
                      ),
                    ),
                  );
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
