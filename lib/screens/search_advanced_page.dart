import 'dart:async';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/map_results_page.dart';
import 'package:docsera/services/supabase/supabase_search_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/rotating_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home/messages/message_select_patient.dart';

class SearchAdvancedPage extends StatefulWidget {
  final String mode; // "search" أو "message"
  final UserDocument? attachedDocument;

  const SearchAdvancedPage({
    Key? key,
    this.mode = "search",
    this.attachedDocument,
  }) : super(key: key);

  @override
  State<SearchAdvancedPage> createState() => _SearchAdvancedPageState();
}

class _SearchAdvancedPageState extends State<SearchAdvancedPage> {
  // ======= تحكم عام =======
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _locationCtrl = TextEditingController();
  final FocusNode _locationFocus = FocusNode();
  Timer? _debounce;
  bool _loadingSuggestions = false;
  bool _suppressSearchListener = false;
  List<_CityOption> _cityMatches = [];
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isFullyExpanded = false;
  bool _isCollapseArmed = false;

  static const double _sheetMax = 0.88;

  // ======= مفضلة المستخدم =======
  String? _userId;
  List<Map<String, dynamic>> _favoriteDoctors = [];

  // ======= خدمة البحث =======
  final SupabaseSearchService _searchService = SupabaseSearchService();

  // ======= اقتراحات =======
  List<_MixedSuggestion> _mixed = [];

  // ======= فلو التخصص + الموقع =======
  String? _selectedSpecialty;
  bool _locationStageActive = false;
  bool _isNearbySelected = false;
  LatLng? _myLatLng;

  // مدن ثابتة
  List<_CityOption> _cities = [];

  // ======= النتائج =======
  bool _isFetchingResults = false;
  List<Map<String, dynamic>> _results = [];

  // ======= حالة إظهار النتائج =======
  bool get _showingResults => _locationStageActive && _results.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _searchCtrl.addListener(() {
      if (_suppressSearchListener) return;
      if (_selectedSpecialty != null) {
        setState(() {
          _selectedSpecialty = null;
          _locationStageActive = false;
          _locationCtrl.clear();
          _isNearbySelected = false;
          _results.clear();
        });
      }
    });

