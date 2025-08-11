import 'dart:math' as math;
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

class FullMapResultsPage extends StatefulWidget {
  final List<Map<String, dynamic>> results; // expects items with lat/lng + basic doctor data

  const FullMapResultsPage({super.key, required this.results});

  @override
  State<FullMapResultsPage> createState() => _FullMapResultsPageState();
}

class _FullMapResultsPageState extends State<FullMapResultsPage> {
  GoogleMapController? _gController;

  Map<String, dynamic>? _selectedDoctor;

  // أيقونات المؤشر المخصصة (محدّد/غير محدد)
  BitmapDescriptor? _pinSelected;
  BitmapDescriptor? _pinUnselected;

  // ارتفاع الكارد السفلي لتعديل الـ padding وتحريك العناصر فوقه
  static const double _bottomCardHeight = 190;

  bool _isDarkMode = false;

  // --- Helpers to read lat/lng safely ---
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

  @override
  void initState() {
    super.initState();
    _generatePinIcons();
  }

  Future<BitmapDescriptor> _createLocationIcon({
    required Color fillColor,
    required Color borderColor,
    double size = 80,
    double borderWidth = 6,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Draw border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw fill
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Draw the location icon shape from the Material font
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

    // Paint filled icon
    tp.paint(canvas, Offset.zero);

    // Overlay border by drawing the same icon with stroke
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
    // Selected → Bigger, filled with main color
    final selected = await _createLocationIcon(
      fillColor: AppColors.main,
      borderColor: AppColors.main,
      size: 150, // bigger
      borderWidth: 0,
    );

    // Unselected → Light fill, dark border
    final unselected = await _createLocationIcon(
      fillColor: AppColors.main.withOpacity(0.4),
      borderColor: AppColors.main,
      size: 120, // smaller
      borderWidth: 6,
    );

    if (mounted) {
      setState(() {
        _pinSelected = selected;
        _pinUnselected = unselected;
      });
    }
  }



  Future<BitmapDescriptor> _drawPinIcon({
    required Color fillColor,
    required Color borderColor,
    required bool selected,
  }) async {
    const double circleDiameter = 72; // بكسل
    const double tailSize = 18;
    final double width = circleDiameter;
    final double height = circleDiameter + tailSize;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final Paint fill = Paint()..color = fillColor;
    final Paint border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final Paint shadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

    // الفقاعة
    final Offset circleCenter = Offset(width / 2, circleDiameter / 2);
    canvas.drawCircle(circleCenter.translate(0, 4), circleDiameter / 2, shadow);
    canvas.drawCircle(circleCenter, circleDiameter / 2, fill);
    if (!selected) {
      canvas.drawCircle(circleCenter, circleDiameter / 2 - 3, border);
    }

    // علامة طبية داخل الفقاعة
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '✚',
        style: TextStyle(
          fontSize: circleDiameter / 2.4,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : borderColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(circleCenter.dx - tp.width / 2, circleCenter.dy - tp.height / 2),
    );

    // الذيل (مربع مُدار 45°)
    final double tailTop = circleDiameter;
    canvas.save();
    canvas.translate(width / 2, tailTop + tailSize / 2);
    canvas.rotate(math.pi / 4);
    final Rect tailRect = Rect.fromCenter(center: Offset.zero, width: tailSize, height: tailSize);
    canvas.drawRect(tailRect, fill);
    if (!selected) {
      final Paint borderThin = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(tailRect.deflate(1.5), borderThin);
    }
    canvas.restore();

    final ui.Picture pict = recorder.endRecording();
    final ui.Image img = await pict.toImage(width.toInt(), height.toInt());
    final ByteData? pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(Uint8List.view(pngBytes!.buffer));
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

  Future<void> _applyMapStyle() async {
    final stylePath = _isDarkMode
        ? 'assets/map_style_dark.json'
        : 'assets/map_style_light.json';
    final style = await rootBundle.loadString(stylePath);
    await _gController?.setMapStyle(style);
  }


  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final LatLng initialCenter = () {
      const fallback = LatLng(33.5138, 36.2765); // دمشق
      final first = widget.results.isNotEmpty ? _getPointFor(widget.results.first) : null;
      return first ?? fallback;
    }();

    final Set<Marker> markers = {};
    for (int i = 0; i < widget.results.length; i++) {
      final doc = widget.results[i];
      final point = _getPointFor(doc);
      if (point == null) continue;

      final bool isSelected = identical(_selectedDoctor, doc);
      markers.add(
        Marker(
          markerId: MarkerId('doc_$i'),
          position: point,
          flat: false, // يبقي الـ Pin عموديًا حتى مع دوران الخريطة
          icon: (isSelected ? _pinSelected : _pinUnselected) ?? BitmapDescriptor.defaultMarker,
          onTap: () async {
            setState(() => _selectedDoctor = doc);

            final LatLng point = _getPointFor(doc)!;
            // إزاحة بسيطة للأعلى (بدل scrollBy بالبكسل)
            final LatLng adjustedPoint = LatLng(point.latitude + 0.002, point.longitude);

            await _gController?.animateCamera(
              CameraUpdate.newLatLng(adjustedPoint),
            );
          },
        ),
      );
    }

    final bool cardVisible = _selectedDoctor != null;

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
            // أثناء ظهور الكارد: أضف padding سفلي حتى لا تغطي العلامات/العناصر
            padding: EdgeInsets.only(bottom: cardVisible ? (_bottomCardHeight + 24) : 0),
            markers: markers,
            onTap: (_) => setState(() => _selectedDoctor = null),
            rotateGesturesEnabled: true,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            compassEnabled: false,
          ),


          // زر "موقعي" — يعلو الكارد تلقائيًا
          Positioned(
            right: 16,
            bottom: cardVisible ? (_bottomCardHeight + 40) : 24,
            child: Theme(
              // تغيير لون الـ ripple إلى لون التطبيق
              data: Theme.of(context).copyWith(
                splashColor: AppColors.main.withOpacity(0.20),
                highlightColor: AppColors.main.withOpacity(0.10),
              ),
              child: FloatingActionButton(
                heroTag: 'myLoc',
                backgroundColor: Colors.white,
                splashColor: AppColors.main.withOpacity(0.1),
                elevation: 3,
                onPressed: () async {
                  // TODO: اجلب موقع المستخدم وحرّك الكاميرا
                  // final userLatLng = LatLng(..., ...);
                  // await _gController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 15));
                },
                child: const Icon(Icons.my_location, color: Colors.black87),
              ),
            ),
          ),

          // ===== Back FAB =====
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

          // ===== Search here =====
          Positioned(
            top: 60.h,
            right: 16.w,
            child: Material(
              color: Colors.white,
              elevation: 2,
              shape: const StadiumBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  // final bounds = await _gController?.getVisibleRegion();
                  // widget.onSearchHere?.call(bounds);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Text(
                    t.searchHere,
                    style: AppTextStyles.getText2(context),
                  ),
                ),
              ),
            ),
          ),

          // ===== Bottom info card =====
          if (_selectedDoctor != null)
            _BottomDoctorCard(
              doctor: _selectedDoctor!,
              onViewProfile: () {
                // TODO: الانتقال لصفحة ملف الطبيب
              },
            ),
        ],
      ),
    );
  }
}

class _BottomDoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onViewProfile;

  const _BottomDoctorCard({
    required this.doctor,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // ✅ Reuse your avatar resolver logic
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final imageProvider = imageResult.imageProvider;

    final name = "${doctor['title'] ?? ''} ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}".trim();
    final specialty = (doctor['specialty'] ?? '').toString();

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          height: _FullMapResultsPageState._bottomCardHeight, // نفس القيمة المستخدمة للحساب
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.mainDark.withOpacity(0.2),
                    radius: 28.sp,
                    backgroundImage: imageProvider, // ✅ fallback جاهز
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Divider(height: 1, color: Colors.grey.shade300),
              ),
              Row(
                children: [
                  Icon(Icons.event_busy, size: 18, color: Colors.grey.shade600),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      t.bookingNotAvailable,
                      style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onViewProfile,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.main),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    backgroundColor: Colors.white,
                  ),
                  child: Text(
                    t.viewProfile,
                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.main),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
