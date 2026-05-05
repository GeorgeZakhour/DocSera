import 'dart:async';

import 'package:docsera/models/document.dart';
import 'package:docsera/screens/centers/center_profile_page.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart'; //
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/services/supabase/specialties_service.dart';
import 'package:docsera/services/supabase/supabase_search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/services/supabase/repositories/favorites_repository.dart';
import 'package:docsera/services/analytics/analytics_service.dart';
import 'package:docsera/services/analytics/analytics_event_catalog.dart';

import 'home/messages/message_select_patient.dart';

class SearchPage extends StatefulWidget {
  final String mode; // "search" أو "message"
  final UserDocument? attachedDocument;

  const SearchPage({
    super.key,
    this.mode = "search",
    this.attachedDocument,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseSearchService _searchService = SupabaseSearchService();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _favoriteDoctors = [];
  final FocusNode _focusNode = FocusNode();
  String? _userId; // Stores the logged-in user ID
  bool _isSearching = false;
  List<Map<String, dynamic>> _specialties = [];

  // Debouncer for the search input. Without this, _performSearch fires a
  // Supabase query on every keystroke — typing "cardiology" issues 9
  // queries in rapid succession. With a 300ms debounce, only the final
  // query after the user stops typing fires.
  Timer? _searchDebounce;
  static const Duration _searchDebounceWindow = Duration(milliseconds: 300);

  // Cache of doctorId → bool ("is current user a patient of this doctor?").
  // Used only in mode == 'message' to decide if the doctor's "patients-only"
  // messaging gate applies. Without caching, _buildDoctorTile would issue a
  // Supabase query per result row on every rebuild (N+1 query antipattern).
  final Map<String, bool> _isPatientCache = {};

  /// Set of icon_key values that have actual SVG files bundled in assets.
  static const _availableSvgIcons = <String>{
    'Internal-specialty', 'Pediatrics-specialty', 'Gynecology-specialty',
    'Cardiology-specialty', 'ENT-specialty', 'Ophthalmology-specialty',
    'Orthopedics-specialty', 'Dermatology-specialty', 'Psychology-specialty',
    'Neurology-specialty', 'Nutrition-specialty', 'Endocrinology-specialty',
    'Urology-specialty', 'GeneralSurgery-specialty', 'Dentistry-specialty',
    'Cancer-specialty', 'Emergency-specialty', 'Gastro-specialty',
    'General-specialty', 'Physio-specialty', 'Plastic-specialty',
  };
  static const _fallbackSvgIcon = 'assets/icons/specialties/General-specialty.svg';

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    Analytics.instance.track(Events.searchStarted, {'source': widget.mode});
    /// ✅ **إعطاء التركيز لحقل البحث فور تحميل الصفحة**
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });

    _focusNode.addListener(() {
      setState(() {}); // Redraw UI when focus changes
    });

    _fetchFavoriteDoctors(); // ✅ Load favorite doctors on page load
    _fetchSpecialties();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// **Fetch favorite practitioners (Doctors & Centers)**
  Future<void> _fetchFavoriteDoctors() async {
    try {
      final repo = FavoritesRepository();
      final favs = await repo.getFavoriteDoctors();
      
      setState(() {
        _favoriteDoctors = favs;
      });

    } catch (e) {
      debugPrint("❌ Failed to fetch favorite practitioners: $e");
      setState(() => _favoriteDoctors = []);
    }
  }

  Future<void> _fetchSpecialties() async {
    try {
      final data = await SpecialtiesService.getAll();
      if (mounted) setState(() => _specialties = data);
    } catch (e) {
      debugPrint("❌ Failed to fetch specialties: $e");
    }
  }