    _loadUserIdAndFavorites();
    _sheetController.addListener(() {
      final maxExtent = _sheetMax;
      if (_sheetController.size >= maxExtent - 0.01 && !_isFullyExpanded) {
        setState(() => _isFullyExpanded = true);
      } else if (_sheetController.size < maxExtent - 0.01 && _isFullyExpanded) {
        setState(() => _isFullyExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _locationCtrl.dispose();
    _locationFocus.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ========= تهيئة المدن =========
  void _initCities(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    _cities = [
      _CityOption(ar: "دمشق", display: t.damascus, center: const LatLng(33.5138, 36.2765)),
      _CityOption(ar: "ريف دمشق", display: t.reefDamascus, center: const LatLng(33.5225, 36.3156)),
      _CityOption(ar: "حلب", display: t.aleppo, center: const LatLng(36.2021, 37.1343)),
      _CityOption(ar: "حمص", display: t.homs, center: const LatLng(34.7324, 36.7138)),
      _CityOption(ar: "حماة", display: t.hama, center: const LatLng(35.1318, 36.7578)),
      _CityOption(ar: "اللاذقية", display: t.latakia, center: const LatLng(35.5196, 35.7904)),
      _CityOption(ar: "دير الزور", display: t.deirEzzor, center: const LatLng(35.3366, 40.1408)),
      _CityOption(ar: "الرقة", display: t.raqqa, center: const LatLng(35.9594, 39.0074)),
      _CityOption(ar: "إدلب", display: t.idlib, center: const LatLng(35.9306, 36.6339)),
      _CityOption(ar: "درعا", display: t.daraa, center: const LatLng(32.6189, 36.1021)),
      _CityOption(ar: "طرطوس", display: t.tartus, center: const LatLng(34.8941, 35.8866)),
      _CityOption(ar: "الحسكة", display: t.alHasakah, center: const LatLng(36.4923, 40.7506)),
      _CityOption(ar: "القامشلي", display: t.qamishli, center: const LatLng(37.0553, 41.2223)),
      _CityOption(ar: "السويداء", display: t.suwayda, center: const LatLng(32.7090, 36.5695)),
    ];
  }

  // ========= مفضلة المستخدم =========
  Future<void> _loadUserIdAndFavorites() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? uid = prefs.getString('userId') ?? Supabase.instance.client.auth.currentUser?.id;
      _userId = uid;
      if (uid != null) {
        final response = await Supabase.instance.client
            .from('users')
            .select('favorites')
            .eq('id', uid)
            .single();

        final favIds = (response['favorites'] as List?)?.cast<dynamic>() ?? [];
        if (favIds.isEmpty) return;

        final List docs = await Supabase.instance.client
            .from('doctors')
            .select('*')
            .inFilter('id', favIds);

        setState(() => _favoriteDoctors = docs.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // تجاهل بهدوء
    }
  }

  // ========= اقتراحات =========
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() => _mixed = []);
        return;
      }
      setState(() => _loadingSuggestions = true);

      // أطباء: من خدمة Supabase (فلتر عميل)
      final doctorMatches = await _searchService.searchDoctors(q.toLowerCase());

      // تخصصات محلية
      final List<_SpecialtyOption> localSpecs = _buildLocalSpecialties(AppLocalizations.of(context)!);
      final specMatches = localSpecs
          .where((s) => s.name.toLowerCase().contains(q.toLowerCase()))
          .map((s) => _MixedSuggestion.specialty(s.name, s.icon))
          .toList();

      setState(() {
        _mixed = [
          ...doctorMatches.map(_MixedSuggestion.fromDoctor),
          ...specMatches,
        ];
        _loadingSuggestions = false;
      });
    });
  }

  // ========= اختيار تخصص =========
  void _selectSpecialty(String specialty) {
    setState(() {
      _selectedSpecialty = specialty;
      _suppressSearchListener = true;
      _searchCtrl.text = specialty;
      _locationStageActive = true;
      _cityMatches = List<_CityOption>.from(_cities);
      _locationCtrl.clear();
      _isNearbySelected = false;
      _results.clear();
    });
    Future.microtask(() => _suppressSearchListener = false);
    Future.delayed(Duration.zero, () => _locationFocus.requestFocus());
  }

  // ========= بالقرب مني =========
  Future<void> _pickNearby() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locationPermissionDenied)),
        );
        return;
      }

      final p = await Geolocator.getCurrentPosition();
      setState(() {
        _myLatLng = LatLng(p.latitude, p.longitude);
        _isNearbySelected = true;
        _locationCtrl.text = AppLocalizations.of(context)!.nearbyMe;
      });

      await _fetchResults();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.locationError)),
      );
    }
  }

  // ========= اختيار مدينة =========
  void _pickCity(_CityOption c) async {
    Navigator.pop(context);
    setState(() {
      _isNearbySelected = false;
      _myLatLng = null;
      _locationCtrl.text = c.display;
    });
    await _fetchResults();
  }

  // ========= جلب النتائج من Supabase =========
  Future<void> _fetchResults() async {
    if (_selectedSpecialty == null || _locationCtrl.text.trim().isEmpty) {
      setState(() {
        _results.clear(); // No results if one field is empty
      });
      return;
    }

    setState(() => _isFetchingResults = true);

    try {
      List<Map<String, dynamic>> list;

      if (_isNearbySelected && _myLatLng != null) {
        list = await _searchService.fetchBySpecialtyNearby(
          specialty: _selectedSpecialty!,
          userLat: _myLatLng!.latitude,
          userLng: _myLatLng!.longitude,
        );
      } else {
        final selectedCity = _cities.firstWhere(
              (c) => c.display == _locationCtrl.text.trim(),
          orElse: () => _CityOption.empty(),
        );
        list = await _searchService.fetchBySpecialtyAndCity(
          specialty: _selectedSpecialty!,
          cityAr: selectedCity.ar,
        );
      }

      setState(() {
        _results = list;
        _isFetchingResults = false;
      });
    } catch (_) {
      setState(() {
        _isFetchingResults = false;
        _results.clear();
      });
    }
  }

  // ========= بطاقة طبيب =========
  Widget _doctorTile(Map<String, dynamic> doctor) {
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final imageProvider = imageResult.imageProvider;
    final t = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mainDark.withOpacity(0.2),
        radius: 22.sp,
        backgroundImage: imageProvider,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${doctor['title'] ?? ''} ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}".trim(),
            style: AppTextStyles.getText2(context).copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.mainDark,
            ),
          ),
          if (doctor['messagingEnabled'] == false)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  t.messagingDisabled,
                  style: AppTextStyles.getText3(context).copyWith(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${doctor['specialty'] ?? ''} • ${doctor['clinic'] ?? ''}",
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.location_on, size: 12.sp, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                doctor['address']?['city'] ?? "",
                style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
              ),
            ],
          ),
          if (doctor['_distanceKm'] != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "${(doctor['_distanceKm'] as double).toStringAsFixed(1)} km",
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
      onTap: () {
        if (widget.mode == "message") {
          Navigator.push(
            context,
            fadePageRoute(
              SelectPatientForMessagePage(
                doctorId: doctor['id'],
                doctorName: "${doctor['title'] ?? ''} ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}".trim(),
                doctorGender: doctor['gender'],
                doctorTitle: doctor['title'],
                specialty: doctor['specialty'],
                doctorImage: imageProvider,
                doctorImageUrl: avatarPath,
                attachedDocument: widget.attachedDocument,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            fadePageRoute(DoctorProfilePage(doctor: doctor, doctorId: doctor['id'])),
          );
        }
      },
    );
  }

  // ========= واجهة تخصص ضمن الاقتراحات =========
  Widget _specialtySuggestionTile(String name, IconData icon) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.main.withOpacity(0.12),
        child: Icon(icon, color: AppColors.main),
      ),
      title: Text(name, style: AppTextStyles.getText2(context)),
      subtitle: Text(
        AppLocalizations.of(context)!.searchBySpecialty,
        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
      ),
      trailing: const Icon(Icons.arrow_outward, size: 18, color: Colors.grey),
      onTap: () => _selectSpecialty(name),
    );
  }

  // ========= واجهة المفضلة =========
  Widget _favoritesSection() {
    final t = AppLocalizations.of(context)!;
    if (_favoriteDoctors.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 16.w, top: 8.h),
          child: Text(
            t.noFavorites,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, size: 14.sp, color: Colors.grey.shade600),
            SizedBox(width: 5.w),
            Text(
              t.favoritesTitle,
              style: AppTextStyles.getText2(context)
                  .copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _favoriteDoctors.length,
          itemBuilder: (_, i) => _doctorTile(_favoriteDoctors[i]),
        ),
      ],
    );
  }

  // ========= واجهة الاقتراحات المختلطة =========
  Widget _buildMixedSuggestions() {
    final t = AppLocalizations.of(context)!;
    if (_mixed.isEmpty) {
      return Center(
        child: Text(
          t.noResultsTitle,
          style: AppTextStyles.getTitle2(context),
        ),
      );
    }
    return ListView.builder(
      itemCount: _mixed.length,
      itemBuilder: (_, i) {
        final m = _mixed[i];
        if (m.type == _MixedType.doctor) {
          return _doctorTile(m.doctor!);
        } else {
          return _specialtySuggestionTile(m.specialtyName!, m.icon!);
        }
      },
    );
  }

  void _onCityChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _isNearbySelected = false;
      _myLatLng = null;
      _cityMatches = q.isEmpty
          ? List<_CityOption>.from(_cities)
          : _cities.where((c) => c.display.toLowerCase().contains(q) || c.ar.contains(q)).toList();
    });
  }

  // ========= شريحة النتائج =========
  Widget _buildResultsSheet() {
    return GestureDetector(
      onVerticalDragStart: (details) {
        if (_isFullyExpanded && details.localPosition.dy > 40) {
          // Ignore drag if user started from below the top bar
          return;
        }
      },
      child: _ResultsSheet(
        isLoading: _isFetchingResults,
        results: _results,
        doctorItemBuilder: (d) => _doctorTile(d),
        controller: _sheetController, // same controller you already use
        maxChildSize: _sheetMax,
      ),
    );
  }


  Widget _buildSelectedSummaryBarWrapper() {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.12, // always 12% of screen height
      child: _buildSelectedSummaryBar(),
    );
  }


  // ========= شريط عرض (التخصص • المدينة) عند ظهور النتائج =========
  Widget _buildSelectedSummaryBar() {
    final t = AppLocalizations.of(context)!;

    final cityDisplay = _isNearbySelected
        ? t.nearbyMe
        : _cities.firstWhere(
          (c) => c.display == _locationCtrl.text,
      orElse: () => _CityOption.empty(),
    ).display;

    return InkWell(
      onTap: () {
        setState(() {
          _results.clear();
        });
        Future.delayed(Duration.zero, () => _locationFocus.requestFocus());
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.background2,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.filter_alt_rounded,
                  color: AppColors.main, size: 20),
            ),
            SizedBox(width: 10.w),

            // Tags for specialty and city
            Expanded(
              child: Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  if (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty)
                    _buildTag(_selectedSpecialty!, AppColors.main),
                  if (cityDisplay.isNotEmpty)
                    _buildTag(cityDisplay, Colors.grey.shade600),
                ],
              ),
            ),

            // Edit icon
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.grey, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTextStyles.getText3(context).copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ========= حقل الموقع =========
  Widget _buildLocationField(AppLocalizations t) {
    return TextField(
      controller: _locationCtrl,
      focusNode: _locationFocus,
      readOnly: false,
      onChanged: (value) {
        _onCityChanged(value);
        _triggerLiveSearch();
      },
      style: AppTextStyles.getText2(context),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background2,
        labelText: t.selectCityPlaceholder,
        labelStyle: AppTextStyles.getText2(context).copyWith(
          color: Colors.grey.shade600,
        ),
        floatingLabelStyle: AppTextStyles.getText3(context).copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.main,
        ),
        prefixIcon: Icon(Icons.place, color: AppColors.main, size: 22.sp),
        suffixIcon: _locationCtrl.text.isNotEmpty
            ? IconButton(
          icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20.sp),
          onPressed: () {
            _locationCtrl.clear();
            _onCityChanged('');
            _triggerLiveSearch();
          },
        )
            : null,
        contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main, width: 2),
        ),
      ),
    );
  }

  void _triggerLiveSearch() {
    if (_selectedSpecialty != null && _isCityConfirmed) {
      _fetchResults();
    } else {
      setState(() {
        _results.clear();
      });
    }
  }



  Widget _buildCitySuggestions() {
    final t = AppLocalizations.of(context)!;

    final q = _locationCtrl.text.trim();
    final items = q.isEmpty
        ? _cities
        : _cityMatches; // don't fallback to all if no matches

    if (q.isNotEmpty && items.isEmpty) {
      return Center(
        child: Text(
          t.noResultsTitle,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.my_location, color: AppColors.main),
          title: Text(t.nearbyMe, style: AppTextStyles.getText2(context)),
          onTap: _pickNearby,
        ),
        const Divider(height: 1),

        ...items.map((c) => ListTile(
          leading: const Icon(Icons.location_city, color: Colors.grey),
          title: Text(c.display, style: AppTextStyles.getText2(context)),
          onTap: () async {
            _locationCtrl.text = c.display;
            _isNearbySelected = false;
            _myLatLng = null;
            setState(() {});
            await _fetchResults();
          },
        )),
      ],
    );
  }


  // ========= خلفية خريطة (صورة ثابتة) مع زر "عرض على الخريطة" =========
  Widget _buildStaticMapBackground() {
    return Stack(
      children: [
        // صورة الخريطة
        Align(
          alignment: Alignment.topCenter,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(1.0, -1.0), // قلب عمودي
            child: Image.asset(
              'assets/images/map.png',
              fit: BoxFit.fitWidth,
              width: double.infinity, // يضمن ملء العرض
            ),
          ),
        ),
      ],
    );
  }

  Widget _openMapButton() {
    final t = AppLocalizations.of(context)!;
    return Center( // ⬅️ Centers the button horizontally
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mainDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        ),
        icon: const Icon(Icons.location_on, color: Colors.white),
        label: Text(
          t.openInMaps, // or t.showOnMap
          style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
        ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullMapResultsPage(results: _results),
              ),
            );
          }

      ),
    );
  }

  bool get _isCityConfirmed {
    final txt = _locationCtrl.text.trim();
    if (txt.isEmpty) return false;
    if (_isNearbySelected) return true;
    return _cities.any((c) => c.display == txt || c.ar == txt);
  }



  // ========= الجسم =========
  @override
  Widget build(BuildContext context) {
    _initCities(context);
    final t = AppLocalizations.of(context)!;

    return BaseScaffold(
      title: Text(
        widget.mode == "message" ? t.sendMessageTitle : t.searchTitle,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Stack(
        children: [
          // خلفية خريطة ثابتة تظهر فقط عند وجود نتائج
// Inside build -> Stack background:
          // خلفية خريطة ثابتة تظهر فقط عند وجود نتائج
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _showingResults
                ? (_isFullyExpanded
                ? Container(
              key: const ValueKey('bg4'),
              color: AppColors.background4,
            )
                : Container(
              key: const ValueKey('map'),
              child: _buildStaticMapBackground(),
            ))
                : const SizedBox.shrink(key: ValueKey('empty-bg')),
          ),


          // المحتوى الرئيسي
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // ====== الحقل العلوي ======
                if (!_showingResults)
                  TextField(
                    focusNode: _searchFocus,
                    controller: _searchCtrl,
                    style: AppTextStyles.getText2(context),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background2, // ✅ Background color
                      labelText: t.searchHint,
                      labelStyle: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey.shade600,
                      ),
                      floatingLabelStyle: AppTextStyles.getText3(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.main,
                      ),
                      prefixIcon: Icon(Icons.search, color: AppColors.main, size: 22.sp),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20.sp),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _mixed = [];
                            _selectedSpecialty = null;
                            _locationStageActive = false;
                            _locationCtrl.clear();
                            _results.clear();
                          });
                        },
                      )
                          : null,
                      contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: BorderSide.none, // ✅ No border by default
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: BorderSide(color: AppColors.main, width: 2),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                  )
                else
                  _buildSelectedSummaryBar(),


                // 👉 Add the button here when results are visible
                if (_showingResults) ...[
                  SizedBox(height: 50.h),
                  _openMapButton(),
                ],


                // ====== حقل المدينة (يختفي عند ظهور النتائج) ======
                if (_locationStageActive && !_showingResults) ...[
                  SizedBox(height: 10.h),
                  _buildLocationField(t),
                ],

                SizedBox(height: 16.h),

                // ====== اقتراحات/مفضلة (تختفي عند ظهور النتائج) ======
                Expanded(
                  child: _showingResults
                      ? const SizedBox() // ⬅️ Don't render results here, bottom sheet will handle it
                      : _locationStageActive
                      ? (_selectedSpecialty != null && _isCityConfirmed)
                      ? (_isFetchingResults
                      ? const Center(child: RotatingLogoLoader(size: 50))
                      : (_results.isEmpty
                      ? Center(
                    child: Text(
                      t.noResultsTitle,
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                    ),
                  )
                      : const SizedBox())) // No duplicate list here
                      : _buildCitySuggestions()
                      : (_searchCtrl.text.isEmpty
                      ? _favoritesSection()
                      : _buildMixedSuggestions()),
                )



              ],
            ),
          ),

          // ====== BottomSheet نتائج (قابل للسحب من الأعلى) ======
          if (_showingResults) _buildResultsSheet(),

          if (_loadingSuggestions)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  // ===== بناء قائمة التخصصات المحلية =====
  List<_SpecialtyOption> _buildLocalSpecialties(AppLocalizations t) {
    return [
      _SpecialtyOption(t.specialtyGynecology, Icons.pregnant_woman),
      _SpecialtyOption(t.specialtyPediatrics, Icons.child_care),
      _SpecialtyOption(t.specialtyDentistry, Icons.medical_services),
      _SpecialtyOption(t.specialtyCardiology, Icons.favorite),
      _SpecialtyOption(t.specialtyOphthalmology, Icons.remove_red_eye),
      _SpecialtyOption(t.specialtyUrology, Icons.water_drop),
      _SpecialtyOption(t.specialtyDermatology, Icons.face),
      _SpecialtyOption(t.specialtyPsychology, Icons.psychology),
      _SpecialtyOption(t.specialtyNutrition, Icons.local_dining),
      _SpecialtyOption(t.specialtyNeurology, Icons.memory),
      _SpecialtyOption(t.specialtyOrthopedics, Icons.directions_walk),
      _SpecialtyOption(t.specialtyOncology, Icons.coronavirus),
      _SpecialtyOption(t.specialtyENT, Icons.hearing),
      _SpecialtyOption(t.specialtyGeneralSurgery, Icons.bed),
    ];
  }
}

