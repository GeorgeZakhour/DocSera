import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class FullMapResultsPage extends StatefulWidget {
  final List<Map<String, dynamic>> results; // عناصر فيها lat/lng + بيانات الطبيب الأساسية

  const FullMapResultsPage({super.key, required this.results});

  @override
  State<FullMapResultsPage> createState() => _FullMapResultsPageState();
}

class _FullMapResultsPageState extends State<FullMapResultsPage> with SingleTickerProviderStateMixin {
  GoogleMapController? _gController;

  // اختيار الحالي
  int _selectedIndex = 0;

  // أيقونات المؤشر المخصصة (محدّد/غير محدد)
  BitmapDescriptor? _pinSelected;
  BitmapDescriptor? _pinUnselected;

  // ارتفاع السلايدر السفلي
  static const double _bottomCardHeight = 210;

  bool _isDarkMode = false;

  // الموقع الحي + نبضة
  Position? _currentPosition;
  late AnimationController _pulseController;
  double _pulseRadius = 60; // متر

  // PageView للتحكم بالسوايب
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // جعل كل بطاقة تملأ العرض بالكامل (مركزة في المنتصف)
    _pageController = PageController(viewportFraction: 1.0, initialPage: _selectedIndex);
    _generatePinIcons();
    _initLocation();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
      setState(() {
        _pulseRadius = 60 + (_pulseController.value * 40);
      });
    })
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Helpers ---
  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  LatLng? _getPointFor(Map<String, dynamic> doc) {
    final location = doc['location'];
    if (location is Map) {
      final lat = _asDouble(location['lat']);
      final lng = _asDouble(location['lng']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  String _buildAddress(Map<String, dynamic> doctor) {
    final addr = doctor['address'] as Map<String, dynamic>?;
    if (addr == null) return '';
    final parts = <String>[];
    void add(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) parts.add(s);
    }

    // ترتيب منطقي: شارع، بناء/طابق، مدينة
    add(addr['street']);
    add(addr['building']);
    add(addr['floor']);
    add(addr['city']);

    return parts.join(' • ');
  }

  String _addressDetails(Map<String, dynamic> doctor) {
    final addr = doctor['address'] as Map<String, dynamic>?;
    final det = (addr?['details'] ?? '').toString().trim();
    return det;
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {});
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((pos) {
        setState(() => _currentPosition = pos);
      });
    } catch (_) {}
  }

  Future<BitmapDescriptor> _createLocationIcon({
    required Color fillColor,
    required Color borderColor,
    double size = 80,
    double borderWidth = 6,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // استخدم رمز أيقونة الموقع
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
        color: fillColor,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset.zero);

    final TextPainter borderTP = TextPainter(textDirection: TextDirection.ltr);
    borderTP.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
        foreground: borderPaint,
      ),
    );
    borderTP.layout();
    borderTP.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(tp.width.toInt(), tp.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _generatePinIcons() async {
    final selected = await _createLocationIcon(
      fillColor: AppColors.main,
      borderColor: AppColors.main,
      size: 150,
      borderWidth: 0,
    );

    final unselected = await _createLocationIcon(
      fillColor: AppColors.main.withOpacity(0.4),
      borderColor: AppColors.main,
      size: 120,
      borderWidth: 6,
    );

    if (mounted) {
      setState(() {
        _pinSelected = selected;
        _pinUnselected = unselected;
      });
    }
  }

  Future<void> _applyMapStyle() async {
    final stylePath = _isDarkMode ? 'assets/map_style_dark.json' : 'assets/map_style_light.json';
    final style = await rootBundle.loadString(stylePath);
    await _gController?.setMapStyle(style);
  }

  Future<void> _fitAllPins() async {
    if (_gController == null) return;
    final points = widget.results.map(_getPointFor).whereType<LatLng>().toList();
    if (points.isEmpty) return;

    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    final cu = CameraUpdate.newLatLngBounds(bounds, 60);
    try {
      await _gController!.animateCamera(cu);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _gController!.animateCamera(cu);
      });
    }
  }

  Future<void> _animateToDoctor(int index, {bool offsetForCard = true}) async {
    final doc = widget.results[index];
    final p = _getPointFor(doc);
    if (p == null) return;

    // نرفع نقطة الهدف قليلاً ليظهر الـ pin فوق الكارد
    final target = offsetForCard ? LatLng(p.latitude + 0.002, p.longitude) : p;

    await _gController?.animateCamera(CameraUpdate.newLatLng(target));
  }

  /// فتح الخرائط باستخدام الإحداثيات.
  /// - إن وُجد تطبيق افتراضي (geo:/Apple/Google) نستخدمه مباشرة
  /// - إن وُجد أكثر من تطبيق متاح: نعرض لك اختيار التطبيق
  /// - إن لم يوجد: نفتح في المتصفح
  Future<void> _openInMapsPreferred(Map<String, dynamic> doctor) async {
    final p = _getPointFor(doctor);
    if (p == null) return;

    final lat = p.latitude.toString();
    final lng = p.longitude.toString();
    final displayName = [
      (doctor['title'] ?? '').toString().trim(),
      (doctor['first_name'] ?? '').toString().trim(),
      (doctor['last_name'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final encodedName = Uri.encodeComponent(displayName);

    final Uri geoScheme = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)'); // Android/geo
    final Uri appleMaps = Uri.parse('http://maps.apple.com/?ll=$lat,$lng&q=$encodedName'); // iOS
    final Uri gmapsApp = Uri.parse('comgooglemaps://?q=$encodedName&center=$lat,$lng');
    final Uri gmapsWeb  = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'); // fallback متصفح


    final options = <_MapLaunchOption>[];

    if (await canLaunchUrl(geoScheme)) {
      // geo عادة يفتح التطبيق الافتراضي على أندرويد
      options.add(_MapLaunchOption(label: 'Default', uri: geoScheme));
    }
    if (await canLaunchUrl(gmapsApp)) {
      options.add(_MapLaunchOption(label: 'Google Maps', uri: gmapsApp));
    }
    if (await canLaunchUrl(appleMaps)) {
      options.add(_MapLaunchOption(label: 'Apple Maps', uri: appleMaps));
    }

    if (options.isEmpty) {
      // لا توجد تطبيقات: افتح المتصفح
      await launchUrl(gmapsWeb, mode: LaunchMode.externalApplication);
      return;
    }

    // إن وُجد خيار واحد نستخدمه مباشرة، وإلا نعرض اختيار
    if (options.length == 1) {
      await launchUrl(options.first.uri, mode: LaunchMode.externalApplication);
    } else {
      final chosen = await showModalBottomSheet<_MapLaunchOption>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          final t = AppLocalizations.of(context)!;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                Text(
                  t.openInMapsApp,
                  style: AppTextStyles.getTitle1(context),
                ),
                SizedBox(height: 12.h),
                ...options.map((opt) => ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(opt.label, style: AppTextStyles.getText2(context)),
                  onTap: () => Navigator.pop(context, opt),
                )),
                SizedBox(height: 8.h),
              ],
            ),
          );
        },
      );

      if (chosen != null) {
        await launchUrl(chosen.uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final LatLng initialCenter = () {
      const fallback = LatLng(33.5138, 36.2765); // دمشق
      final first = widget.results.isNotEmpty ? _getPointFor(widget.results.first) : null;
      return first ?? fallback;
    }();

    // ——— Build Markers ———
    final Set<Marker> markers = {};
    for (int i = 0; i < widget.results.length; i++) {
      final doc = widget.results[i];
      final point = _getPointFor(doc);
      if (point == null) continue;

      final bool isSelected = i == _selectedIndex;
      markers.add(
        Marker(
          markerId: MarkerId('doc_$i'),
          position: point,
          icon: (isSelected ? _pinSelected : _pinUnselected) ?? BitmapDescriptor.defaultMarker,
          onTap: () async {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
              );
            }
            setState(() => _selectedIndex = i);
            await _animateToDoctor(i);
          },
        ),
      );
    }

    // دائرة نبض موقع المستخدم
    final Set<Circle> circles = {};
    if (_currentPosition != null) {
      circles.add(
        Circle(
          circleId: const CircleId('pulse'),
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          radius: _pulseRadius,
          fillColor: AppColors.main.withOpacity(0.20),
          strokeColor: Colors.transparent,
        ),
      );
    }

    final bool hasCards = widget.results.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // ===== Google Map =====
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialCenter, zoom: 12),
            onMapCreated: (c) async {
              _gController = c;
              await _applyMapStyle();
              await _fitAllPins();
            },
            padding: EdgeInsets.only(bottom: hasCards ? (_bottomCardHeight + 24) : 0),
            markers: markers,
            circles: circles,
            onTap: (_) {},
            rotateGesturesEnabled: true,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            compassEnabled: false,
          ),

          // زر "موقعي"
          Positioned(
            right: 16,
            bottom: hasCards ? (_bottomCardHeight + 40) : 24,
            child: SafeArea(
              top: false,
              child: FloatingActionButton(
                heroTag: 'myLoc',
                backgroundColor: Colors.white,
                elevation: 3,
                onPressed: () async {
                  if (_currentPosition != null) {
                    final user = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                    await _gController?.animateCamera(CameraUpdate.newLatLngZoom(user, 15));
                  } else {
                    await _initLocation();
                  }
                },
                child: const Icon(Icons.my_location, color: Colors.black87),
              ),
            ),
          ),

          // Back
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Search here (placeholder)
          Positioned(
            top: 60.h,
            right: 16.w,
            child: Material(
              color: Colors.white,
              elevation: 2,
              shape: const StadiumBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Text(t.searchHere, style: AppTextStyles.getText2(context)),
                ),
              ),
            ),
          ),

          // ===== Bottom swipeable doctor cards =====
          if (hasCards)
            _BottomCardsPager(
              height: _bottomCardHeight,
              controller: _pageController,
              doctors: widget.results,
              selectedIndex: _selectedIndex,
              onPageChanged: (i) async {
                setState(() => _selectedIndex = i);
                await _animateToDoctor(i);
              },
              onOpenMaps: (doc) => _openInMapsPreferred(doc),
            ),
        ],
      ),
    );
  }
}