  /// Debounced entry point — called by the TextField onChanged. Cancels any
  /// in-flight timer and re-arms it so the actual query only fires after
  /// the user pauses typing for [_searchDebounceWindow].
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      // Clearing the field is immediate (no debounce on empty string).
      _performSearch(query);
      return;
    }
    _searchDebounce = Timer(_searchDebounceWindow, () => _performSearch(query));
  }

  /// **Perform search based on user input**
  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final q = query.toLowerCase();

    final rawResults = await _searchService.searchUnified(q);

    // 🛡️ Filter centers if in messaging mode
    final results = widget.mode == "message"
        ? rawResults.where((r) => r['search_type'] != 'center').toList()
        : rawResults;

    // In message mode the per-doctor "is current user a patient?" query is
    // needed to gate the patients-only messaging UX. Pre-fetch ALL of them
    // in a single batch up-front so the tile builder can read from
    // _isPatientCache synchronously instead of issuing N FutureBuilders.
    if (widget.mode == "message" && _userId != null && results.isNotEmpty) {
      final doctorIds = results
          .where((r) => r['search_type'] != 'center' && r['id'] != null)
          .map((r) => r['id'] as String)
          .where((id) => !_isPatientCache.containsKey(id))
          .toList();
      if (doctorIds.isNotEmpty) {
        await _prefetchPatientStatus(doctorIds);
      }
    }

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// Single batched query that populates _isPatientCache for every doctor
  /// id in the search results. Replaces the per-row FutureBuilder pattern
  /// that issued N queries on every list rebuild.
  Future<void> _prefetchPatientStatus(List<String> doctorIds) async {
    try {
      final rows = await Supabase.instance.client
          .from('appointments')
          .select('doctor_id')
          .eq('user_id', _userId!)
          .inFilter('doctor_id', doctorIds);
      final patientOf = <String>{};
      for (final r in rows) {
        final id = r['doctor_id']?.toString();
        if (id != null) patientOf.add(id);
      }
      for (final id in doctorIds) {
        _isPatientCache[id] = patientOf.contains(id);
      }
    } catch (e) {
      // Treat as "not a patient" on error — the patients-only gate is a
      // permissive default elsewhere in the app, so this matches behavior.
      for (final id in doctorIds) {
        _isPatientCache[id] = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        widget.mode == "message"
              ? AppLocalizations.of(context)!.sendMessageTitle
              : (widget.mode == "appointment" 
                  ? AppLocalizations.of(context)!.bookAppointment 
                  : AppLocalizations.of(context)!.searchTitle),
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),

      ),
      child: Column(
        children: [
          // 🔄 **Loading Bar**
          if (_isSearching)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: AppColors.main.withValues(alpha: 0.3),
            ),

          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // 🔍 **Search Bar**
                TextField(
                  focusNode: _focusNode,
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.mode == "message"
                        ? AppLocalizations.of(context)!.searchHint
                        : AppLocalizations.of(context)!.searchHint,
                    hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: AppColors.main),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged("");
                      },
                    )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 12.w,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.r),
                      borderSide: const BorderSide(color: AppColors.main, width: 2),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                
                SizedBox(height: 20.h),
    
                // 📋 **Content**
                SizedBox(
                  height: 1.sh - 220.h, // Adjusted to fill space but avoid overflow
                  child: _searchController.text.isEmpty
                      ? (_focusNode.hasFocus && widget.mode == "search"
                          ? _buildSpecialtiesList()
                          : (_favoriteDoctors.isNotEmpty ? _buildFavoritesList() : _buildNoFavorites()))
                      : (_searchResults.isEmpty && !_isSearching ? _buildNoResults() : _buildResultsList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        if (item['search_type'] == 'center') {
          return _buildCenterTile(item);
        }
        return _buildDoctorTile(item);
      },
    );
  }

  Widget _buildNoFavorites() {
    return Align(
      alignment: Alignment.topLeft, // ✅ Aligns "Favorites" to the start
      child:  Padding(
        padding: EdgeInsets.only(left: 16.w, top: 8.h),
        child: Text(
          AppLocalizations.of(context)!.noFavorites,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
        ),
      ),
    );
  }

  /// **Builds the Favorite Practitioners List**
  Widget _buildFavoritesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, size: 14.sp, color: Colors.grey.shade600),
            SizedBox(width: 5.w),
            Text(
              AppLocalizations.of(context)!.favoritesTitle,
            style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade600),

            ),
          ],
        ),
        SizedBox(height: 5.h),

        // ✅ Use ListView.builder with `shrinkWrap: true` to display all elements
        ListView.builder(
          shrinkWrap: true, // ✅ Ensure it does not take infinite space
          physics: const NeverScrollableScrollPhysics(), // ✅ Prevent internal scrolling issues
          itemCount: _favoriteDoctors.length,
          itemBuilder: (context, index) {
            final item = _favoriteDoctors[index];
            if (item['search_type'] == 'center') {
              return _buildCenterTile(item);
            }
            return _buildDoctorTile(item);
          },
        ),
      ],
    );
  }

  Widget _buildSpecialtiesList() {
    final t = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    if (_specialties.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.main));
    }

    return ListView.builder(
      itemCount: _specialties.length,
      itemBuilder: (context, index) {
        final spec = _specialties[index];
        final name = lang == 'ar' ? (spec['name_ar'] ?? '') : (spec['name_en'] ?? '');
        final iconKey = spec['icon_key'] ?? 'General-specialty';
        final iconAsset = _availableSvgIcons.contains(iconKey)
            ? 'assets/icons/specialties/$iconKey.svg'
            : _fallbackSvgIcon;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.08),
            child: SvgPicture.asset(
              iconAsset,
              width: 25.w,
              height: 25.w,
              colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
            ),
          ),
          title: Text(name, style: AppTextStyles.getText2(context)),
          subtitle: Text(
            t.searchBySpecialty,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
          ),
          trailing: const Icon(Icons.arrow_outward, size: 18, color: Colors.grey),
          onTap: () {
            _searchController.text = name;
            _performSearch(_searchController.text);
          },
        );
      },
    );
  }

  /// **No Search Results UI**
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60.sp, color: AppColors.main),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.noResultsTitle,
            style: AppTextStyles.getTitle2(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.noResultsSubtitle,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  /// **Doctor Search Result Tile**
  Widget _buildDoctorTile(Map<String, dynamic> doctor) {
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final imageProvider = imageResult.imageProvider;
    final local = AppLocalizations.of(context)!;

    final bool messagesEnabled = doctor['messages_enabled'] == true;
    final String access = doctor['messages_access'] ?? 'public';

    // Pull patient status from the prefetched cache (populated in batch by
    // _prefetchPatientStatus during the search). Falls back to false in
    // search mode where we never need this value anyway.
    final bool isPatient = _isPatientCache[doctor['id']] ?? false;

    // 🧩 تحقق من التوفر (فقط في وضع الرسائل)
    bool isUnavailable = false;
    String unavailableReason = '';

    if (widget.mode == "message") {
      if (doctor['id'] == _userId) {
        isUnavailable = true;
        unavailableReason = local.ownProfileBadge;
      } else if (!messagesEnabled) {
        isUnavailable = true;
        unavailableReason = local.messagesDisabled; // 🔹 "غير متاح للرسائل"
      } else if (access == 'patients' && !isPatient) {
        isUnavailable = true;
        unavailableReason = local.patientsOnlyMessaging; // 🔹 "متاح فقط لمرضاه"
      }
    }

    final tileOpacity = isUnavailable ? 0.6 : 1.0;

    return Opacity(
          opacity: tileOpacity,
          child: AbsorbPointer( // يمنع الضغط لما يكون غير متاح
            absorbing: isUnavailable,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.mainDark.withValues(alpha: 0.15),
                radius: 22,
                backgroundImage: imageProvider,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      doctor['title'] ?? '',
                      doctor['first_name'] ?? '',
                      doctor['middle_name'] ?? '',
                      doctor['last_name'] ?? '',
                    ]
                        .map((s) => s.toString().trim())
                        .where((s) => s.isNotEmpty)
                        .join(' '),
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainDark,
                    ),
                  ),
                  if (isUnavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unavailableReason,
                          style: AppTextStyles.getText3(context).copyWith(
                            color: AppColors.mainDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${doctor['specialty']} • ${doctor['clinic'] ?? ''}",
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        doctor['address']?['city'] ?? '',
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              onTap: () {
                if (widget.mode == "message") {
                  Navigator.push(context, fadePageRoute(
                    SelectPatientForMessagePage(
                      doctorId: doctor['id'],
                      doctorName: [
                        doctor['title'] ?? '',
                        doctor['first_name'] ?? '',
                        doctor['middle_name'] ?? '',
                        doctor['last_name'] ?? '',
                      ]
                          .map((s) => s.toString().trim())
                          .where((s) => s.isNotEmpty)
                          .join(' '),
                      doctorGender: doctor['gender'],
                      doctorTitle: doctor['title'],
                      specialty: doctor['specialty'],
                      doctorImage: imageProvider,
                      doctorImageUrl: avatarPath,
                      attachedDocument: widget.attachedDocument,
                    ),
                  ));
                } else {
                  Navigator.push(context, fadePageRoute(
                    DoctorProfilePage(doctor: doctor, doctorId: doctor['id']),
                  ));
                }
              },
            ),
          ),
        );
  }

  /// **Center Search Result Tile**
  Widget _buildCenterTile(Map<String, dynamic> center) {
    final imageResult = resolveCenterImagePathAndWidget(center: center);
    final imageProvider = imageResult.imageProvider;

    final specialties = (center['specialties'] as List?)?.join(' • ') ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.mainDark.withValues(alpha: 0.15),
        radius: 22,
        backgroundImage: imageProvider,
      ),
      title: Text(
        (center['name'] ?? '').toString(),
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
              style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                center['address']?['city'] ?? '',
                style: AppTextStyles.getText3(context).copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: () {
        if (widget.mode == "search") {
          Navigator.push(context, fadePageRoute(
            CenterProfilePage(centerId: center['id']),
          ));
        }
      },
    );
  }

}