// ==================== نماذج مساعدة ====================

class _SpecialtyOption {
  final String name;
  final IconData icon;
  _SpecialtyOption(this.name, this.icon);
}

enum _MixedType { doctor, specialty }

class _MixedSuggestion {
  final _MixedType type;
  final Map<String, dynamic>? doctor;
  final String? specialtyName;
  final IconData? icon;

  _MixedSuggestion._(this.type, this.doctor, this.specialtyName, this.icon);

  static _MixedSuggestion fromDoctor(Map<String, dynamic> d) =>
      _MixedSuggestion._(_MixedType.doctor, d, null, null);

  static _MixedSuggestion specialty(String name, IconData icon) =>
      _MixedSuggestion._(_MixedType.specialty, null, name, icon);
}

class _CityOption {
  final String ar;       // القيمة في قاعدة البيانات (عربي)
  final String display;  // نص العرض (محلي)
  final LatLng? center;
  _CityOption({required this.ar, required this.display, this.center});
  _CityOption.empty() : ar = '', display = '', center = null;
}

// ==================== BottomSheet النتائج ====================

class _ResultsSheet extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final Widget Function(Map<String, dynamic>) doctorItemBuilder;
  final DraggableScrollableController controller; // 👈 add this
  final double maxChildSize; // optional

  const _ResultsSheet({
    required this.isLoading,
    required this.results,
    required this.doctorItemBuilder,
    required this.controller,   // 👈
    this.maxChildSize = 0.88,   // default matches parent
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.7,
      minChildSize: 0.7,
      maxChildSize: maxChildSize,
      snap: false,
      builder: (context, controller) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                // ===== Drag Handle =====
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 15),
                  child: Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),

                // ===== Wider Divider =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30), // ~70% width
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: Colors.grey.shade300,
                  ),
                ),

                // ===== Results Text with Badge =====
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        t.results,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.grayMain,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          results.length.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


                if (isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.main,
                    backgroundColor: Colors.transparent,
                  ),

                // ===== Results List =====
                Expanded(
                  child: results.isEmpty && !isLoading
                      ? Center(
                    child: Text(
                      t.noResultsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  )
                      : ListView.separated(
                    controller: controller,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12), // extra space between items
                    itemBuilder: (_, i) => doctorItemBuilder(results[i]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