class _MapLaunchOption {
  final String label;
  final Uri uri;
  _MapLaunchOption({required this.label, required this.uri});
}

// ======= Bottom Pager =======
class _BottomCardsPager extends StatelessWidget {
  final double height;
  final PageController controller;
  final List<Map<String, dynamic>> doctors;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final void Function(Map<String, dynamic>) onOpenMaps;

  const _BottomCardsPager({
    super.key,
    required this.height,
    required this.controller,
    required this.doctors,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: PageView.builder(
            controller: controller,
            itemCount: doctors.length,
            onPageChanged: onPageChanged,
            padEnds: true, // كل بطاقة بوسط الشاشة
            itemBuilder: (context, index) {
              final doc = doctors[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: 12.w,
                  right: 12.w,
                  bottom: 12.w,
                  top: 8.w,
                ),
                child: _DoctorCard(
                  doctor: doc,
                  onOpenMaps: () => onOpenMaps(doc),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ======= بطاقة الطبيب (صديقة للمساحات الصغيرة، بدون RenderFlex) =======
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpenMaps;

  const _DoctorCard({
    required this.doctor,
    required this.onOpenMaps,
  });

  String _address(Map<String, dynamic> doctor) {
    final addr = doctor['address'] as Map<String, dynamic>?;
    if (addr == null) return '';
    final parts = <String>[];

    void add(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) parts.add(s);
    }

    add(addr['street']);
    add(addr['building']);
    add(addr['floor']);
    add(addr['city']);

    return parts.join(' • ');
  }

  String _addressDetails(Map<String, dynamic> doctor) {
    final addr = doctor['address'] as Map<String, dynamic>?;
    final det = (addr?['details'] ?? '').toString().trim();
    return det;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final imageProvider = imageResult.imageProvider;

    final name =
    "${doctor['title'] ?? ''} ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}"
        .trim();
    final specialty = (doctor['specialty'] ?? '').toString();
    final address = _address(doctor);
    final details = _addressDetails(doctor);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4)),
        ],
      ),
      // السماح للبطاقة أن تتمدّد عموديًا قليلًا إذا احتاج النص
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// الهيدر: الصورة + الاسم + التخصص
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.mainDark.withOpacity(0.2),
                  radius: 28.sp,
                  backgroundImage: imageProvider,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.getText2(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.mainDark,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // التخصص
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            /// العنوان + زر الخرائط — بدون RenderFlex:
            /// - دمج تفاصيل العنوان مع السطر الأساسي ليكونوا "أقرب"
            /// - استخدام Expanded للنص وقيود عرض للزر
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place, size: 16.sp, color: Colors.grey[700]),
                SizedBox(width: 6.w),

                /// النص قابل للالتفاف حتى 3 أسطر مع دمج التفاصيل
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: (address.isEmpty ? '-' : address),
                          style: AppTextStyles.getText3(context)
                              .copyWith(color: Colors.grey[800]),
                        ),
                        if (details.isNotEmpty) ...[
                          TextSpan(
                            text: " — ",
                            style: AppTextStyles.getText3(context)
                                .copyWith(color: Colors.grey[700]),
                          ),
                          TextSpan(
                            text: details,
                            style: AppTextStyles.getText3(context)
                                .copyWith(color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(width: 8.w),

                /// الزر بقيود عرض + FittedBox لتفادي الفيضان
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 140.w, // يتقلّص قبل ما يسبب Overflow
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onOpenMaps,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        t.openInMapsApp,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.main,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            /// فاصل
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Divider(height: 1, color: Colors.grey.shade300),
            ),

            /// صف حالة الحجز (كما السابق)
            Row(
              children: [
                Icon(Icons.event_busy, size: 18, color: Colors.grey.shade600),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    t.bookingNotAvailable,
                    style: AppTextStyles.getText3(context)
                        .copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}