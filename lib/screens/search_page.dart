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
import 'package:docsera/services/supabase/supabase_search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/services/supabase/repositories/favorites_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    /// ✅ **إعطاء التركيز لحقل البحث فور تحميل الصفحة**
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });

    _focusNode.addListener(() {
      setState(() {}); // Redraw UI when focus changes
    });

    _fetchFavoriteDoctors(); // ✅ Load favorite doctors on page load
  }

  @override
  void dispose() {
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

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
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
              color: AppColors.main.withOpacity(0.3),
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
                        _performSearch("");
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
                  onChanged: _performSearch,
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
    final specialties = [
      {'name': t.specialtyGeneral, 'iconAsset': 'assets/icons/specialties/General-specialty.svg'},
      {'name': t.specialtyInternal, 'iconAsset': 'assets/icons/specialties/Internal-specialty.svg'},
      {'name': t.specialtyPediatrics, 'iconAsset': 'assets/icons/specialties/Pediatrics-specialty.svg'},
      {'name': t.specialtyGynecology, 'iconAsset': 'assets/icons/specialties/Gynecology-specialty.svg'},
      {'name': t.specialtyDentistry, 'iconAsset': 'assets/icons/specialties/Dentistry-specialty.svg'},
      {'name': t.specialtyCardiology, 'iconAsset': 'assets/icons/specialties/Cardiology-specialty.svg'},
      {'name': t.specialtyENT, 'iconAsset': 'assets/icons/specialties/ENT-specialty.svg'},
      {'name': t.specialtyOphthalmology, 'iconAsset': 'assets/icons/specialties/Ophthalmology-specialty.svg'},
      {'name': t.specialtyOrthopedics, 'iconAsset': 'assets/icons/specialties/Orthopedics-specialty.svg'},
      {'name': t.specialtyDermatology, 'iconAsset': 'assets/icons/specialties/Dermatology-specialty.svg'},
    ];

    return ListView.builder(
      itemCount: specialties.length,
      itemBuilder: (context, index) {
        final spec = specialties[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.08),
            child: spec['iconAsset'] != null
                ? SvgPicture.asset(
                    spec['iconAsset'] as String,
                    width: 25.w,
                    height: 25.w,
                    color: AppColors.main,
                  )
                : null,
          ),
          title: Text(spec['name'] as String, style: AppTextStyles.getText2(context)),
          subtitle: Text(
            t.searchBySpecialty,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
          ),
          trailing: const Icon(Icons.arrow_outward, size: 18, color: Colors.grey),
          onTap: () {
            _searchController.text = spec['name'] as String;
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

  Future<bool> _isUserPatientOfDoctor(String doctorId) async {
    if (_userId == null) return false;

    final result = await Supabase.instance.client
        .from('appointments')
        .select('id')
        .eq('doctor_id', doctorId)
        .eq('user_id', _userId!)
        .limit(1);

    return (result.isNotEmpty);
  }


  /// **Doctor Search Result Tile**
  Widget _buildDoctorTile(Map<String, dynamic> doctor) {
    final imageResult = resolveDoctorImagePathAndWidget(doctor: doctor);
    final avatarPath = imageResult.avatarPath;
    final imageProvider = imageResult.imageProvider;
    final local = AppLocalizations.of(context)!;

    final bool messagesEnabled = doctor['messages_enabled'] == true;
    final String access = doctor['messages_access'] ?? 'public';

    return FutureBuilder<bool>(
      future: _isUserPatientOfDoctor(doctor['id']),
      builder: (context, snapshot) {
        final bool isPatient = snapshot.data ?? false;

        // 🧩 تحقق من التوفر
        bool isUnavailable = false;
        String unavailableReason = '';

        if (widget.mode == "message" && doctor['id'] == _userId) {
          isUnavailable = true;
          unavailableReason = local.ownProfileBadge; 
        } else if (!messagesEnabled) {
          isUnavailable = true;
          unavailableReason = local.messagesDisabled; // 🔹 “غير متاح للرسائل”
        } else if (access == 'patients' && !isPatient) {
          isUnavailable = true;
          unavailableReason = local.patientsOnlyMessaging; // 🔹 “متاح فقط لمرضاه”
        }

        final tileOpacity = isUnavailable ? 0.6 : 1.0;

        return Opacity(
          opacity: tileOpacity,
          child: AbsorbPointer( // يمنع الضغط لما يكون غير متاح
            absorbing: isUnavailable,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.mainDark.withOpacity(0.15),
                radius: 22,
                backgroundImage: imageProvider,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${doctor['title']} ${doctor['first_name']} ${doctor['last_name']}".trim(),
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
                      doctorName:
                      "${doctor['title']} ${doctor['first_name']} ${doctor['last_name']}",
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
      },
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
        backgroundColor: AppColors.mainDark.withOpacity(0.15),
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
