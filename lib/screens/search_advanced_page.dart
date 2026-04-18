import 'dart:async';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/centers/center_profile_page.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/map_results_page.dart';
import 'package:docsera/services/supabase/specialties_service.dart';
import 'package:docsera/services/supabase/supabase_search_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/geography_constants.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/rotating_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home/messages/message_select_patient.dart';

class SearchAdvancedPage extends StatefulWidget {
  final String mode; // "search" أو "message"
  final UserDocument? attachedDocument;

  const SearchAdvancedPage({
    super.key,
    this.mode = "search",
    this.attachedDocument,
  });

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

  static const double _sheetMax = 0.88;

  // ======= مفضلة المستخدم =======
  // String? _userId;
  List<Map<String, dynamic>> _favoriteDoctors = [];

  // ======= خدمة البحث =======
  final SupabaseSearchService _searchService = SupabaseSearchService();

  // ======= اقتراحات =======
  List<_MixedSuggestion> _mixed = [];

  // ======= Specialties from DB =======
  List<_SpecialtyOption>? _dbSpecialties;

  // ======= فلو التخصص + الموقع =======
  String? _selectedSpecialty; // التخصص الأساسي (للحقل والبحث المبدئي)
  String? _selectedSpecialtyKey; // specialty key for DB queries
  List<String> _cachedNeighborhoods = []; // cached from _results
  _CityOption? _zonePendingCity; // non-null = showing zone picker for this city
  bool _locationStageActive = false;
  bool _isNearbySelected = false;
  LatLng? _myLatLng;

  // قيمة مؤقتة للسلايدر قبل تثبيت "تم"
  double _nearbyTempKm = 5;

  // مدن ثابتة
  List<_CityOption> _cities = [];

  // ======= النتائج =======
  bool _isFetchingResults = false;
  List<Map<String, dynamic>> _results = [];

  // ======= فلاتر فعّالة + نتائج بعد التصفية =======
  FilterOptions _filters = const FilterOptions(); // الافتراضي: بدون تصفية
  List<Map<String, dynamic>> _filteredResults = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  List<Map<String, dynamic>> _filteredCenters = [];

  bool get _showingResults => _locationStageActive && _filteredResults.isNotEmpty && _zonePendingCity == null;

  @override
  void initState() {
    super.initState();
    _loadSpecialtiesFromDb();

    // عند الكتابة في حقل البحث:
    _searchCtrl.addListener(() {
      if (_suppressSearchListener) return;
      // إذا كان هناك تخصص مُختار سابقًا ثم بدأ يكتب، نعيد الضبط
      if (_selectedSpecialty != null) {
        setState(() {
          _selectedSpecialty = null;
          _filters = _filters.copyWith(neighborhood: null);
          _zonePendingCity = null;
          _locationStageActive = false;
          _locationCtrl.clear();
          _isNearbySelected = false;
          _results.clear();
          _filteredResults.clear();
        });
      }
    });

    // ✅ عند التركيز على حقل البحث وهو فارغ: أظهر كل التخصصات فورًا
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        // نؤجل لِما بعد توفر الـ context مع اللغات
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_searchCtrl.text.trim().isEmpty) {
            final t = AppLocalizations.of(context)!;
            setState(() {
              _mixed = _allSpecialtiesAsMixed(t);
              _loadingSuggestions = false;
            });
          }
        });
      } else {
        // يمكن ترك القائمة كما هي أو تفريغها عند فقدان التركيز، نتركها كما هي ليستفيد منها المستخدم
      }
    });

    _loadUserIdAndFavorites();
    _sheetController.addListener(() {
      const maxExtent = _sheetMax;
      final isNowFull = _sheetController.size >= maxExtent - 0.01;
      if (isNowFull != _isFullyExpanded) {
        setState(() => _isFullyExpanded = isNowFull);
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
      final client = Supabase.instance.client;

      final res = await client.rpc('rpc_get_my_favorite_doctors');

      if (res == null || res is! List) {
        setState(() => _favoriteDoctors = []);
        return;
      }

      setState(() {
        _favoriteDoctors = List<Map<String, dynamic>>.from(res);
      });

    } catch (e) {
      debugPrint("❌ Failed to load favorite doctors: $e");
      setState(() => _favoriteDoctors = []);
    }
  }

  // ========= اقتراحات =========
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      // ✅ إذا كان الحقل فارغ ومركّز: أعرض كل التخصصات بدل تفريغ القائمة
      if (q.isEmpty) {
        if (_searchFocus.hasFocus) {
          final t = AppLocalizations.of(context)!;
          setState(() {
            _mixed = _allSpecialtiesAsMixed(t);
            _loadingSuggestions = false;
          });
        } else {
          setState(() => _mixed = []);
        }
        return;
      }

      setState(() => _loadingSuggestions = true);

      // Fetch doctors and centers in parallel
      final results = await Future.wait([
        _searchService.searchDoctors(q.toLowerCase()),
        _searchService.searchCenters(q.toLowerCase()),
      ]);

      final List<Map<String, dynamic>> doctorMatches = results[0] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> centerMatches = widget.mode == "message"
          ? <Map<String, dynamic>>[]
          : results[1] as List<Map<String, dynamic>>;

      final List<_SpecialtyOption> localSpecs = _buildLocalSpecialties(AppLocalizations.of(context)!);
      final specMatches = localSpecs
          .where((s) => s.name.toLowerCase().contains(q.toLowerCase()))
          .map((s) => _MixedSuggestion.specialty(s.name, s.asset, s.key))
          .toList();

      setState(() {
        _mixed = [
          ...specMatches,
          ...doctorMatches.map(_MixedSuggestion.fromDoctor),
          ...centerMatches.map(_MixedSuggestion.fromCenter),
        ];
        _loadingSuggestions = false;
      });
    });
  }

  // يبني قائمة كل التخصصات كاقتراحات جاهزة
  List<_MixedSuggestion> _allSpecialtiesAsMixed(AppLocalizations t) {
    return _buildLocalSpecialties(t)
        .map((s) => _MixedSuggestion.specialty(s.name, s.asset, s.key))
        .toList();
  }


  // ========= اختيار تخصص من الاقتراحات =========
  void _selectSpecialty(String specialty, String specialtyKey) {
    setState(() {
      _selectedSpecialty = specialty;
      _selectedSpecialtyKey = specialtyKey;
      _suppressSearchListener = true;
      _searchCtrl.text = specialty;
      _locationStageActive = true;
      _cityMatches = List<_CityOption>.from(_cities);
      _locationCtrl.clear();
      _isNearbySelected = false;
      _results.clear();
      _filteredResults.clear();
      _zonePendingCity = null;
      _filters = const FilterOptions(); // تصفير الفلاتر عند بدء بحث جديد
    });
    Future.microtask(() => _suppressSearchListener = false);
    Future.delayed(Duration.zero, () => _locationFocus.requestFocus());
  }

  // ========= lookup specialty key from display name =========
  String _specNameToKey(String displayName) {
    final allSpecs = _buildLocalSpecialties(AppLocalizations.of(context)!);
    for (final s in allSpecs) {
      if (s.name == displayName) return s.key;
    }
    return displayName; // fallback
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
        _nearbyTempKm = _filters.nearbyKm ?? 5;
        _filters = _filters.copyWith(byNearby: true, nearbyKm: null); // لا نتائج قبل تثبيت المسافة
        _locationCtrl.text = AppLocalizations.of(context)!.nearbyMe;
      });

      // ⚠️ لا نجلب النتائج الآن — سننتظر حتى يضغط المستخدم "تم" في السلايدر
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.locationError)),
      );
    }
  }


  // ========= جلب النتائج من Supabase مع دعم تخصصات متعددة =========
  Future<void> _fetchResults() async {
    // تحديد التخصصات المطلوبة (as specialty keys for DB queries)
    final Set<String> selectedSpecKeys = _filters.specs.isNotEmpty
        ? _filters.specs.map(_specNameToKey).toSet()
        : (_selectedSpecialtyKey != null && _selectedSpecialtyKey!.isNotEmpty)
        ? {_selectedSpecialtyKey!}
        : <String>{};

    // إلغاء البحث إذا لم يتم اختيار تخصص أو مدينة/بالقرب مني (ومسافة)
    final bool hasLocationReady = _isNearbySelected
        ? (_myLatLng != null && _filters.nearbyKm != null)
        : _locationCtrl.text.trim().isNotEmpty;

    if (selectedSpecKeys.isEmpty || !hasLocationReady) {
      setState(() {
        _results.clear();
        _filteredResults.clear();
      });
      return;
    }

    setState(() => _isFetchingResults = true);

    try {
      final Map<dynamic, Map<String, dynamic>> merged = {}; // دمج النتائج حسب الـ id

      // تحديد المدينة الفعّالة إذا لم يكن البحث بالقرب مني
      final effectiveCity = (_filters.cityDisplay != null && _filters.cityDisplay!.isNotEmpty)
          ? _filters.cityDisplay!
          : _locationCtrl.text.trim();

      final selectedCity = _cities.firstWhere(
            (c) => c.display == effectiveCity,
        orElse: () => _CityOption.empty(),
      );

      // جلب النتائج لكل تخصص
      for (final specKey in selectedSpecKeys) {
        // Parallel fetch for doctors and centers
        final results = await Future.wait([
          // Doctor fetch
          _isNearbySelected && _myLatLng != null
              ? _searchService.fetchBySpecialtyNearby(
            specialtyKey: specKey,
            userLat: _myLatLng!.latitude,
            userLng: _myLatLng!.longitude,
            radiusKm: _filters.nearbyKm ?? 5,
          )
              : _searchService.fetchBySpecialtyAndCity(
            specialtyKey: specKey,
            cityAr: selectedCity.ar,
          ),
          // Center fetch
          _isNearbySelected && _myLatLng != null
              ? _searchService.fetchCentersBySpecialtyNearby(
            specialtyKey: specKey,
            userLat: _myLatLng!.latitude,
            userLng: _myLatLng!.longitude,
            radiusKm: _filters.nearbyKm ?? 5,
          )
              : _searchService.fetchCentersBySpecialtyAndCity(
            specialtyKey: specKey,
            cityAr: selectedCity.ar,
          ),
        ]);

        final List<Map<String, dynamic>> doctors = 
            results[0].map((d) => {...d, 'search_type': 'doctor'}).toList();
        final List<Map<String, dynamic>> centers = 
            widget.mode == "message"
                ? []
                : results[1].map((c) => {...c, 'search_type': 'center'}).toList();

        // دمج النتائج بدون تكرار
        for (final d in doctors) {
          merged[d['id']] = d;
        }
        for (final c in centers) {
          merged[c['id']] = c;
        }
      }

      setState(() {
        _results = merged.values.toList();
        _isFetchingResults = false;
        _updateNeighborhoodCache();
      });

      _applyFilters(); // تطبيق الفلاتر الإضافية (مثل الجنس)
    } catch (e) {
      debugPrint("❌ Advanced Search Error: $e");
      setState(() {
        _isFetchingResults = false;
        _results.clear();
        _filteredResults.clear();
      });
    }
  }

  // ========= تطبيق الفلاتر محليًا =========
  void _applyFilters() {
    List<Map<String, dynamic>> base = List<Map<String, dynamic>>.from(_results);

    // فلتر الجنس
    final bool filterMale = _filters.male;
    final bool filterFemale = _filters.female;

    if (filterMale != filterFemale) {
      base = base.where((d) {
        final g = (d['gender'] ?? '').toString().trim().toLowerCase();
        final isMale = g.startsWith('m') || g.contains('ذكر');
        final isFemale = g.startsWith('f') || g.contains('أنث');
        return filterMale ? isMale : isFemale;
      }).toList();
    }

    // فلتر الحي/المنطقة
    if (_filters.neighborhood != null) {
      base = base.where((d) {
        return (d['address']?['neighborhood'] ?? '') == _filters.neighborhood;
      }).toList();
    }

    // (اختياري) فلتر التخصصات محليًا كطبقة أمان
    if (_filters.specs.isNotEmpty) {
      final specKeys = _filters.specs.map(_specNameToKey).toSet();
      base = base.where((d) {
        final dk = (d['specialty_key'] ?? '').toString();
        return specKeys.contains(dk);
      }).toList();
    }

    setState(() {
      _filteredResults = base;
      _filteredDoctors = _filteredResults.where((r) => r['search_type'] == 'doctor').toList();
      _filteredCenters = _filteredResults.where((r) => r['search_type'] == 'center').toList();
    });
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

  // ========= بطاقة مركز =========
  Widget _centerTile(Map<String, dynamic> center) {
    final imageResult = resolveCenterImagePathAndWidget(center: center);
    final imageProvider = imageResult.imageProvider;
    // final t = AppLocalizations.of(context)!;

    final specialties = (center['specialties'] as List?)?.join(' • ') ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mainDark.withOpacity(0.2),
        radius: 22.sp,
        backgroundImage: imageProvider,
      ),
      title: Text(
        (center['name'] ?? "").toString(),
        style: AppTextStyles.getText2(context).copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.mainDark,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (specialties.isNotEmpty)
            Text(
              specialties,
              style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
            ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.location_on, size: 12.sp, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                center['address']?['city'] ?? "",
                style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
              ),
            ],
          ),
          if (center['_distanceKm'] != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "${(center['_distanceKm'] as double).toStringAsFixed(1)} km",
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
      onTap: () {
        if (widget.mode == "search") {
          Navigator.push(
            context,
            fadePageRoute(CenterProfilePage(centerId: center['id'])),
          );
        }
      },
    );
  }

  // ========= واجهة تخصص ضمن الاقتراحات =========
  Widget _specialtySuggestionTile(String name, String asset, String key) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.withOpacity(0.08),
        child: SvgPicture.asset(
          asset,
          width: 25.w,
          height: 25.w,
          colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
        ),
      ),
      title: Text(name, style: AppTextStyles.getText2(context)),
      subtitle: Text(
        AppLocalizations.of(context)!.searchBySpecialty,
        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
      ),
      trailing: const Icon(Icons.arrow_outward, size: 18, color: Colors.grey),
      onTap: () => _selectSpecialty(name, key),
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
          physics: const ClampingScrollPhysics(),
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
          style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _mixed.length,
      itemBuilder: (_, i) {
        final m = _mixed[i];
        if (m.type == _MixedType.doctor) {
          return _doctorTile(m.doctor!);
        } else if (m.type == _MixedType.center) {
          return _centerTile(m.center!);
        } else {
          return _specialtySuggestionTile(m.specialtyName!, m.asset!, m.specialtyKey!);
        }
      },
    );
  }

  void _onCityChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _zonePendingCity = null;
      _isNearbySelected = false;
      _myLatLng = null;
      _filters = _filters.copyWith(byNearby: false, nearbyKm: null, cityDisplay: null, neighborhood: null);
      _cityMatches = q.isEmpty
          ? List<_CityOption>.from(_cities)
          : _cities.where((c) => c.display.toLowerCase().contains(q) || c.ar.contains(q)).toList();
    });
  }

  // ========= الدخول لوضع التحرير من شريط الملخّص =========
  void _enterEditMode() {
    setState(() {
      _locationStageActive = true;
      _zonePendingCity = null;
      _results.clear();
      _filteredResults.clear();
      _filters = const FilterOptions();
      _locationCtrl.clear();
      _isNearbySelected = false;
      _cityMatches = List<_CityOption>.from(_cities);
    });
    Future.delayed(Duration.zero, () => _locationFocus.requestFocus());
  }

  // ========= فتح صفحة الفلاتر =========
  Future<void> _openFilters() async {
    final t = AppLocalizations.of(context)!;

    // حضّر initial يعكس المختارات الفعلية الآن
    final currentCity = _locationCtrl.text.trim();
    final effectiveInitial = _filters.copyWith(
      specs: {
        ..._filters.specs,
        if (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty) _selectedSpecialty!,
      },
      byNearby: _isNearbySelected ? true : _filters.byNearby,
      cityDisplay: _isNearbySelected
          ? null
          : (currentCity.isNotEmpty ? currentCity : _filters.cityDisplay),
    );

    final result = await Navigator.push<FilterOptions>(
      context,
      MaterialPageRoute(
        builder: (_) => FiltersPage(
          initial: effectiveInitial,
          allSpecs: _buildLocalSpecialties(t).map((s) => s.name).toList(),
          allCities: _cities.map((c) => c.display).toList(),
          selectedSpecialty: _selectedSpecialty, // لإظهاره أولاً
          isNearbyAvailable: _myLatLng != null || _isNearbySelected,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      // حدّد مجموعة التخصصات السابقة واللاحقة للمقارنة
      final Set<String> prevSpecs = _filters.specs.isNotEmpty
          ? _filters.specs
          : (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty)
          ? {_selectedSpecialty!}
          : <String>{};

      final Set<String> newSpecs = result.specs;

      // اختر تخصصًا أساسيًا للحقل (الأول من المجموعة إن وُجد)
      String? newPrimary = _selectedSpecialty;
      if (newSpecs.isNotEmpty) {
        newPrimary = newSpecs.first;
      }

      // الموقع:
      final wasNearby = _isNearbySelected;
      final newNearby = result.byNearby && (_myLatLng != null || wasNearby);
      final oldCity = _locationCtrl.text.trim();
      final newCity = (result.cityDisplay ?? '').trim();

      final locationChanged = (newNearby != wasNearby) ||
          (!newNearby && newCity.isNotEmpty && newCity != oldCity);
      final specsChanged = _setEquals(prevSpecs, newSpecs);

      // حدّث الحالة الظاهرة في الشريط
      setState(() {
        _filters = result;
        _selectedSpecialty = newPrimary ?? _selectedSpecialty;
        _selectedSpecialtyKey = _specNameToKey(_selectedSpecialty ?? '');

        if (newNearby && _myLatLng != null) {
          _isNearbySelected = true;
          _nearbyTempKm = _filters.nearbyKm ?? 5;
          _locationCtrl.text = t.nearbyMe;
        } else if (!newNearby && newCity.isNotEmpty) {
          _isNearbySelected = false;
          _myLatLng = null;
          _locationCtrl.text = newCity;
        }
      });

      // إن تغيّر الموقع أو مجموعة التخصصات => إعادة جلب من السيرفر
      if (locationChanged || specsChanged) {
        setState(() {
          _zonePendingCity = null;
          _filters = _filters.copyWith(neighborhood: null);
        });
        await _fetchResults();
      } else {
        _applyFilters(); // تغييرات محلية (جنس فقط غالبًا)
      }
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return true; // مختلفان
    for (final v in a) {
      if (!b.contains(v)) return true;
    }
    return false; // متساويان
  }

  // ========= شريحة النتائج =========
  Widget _buildResultsSheet() {
    return GestureDetector(
      onVerticalDragStart: (details) {},
      child: _ResultsSheet(
        isLoading: _isFetchingResults,
        doctorResults: _filteredDoctors,
        centerResults: _filteredCenters,
        results: _filteredResults,
        doctorItemBuilder: (d) => _doctorTile(d),
        centerItemBuilder: (c) => _centerTile(c),
        controller: _sheetController,
        maxChildSize: _sheetMax,
      ),
    );
  }


  Widget _buildNearbyChosenChip() {
    final t = AppLocalizations.of(context)!;

    final bool shouldShow =
        _isNearbySelected && _filters.nearbyKm != null && !_showingResults;
    if (!shouldShow) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.main.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.main.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location, size: 16, color: AppColors.main,),
          SizedBox(width: 6.w),
          Text(
            '${t.nearbyMe} • ${_filters.nearbyKm!.toStringAsFixed(0)} km',
            style: AppTextStyles.getText3(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            onTap: () {
              // remove the selected distance -> show slider again
              setState(() {
                _filters = _filters.copyWith(nearbyKm: null); // keep byNearby = true
                _results.clear();
                _filteredResults.clear();
              });
            },
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }


  // ========= عنوان التخصصات للعرض في الشارة الأولى =========
  String _specialtiesLabel(AppLocalizations t) {
    // لائحة كل الأسماء المتاحة محلياً
    final allSpecs = _buildLocalSpecialties(t).map((e) => e.name).toList();

    // التخصصات المختارة فعلياً
    final List<String> chosen = _filters.specs.isNotEmpty
        ? allSpecs.where((s) => _filters.specs.contains(s)).toList()
        : (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty)
        ? [_selectedSpecialty!]
        : [];

    if (chosen.isEmpty) return '';

    // لو ≤ 3، أعرضها كلها مفصولة بـ " * "
    if (chosen.length <= 3) {
      return chosen.join(' • ');
    }

    // لو > 3: أعرض أول تخصّصين + "N more"
    final shown = chosen.take(2).toList();
    final moreCount = chosen.length - 2;
    return '${shown.join(' • ')} + $moreCount ${t.more}';
  }

  // ========= جنس مختار لعرضه كشارة ثالثة إن وُجد =========
  String _genderLabel(AppLocalizations t) {
    if (_filters.male && !_filters.female) return t.male;
    if (_filters.female && !_filters.male) return t.female;
    return '';
  }

  // ========= شريط عرض (التخصصات • الموقع • الجنس) + زر الفلتر =========
  Widget _buildSelectedSummaryBar() {
    final t = AppLocalizations.of(context)!;

    final String cityDisplay = _isNearbySelected
        ? (_filters.nearbyKm != null
        ? '${t.nearbyMe} • ${_filters.nearbyKm!.toStringAsFixed(0)} km'
        : t.nearbyMe)
        : _cities.firstWhere(
          (c) => c.display == _locationCtrl.text,
      orElse: () => _CityOption.empty(),
    ).display;

    final String specsText = _specialtiesLabel(t);
    final String genderText = _genderLabel(t);

    return InkWell(
      onTap: _enterEditMode, // فتح التحرير + تصفير الفلاتر + إظهار الاقتراحات
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
            // زر الفلتر
            InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/filter.svg',
                  color: AppColors.main,
                  width: 16.w,
                  height: 16.w,
                ),
              ),
            ),
            SizedBox(width: 10.w),

            // العناصر الظاهرة: تخصصات متعددة + موقع + جنس (اختياري)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (specsText.isNotEmpty) _buildTag(specsText, AppColors.main),
                    if (specsText.isNotEmpty) const SizedBox(width: 8),
                    if (cityDisplay.isNotEmpty) _buildTag(cityDisplay, Colors.grey.shade600),
                    if (cityDisplay.isNotEmpty && genderText.isNotEmpty) const SizedBox(width: 8),
                    if (genderText.isNotEmpty) _buildTag(genderText, AppColors.mainDark),
                  ],
                ),
              ),
            ),

            // أيقونة تحرير
            GestureDetector(
              onTap: _enterEditMode,
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.grey, size: 18),
              ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: AppTextStyles.getText3(context).copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ========= تحديث كاش الأحياء =========
  void _updateNeighborhoodCache() {
    final Set<String> zones = {};
    for (var r in _results) {
      final n = (r['address']?['neighborhood'] ?? '').toString().trim();
      if (n.isNotEmpty) zones.add(n);
    }
    _cachedNeighborhoods = zones.toList()..sort();
  }

  // ========= اختيار الحي/المنطقة (خطوة بعد اختيار المدينة) =========
  Widget _buildZonePicker(AppLocalizations t) {
    final city = _zonePendingCity!;
    final zones = _cachedNeighborhoods; // only zones that have doctors
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: city name + back
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Go back to results (all zones) without re-fetching
                  setState(() => _zonePendingCity = null);
                },
                child: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Icon(Icons.arrow_back_rounded, size: 22.sp, color: AppColors.main),
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                city.display,
                style: AppTextStyles.getTitle3(context).copyWith(
                  color: AppColors.main,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.only(right: 16.w, left: 16.w, bottom: 8.h),
          child: Text(
            t.selectZone,
            style: AppTextStyles.getText3(context).copyWith(
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
        ),

        // Zone list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            itemCount: zones.length + 1, // +1 for "All zones"
            separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            itemBuilder: (context, index) {
              final bool isAll = index == 0;
              final String zoneName = isAll ? t.allZones : zones[index - 1];

              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                leading: Icon(
                  isAll ? Icons.location_city_rounded : Icons.place_outlined,
                  color: isAll ? AppColors.main : (isDark ? Colors.white38 : Colors.grey.shade400),
                  size: 22.sp,
                ),
                title: Text(
                  zoneName,
                  style: AppTextStyles.getText2(context).copyWith(
                    fontWeight: isAll ? FontWeight.w600 : FontWeight.w500,
                    color: isAll ? AppColors.main : null,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                onTap: () {
                  // Apply filter locally — results are already loaded
                  _filters = _filters.copyWith(
                    neighborhood: isAll ? null : zoneName,
                  );
                  setState(() => _zonePendingCity = null);
                  _applyFilters();
                },
              );
            },
          ),
        ),
      ],
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
      onTap: () {
        // عرض الاقتراحات فور التركيز
        final q = _locationCtrl.text.trim();
        setState(() {
          _cityMatches = q.isEmpty
              ? List<_CityOption>.from(_cities)
              : _cities
              .where((c) => c.display.toLowerCase().contains(q.toLowerCase()) || c.ar.contains(q))
              .toList();
        });
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
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
      ),
    );
  }

  // ========= السلايدر المدمج عند اختيار "بالقرب مني" =========
  Widget _buildNearbyInline() {
    final t = AppLocalizations.of(context)!;

    if (!_isNearbySelected || _myLatLng == null) return const SizedBox.shrink();

    // لا نعرضه إذا كانت النتائج تُعرض بالفعل
    if (_showingResults) return const SizedBox.shrink();

    // نعرضه فقط إن لم تُثبّت مسافة بعد
    if (_filters.nearbyKm != null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background2,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.maxDistance, style: AppTextStyles.getText3(context)),
          SizedBox(height: 5.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.main,
              thumbColor: AppColors.main,
              overlayColor: AppColors.main.withOpacity(0.1),
              inactiveTrackColor: AppColors.main.withOpacity(0.2),
              valueIndicatorColor: AppColors.main,
            ),
            child: Slider(
              value: _nearbyTempKm,
              min: 1,
              max: 25,
              divisions: 24,
              label: '${_nearbyTempKm.toStringAsFixed(0)} km',
              onChanged: (v) => setState(() => _nearbyTempKm = v),
            ),
          ),
          SizedBox(height: 5.h),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              padding: EdgeInsets.symmetric(vertical: 8.h),
            ),
            onPressed: () async {
              setState(() {
                _filters = _filters.copyWith(byNearby: true, nearbyKm: _nearbyTempKm);
              });
              await _fetchResults();
            },
            child: Text(t.done, style: AppTextStyles.getText3(context).copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _triggerLiveSearch() {
    // يجب توفر تخصص + موقع صالح
    if (_selectedSpecialty != null) {
      if (_isNearbySelected) {
        // لا نبحث قربياً قبل تثبيت المسافة
        if (_filters.nearbyKm != null && _myLatLng != null) {
          _fetchResults();
        } else {
          setState(() {
            _results.clear();
            _filteredResults.clear();
          });
        }
      } else if (_isCityConfirmed) {
        _fetchResults();
      } else {
        setState(() {
          _results.clear();
          _filteredResults.clear();
        });
      }
    } else {
      setState(() {
        _results.clear();
        _filteredResults.clear();
      });
    }
  }

  Widget _buildCitySuggestions() {
    final t = AppLocalizations.of(context)!;

    final q = _locationCtrl.text.trim();
    List<_CityOption> items;
    if (q.isEmpty) {
      items = _cities;
    } else {
      items = _cityMatches;
      if (items.isEmpty) {
        final exact =
        _cities.where((c) => c.display.toLowerCase() == q.toLowerCase() || c.ar == q).toList();
        items = exact.isNotEmpty ? exact : _cities;
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: SvgPicture.asset(
            'assets/icons/my-location.svg',
            color: AppColors.main,
            width: 24,
            height: 24,
          ),
          title: Text(t.nearbyMe, style: AppTextStyles.getText2(context)),
          onTap: () async {
            await _pickNearby(); // يجهّز الإحداثيات ويُظهر السلايدر المدمج
            setState(() {}); // لإعادة بناء الواجهة وإظهار السلايدر
          },
        ),
        const Divider(height: 1),
        ...items.map(
              (c) => ListTile(
            leading: SvgPicture.asset(
              'assets/icons/city-location.svg',
              color: AppColors.grayMain,
              width: 24,
              height: 24,
            ),
            title: Text(c.display, style: AppTextStyles.getText2(context)),
            onTap: () async {
              _locationCtrl.text = c.display;
              _isNearbySelected = false;
              _myLatLng = null;
              _filters = _filters.copyWith(byNearby: false, nearbyKm: null, cityDisplay: c.display, neighborhood: null);

              // Fetch all results for this city first
              await _fetchResults();

              // If city has zones and there are populated zones, show zone picker
              if (GeographyConstants.hasZones(c.ar) && _cachedNeighborhoods.isNotEmpty) {
                setState(() => _zonePendingCity = c);
              } else {
                setState(() => _zonePendingCity = null);
              }
            },
          ),
        ),
      ],
    );
  }

  // ========= خلفية خريطة (صورة ثابتة) =========
  Widget _buildStaticMapBackground() {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(1.0, -1.0),
            child: Image.asset(
              'assets/images/map.webp',
              fit: BoxFit.fitWidth,
              width: double.infinity,
            ),
          ),
        ),
      ],
    );
  }

  Widget _openMapButton() {
    final t = AppLocalizations.of(context)!;
    return Center(
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
          t.openInMaps,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullMapResultsPage(results: _filteredResults),
            ),
          );
        },
      ),
    );
  }

  bool get _isCityConfirmed {
    final txt = _locationCtrl.text.trim();
    if (txt.isEmpty && !_isNearbySelected) return false;
    if (_isNearbySelected) return _filters.nearbyKm != null; // يجب تثبيت المسافة
    return _cities.any((c) => c.display == txt || c.ar == txt);
  }

  // ========= الجسم =========
  @override
  Widget build(BuildContext context) {
    _initCities(context);
    final t = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_showingResults && _zonePendingCity == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBackFromResults();
      },
      child: BaseScaffold(
        title: Text(
          widget.mode == "message" ? t.sendMessageTitle : t.searchTitle,
          style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
        ),
        showBackArrow: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: AppColors.whiteText, size: 16),
            onPressed: () {
              if (_showingResults || _zonePendingCity != null) {
                _goBackFromResults();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
        child: Stack(
        children: [
          // خلفية
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _showingResults
                ? (_isFullyExpanded
                ? Container(key: const ValueKey('bg4'), color: AppColors.background4)
                : Container(key: const ValueKey('map'), child: _buildStaticMapBackground()))
                : const SizedBox.shrink(key: ValueKey('empty-bg')),
          ),

          // المحتوى الرئيسي
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                if (!_showingResults)
                  TextField(
                    focusNode: _searchFocus,
                    controller: _searchCtrl,
                    style: AppTextStyles.getText2(context),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background2,
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
                          // ✅ عند المسح وإبقاء التركيز: أعِد عرض قائمة كل التخصصات
                          if (_searchFocus.hasFocus) {
                            final t = AppLocalizations.of(context)!;
                            setState(() {
                              _mixed = _allSpecialtiesAsMixed(t);
                            });
                          } else {
                            setState(() => _mixed = []);
                          }

                            setState(() {
                              _selectedSpecialty = null;
                              _locationStageActive = false;
                              _zonePendingCity = null;
                              _locationCtrl.clear();
                              _results.clear();
                              _filteredResults.clear();
                              _filters = const FilterOptions();
                              _isNearbySelected = false;
                              _myLatLng = null;
                            });
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
                        borderSide: const BorderSide(color: AppColors.main, width: 2),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                  )
                else
                  _buildSelectedSummaryBar(),

                if (_showingResults) ...[
                  SizedBox(height: 50.h),
                  _openMapButton(),
                ],

                if (_locationStageActive && !_showingResults) ...[
                  SizedBox(height: 10.h),
                  _buildLocationField(t),
                  // either show the slider (no distance yet) or the chip (distance chosen)
                  if (_isNearbySelected && _filters.nearbyKm == null) _buildNearbyInline(),
                  if (_isNearbySelected && _filters.nearbyKm != null) _buildNearbyChosenChip(),
                ],


                SizedBox(height: 16.h),

                Expanded(
                  child: _showingResults
                      ? const SizedBox()
                      : _locationStageActive
                      ? _zonePendingCity != null
                          ? _buildZonePicker(t)
                          : (_selectedSpecialty != null && _isCityConfirmed)
                              ? (_isFetchingResults
                                  ? const Center(child: RotatingLogoLoader(size: 50))
                                  : (_filteredResults.isEmpty
                                      ? Center(
                                          child: Text(
                                            t.noResultsTitle,
                                            style: AppTextStyles.getText2(context)
                                                .copyWith(color: Colors.grey),
                                          ),
                                        )
                                      : const SizedBox()))
                              : _buildCitySuggestions()
                      : (_mixed.isNotEmpty ? _buildMixedSuggestions() : _favoritesSection()),
                ),
              ],
            ),
          ),

          if (_showingResults) _buildResultsSheet(),

          if (_loadingSuggestions)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      ),
    );
  }

  void _goBackFromResults() {
    final cityAr = _cities.firstWhere(
      (c) => c.display == _filters.cityDisplay,
      orElse: () => _CityOption.empty(),
    ).ar;

    if (_showingResults && GeographyConstants.hasZones(cityAr) && _cachedNeighborhoods.isNotEmpty) {
      // Go back to zone picker
      setState(() {
        _zonePendingCity = _cities.firstWhere(
          (c) => c.display == _filters.cityDisplay,
          orElse: () => _CityOption.empty(),
        );
        _filters = _filters.copyWith(neighborhood: null);
        _applyFilters();
      });
    } else if (_showingResults || _zonePendingCity != null) {
      // Go back to city list
      _enterEditMode();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ===== تحميل التخصصات من قاعدة البيانات =====
  Future<void> _loadSpecialtiesFromDb() async {
    try {
      final all = await SpecialtiesService.getAll();
      if (!mounted) return;
      final lang = Localizations.localeOf(context).languageCode;
      final list = all.map((s) {
        final name = lang == 'ar'
            ? (s['name_ar'] ?? s['name_en'] ?? '')
            : (s['name_en'] ?? s['name_ar'] ?? '');
        final iconKey = s['icon_key'] ?? 'General-specialty';
        const availableIcons = <String>{
          'Internal-specialty', 'Pediatrics-specialty', 'Gynecology-specialty',
          'Cardiology-specialty', 'ENT-specialty', 'Ophthalmology-specialty',
          'Orthopedics-specialty', 'Dermatology-specialty', 'Psychology-specialty',
          'Neurology-specialty', 'Nutrition-specialty', 'Endocrinology-specialty',
          'Urology-specialty', 'GeneralSurgery-specialty', 'Dentistry-specialty',
          'Cancer-specialty', 'Emergency-specialty', 'Gastro-specialty',
          'General-specialty', 'Physio-specialty', 'Plastic-specialty',
        };
        final assetPath = availableIcons.contains(iconKey)
            ? 'assets/icons/specialties/$iconKey.svg'
            : 'assets/icons/specialties/General-specialty.svg';
        return _SpecialtyOption(name.toString(), assetPath, (s['key'] ?? '').toString());
      }).toList();
      if (mounted) setState(() => _dbSpecialties = list);
    } catch (_) {
      // Fall back to hardcoded list
    }
  }

  List<_SpecialtyOption> _buildLocalSpecialties(AppLocalizations t) {
    // Use DB-loaded specialties when available
    if (_dbSpecialties != null) return _dbSpecialties!;
    return [
      _SpecialtyOption(t.specialtyGeneral,         'assets/icons/specialties/General-specialty.svg',        'general'),
      _SpecialtyOption(t.specialtyInternal,        'assets/icons/specialties/Internal-specialty.svg',       'internal'),
      _SpecialtyOption(t.specialtyPediatrics,      'assets/icons/specialties/Pediatrics-specialty.svg',     'pediatrics'),
      _SpecialtyOption(t.specialtyGynecology,      'assets/icons/specialties/Gynecology-specialty.svg',     'gynecology'),
      _SpecialtyOption(t.specialtyDentistry,       'assets/icons/specialties/Dentistry-specialty.svg',      'dentistry'),
      _SpecialtyOption(t.specialtyCardiology,      'assets/icons/specialties/Cardiology-specialty.svg',     'cardiology'),
      _SpecialtyOption(t.specialtyENT,             'assets/icons/specialties/ENT-specialty.svg',            'ent'),
      _SpecialtyOption(t.specialtyOphthalmology,   'assets/icons/specialties/Ophthalmology-specialty.svg',  'ophthalmology'),
      _SpecialtyOption(t.specialtyOrthopedics,     'assets/icons/specialties/Orthopedics-specialty.svg',    'orthopedics'),
      _SpecialtyOption(t.specialtyDermatology,     'assets/icons/specialties/Dermatology-specialty.svg',    'dermatology'),
      _SpecialtyOption(t.specialtyPsychology,      'assets/icons/specialties/Psychology-specialty.svg',     'psychology'),
      _SpecialtyOption(t.specialtyNeurology,       'assets/icons/specialties/Neurology-specialty.svg',      'neurology'),
      _SpecialtyOption(t.specialtyNutrition,       'assets/icons/specialties/Nutrition-specialty.svg',      'nutrition'),
      _SpecialtyOption(t.specialtyEndocrinology,   'assets/icons/specialties/Endocrinology-specialty.svg',  'endocrinology'),
      _SpecialtyOption(t.specialtyUrology,         'assets/icons/specialties/Urology-specialty.svg',        'urology'),
      _SpecialtyOption(t.specialtyGeneralSurgery,  'assets/icons/specialties/GeneralSurgery-specialty.svg', 'general_surgery'),
      _SpecialtyOption(t.specialtyGastro,          'assets/icons/specialties/Gastro-specialty.svg',         'gastroenterology'),
      _SpecialtyOption(t.specialtyPlastic,         'assets/icons/specialties/Plastic-specialty.svg',        'plastic_surgery'),
      _SpecialtyOption(t.specialtyCancer,          'assets/icons/specialties/Cancer-specialty.svg',         'oncology'),
      _SpecialtyOption(t.specialtyEmergency,       'assets/icons/specialties/Emergency-specialty.svg',      'emergency'),
      _SpecialtyOption(t.specialtyPhysio,          'assets/icons/specialties/Physio-specialty.svg',         'physiotherapy'),
    ];
  }


}

// ==================== نماذج مساعدة ====================

class _SpecialtyOption {
  final String name;
  final String asset; // مسار الـ SVG
  final String key;   // specialty key matching doctors.specialty_key
  _SpecialtyOption(this.name, this.asset, this.key);
}


enum _MixedType { doctor, center, specialty }

class _MixedSuggestion {
  final _MixedType type;
  final Map<String, dynamic>? doctor;
  final Map<String, dynamic>? center;
  final String? specialtyName;
  final String? asset; // مسار SVG
  final String? specialtyKey; // specialty key for DB queries

  _MixedSuggestion._(this.type, this.doctor, this.center, this.specialtyName, this.asset, this.specialtyKey);

  static _MixedSuggestion fromDoctor(Map<String, dynamic> d) =>
      _MixedSuggestion._(_MixedType.doctor, d, null, null, null, null);

  static _MixedSuggestion fromCenter(Map<String, dynamic> c) =>
      _MixedSuggestion._(_MixedType.center, null, c, null, null, null);

  static _MixedSuggestion specialty(String name, String asset, String key) =>
      _MixedSuggestion._(_MixedType.specialty, null, null, name, asset, key);
}


class _CityOption {
  final String ar; // القيمة في قاعدة البيانات (عربي)
  final String display; // نص العرض (محلي)
  final LatLng? center;
  _CityOption({required this.ar, required this.display, this.center});
  _CityOption.empty()
      : ar = '',
        display = '',
        center = null;
}

// ==================== خيارات الفلاتر (موسعة) ====================

class FilterOptions {
  final bool male; // ذكر
  final bool female; // أنثى
  final Set<String> specs; // تخصصات متعددة مختارة بالاسم المعروض
  final bool byNearby; // تفعيل "بالقرب مني"
  final double? nearbyKm; // نصف القطر بالكيلومتر
  final String? cityDisplay; // مدينة (عرض محلي)
  final String? neighborhood; // الحي المختار

  const FilterOptions({
    this.male = false,
    this.female = false,
    this.specs = const {},
    this.byNearby = false,
    this.nearbyKm,
    this.cityDisplay,
    this.neighborhood,
  });

  bool get hasAny =>
      male || female || specs.isNotEmpty || byNearby ||
      (cityDisplay != null && cityDisplay!.isNotEmpty) ||
      neighborhood != null;

  static const _unset = Object(); // sentinel

  FilterOptions copyWith({
    bool? male,
    bool? female,
    Set<String>? specs,
    bool? byNearby,
    Object? nearbyKm = _unset,   // use Object?, not double?
    Object? cityDisplay = _unset, // use Object?, not String?
    Object? neighborhood = _unset, // use Object?, not String?
  }) {
    return FilterOptions(
      male: male ?? this.male,
      female: female ?? this.female,
      specs: specs ?? this.specs,
      byNearby: byNearby ?? this.byNearby,
      nearbyKm: identical(nearbyKm, _unset) ? this.nearbyKm : nearbyKm as double?,
      cityDisplay: identical(cityDisplay, _unset) ? this.cityDisplay : cityDisplay as String?,
      neighborhood: identical(neighborhood, _unset) ? this.neighborhood : neighborhood as String?,
    );
  }

  // ملخص للفلاتر
  String summaryLabel(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final parts = <String>[];

    if (male && female) {
      parts.add(t.bothGenders);
    } else if (male) {
      parts.add(t.male);
    } else if (female) {
      parts.add(t.female);
    }

    if (byNearby && nearbyKm != null) parts.add('${t.nearbyMe} ≤ ${nearbyKm!.toStringAsFixed(0)} km');
    if (!byNearby && cityDisplay != null && cityDisplay!.isNotEmpty) parts.add(cityDisplay!);
    if (neighborhood != null) parts.add(neighborhood!);

    return parts.isEmpty ? t.noFilters : parts.join(' • ');
  }
}

// ==================== BottomSheet النتائج ====================

class _ResultsSheet extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> doctorResults;
  final List<Map<String, dynamic>> centerResults;
  final List<Map<String, dynamic>> results;
  final Widget Function(Map<String, dynamic>) doctorItemBuilder;
  final Widget Function(Map<String, dynamic>) centerItemBuilder;
  final DraggableScrollableController controller;
  final double maxChildSize;

  const _ResultsSheet({
    required this.isLoading,
    required this.doctorResults,
    required this.centerResults,
    required this.results,
    required this.doctorItemBuilder,
    required this.centerItemBuilder,
    required this.controller,
    this.maxChildSize = 0.88,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.7,
      maxChildSize: 0.88,
      controller: controller,
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
                // Drag Handle
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
                if (isLoading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.main.withOpacity(0.3),
                    backgroundColor: Colors.transparent,
                  ),
                // Combined Results List
                Expanded(
                  child: results.isEmpty && !isLoading
                      ? Center(
                          child: Text(
                            t.noResultsTitle,
                            style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = results[i];
                            if (item['search_type'] == 'center') {
                              return centerItemBuilder(item);
                            }
                            return doctorItemBuilder(item);
                          },
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

// ==================== صفحة الفلاتر ====================

class FiltersPage extends StatefulWidget {
  final FilterOptions initial;
  final List<String> allSpecs; // كل التخصصات المتاحة (بالاسم المعروض)
  final List<String> allCities; // كل المدن (display)
  final String? selectedSpecialty;
  final bool isNearbyAvailable;

  const FiltersPage({
    super.key,
    required this.initial,
    required this.allSpecs,
    required this.allCities,
    this.selectedSpecialty,
    this.isNearbyAvailable = true,
  });

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  late bool male;
  late bool female;
  late Set<String> specs;
  late bool byNearby;
  double nearbyKm = 5; // افتراضي
  String? cityDisplay;

  @override
  void initState() {
    super.initState();
    male = widget.initial.male;
    female = widget.initial.female;
    specs = Set<String>.from(widget.initial.specs);
    if (widget.selectedSpecialty != null && widget.selectedSpecialty!.isNotEmpty) {
      specs.add(widget.selectedSpecialty!);
    }
    byNearby = widget.initial.byNearby;
    nearbyKm = widget.initial.nearbyKm ?? 5;
    cityDisplay = widget.initial.cityDisplay;
  }

  void _reset() {
    setState(() {
      male = false;
      female = false;
      specs.clear();
      if (widget.isNearbyAvailable) {
        byNearby = false;
        nearbyKm = 5;
      }
      cityDisplay = null;
    });
  }

  void _done() {
    Navigator.pop(
      context,
      FilterOptions(
        male: male,
        female: female,
        specs: specs,
        byNearby: widget.isNearbyAvailable ? byNearby : false,
        nearbyKm: widget.isNearbyAvailable ? nearbyKm : null,
        cityDisplay: (!byNearby) ? (cityDisplay ?? '') : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // رتب التخصصات: المختار أساسياً أولاً
    final allSpecsOrdered = [
      if (widget.selectedSpecialty != null && widget.allSpecs.contains(widget.selectedSpecialty))
        widget.selectedSpecialty!,
      ...widget.allSpecs.where((s) => s != widget.selectedSpecialty),
    ];

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: SafeArea(
        child: Column(
          children: [
            // شريط علوي بسيط بدون عنوان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      t.reset,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _done,
                    child: Text(
                      t.done,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.main,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // الجنس
                  Text(
                    t.gender,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: male,
                    activeColor: AppColors.main,
                    title: Text(t.male, style: AppTextStyles.getText2(context)),
                    onChanged: (v) => setState(() => male = v ?? false),
                  ),
                  CheckboxListTile(
                    value: female,
                    activeColor: AppColors.main,
                    title: Text(t.female, style: AppTextStyles.getText2(context)),
                    onChanged: (v) => setState(() => female = v ?? false),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),

                  // التخصصات (متعددة)
                  const SizedBox(height: 12),
                  Text(
                    t.specialty,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allSpecsOrdered.map((s) {
                      final selected = specs.contains(s);
                      return FilterChip(
                        selected: selected,
                        label: Text(
                          s,
                          style: AppTextStyles.getText3(context).copyWith(
                            color: selected ? Colors.white : AppColors.mainDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: AppColors.main,
                        backgroundColor: Colors.white,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              specs.add(s);
                            } else {
                              specs.remove(s);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),

                  // الموقع: بالقرب مني أو مدينة
                  const SizedBox(height: 12),
                  Text(
                    t.location,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (widget.isNearbyAvailable) ...[
                    SwitchListTile(
                      value: byNearby,
                      activeColor: AppColors.main,
                      title: Text(t.nearbyMe, style: AppTextStyles.getText2(context)),
                      onChanged: (v) => setState(() {
                        byNearby = v;
                        if (v) cityDisplay = null; // إلغاء المدينة عند اختيار بالقرب مني
                      }),
                    ),
                    if (byNearby) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Slider(
                              value: nearbyKm,
                              min: 1,
                              max: 25,
                              divisions: 24,
                              label: '${nearbyKm.toStringAsFixed(0)} km',
                              activeColor: AppColors.main,
                              onChanged: (v) => setState(() => nearbyKm = v),
                            ),
                            Text(
                              '${t.maxDistance}: ${nearbyKm.toStringAsFixed(0)} km',
                              style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  if (!byNearby) ...[
                    // لائحة المدن (Radio)
                    ...widget.allCities.map((c) {
                      return RadioListTile<String>(
                        value: c,
                        groupValue: cityDisplay,
                        activeColor: AppColors.main,
                        title: Text(c, style: AppTextStyles.getText2(context)),
                        onChanged: (v) => setState(() => cityDisplay = v),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
