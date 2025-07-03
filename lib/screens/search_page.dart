import 'package:docsera/models/document.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart'; //
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/services/supabase/supabase_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home/messages/message_select_patient.dart';

class SearchPage extends StatefulWidget {
  final String mode; // "search" أو "message"
  final UserDocument? attachedDocument;

  const SearchPage({
    Key? key,
    this.mode = "search",
    this.attachedDocument,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    /// ✅ **إعطاء التركيز لحقل البحث فور تحميل الصفحة**
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });

    _focusNode.addListener(() {
      setState(() {}); // Redraw UI when focus changes
    });

    _loadUserId(); // Load user ID and fetch favorites
    _fetchFavoriteDoctors(); // ✅ Load favorite doctors on page load
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// **Retrieve the logged-in user ID**
  void _loadUserId() async {
    User? user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _userId = user.id);
      _fetchFavoriteDoctors(); // Load favorite doctors once we have the user ID
    }
  }

  /// **Fetch favorite doctors from Firestore**
  Future<void> _fetchFavoriteDoctors() async {
    try {
      // 🔹 جلب userId من SharedPreferences أولًا
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      // 🔹 إذا كان null، جرب من Supabase
      userId ??= Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        print("❌ No user logged in! Cannot fetch favorites.");
        return;
      }

      print("🟢 Fetching favorites for User ID: $userId");

      final response = await Supabase.instance.client
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .single();

      final favorites = response['favorites'] as List<dynamic>?;

      if (favorites == null || favorites.isEmpty) {
        print("❌ No favorite doctors found!");
        setState(() {
          _favoriteDoctors = [];
        });
        return;
      }

      print("⭐ Favorite Doctor IDs: $favorites");

      final doctorsResponse = await Supabase.instance.client
          .from('doctors')
          .select()
          .inFilter('id', favorites);

      setState(() {
        _favoriteDoctors = List<Map<String, dynamic>>.from(doctorsResponse);
      });

      print("✅ Total Favorite Doctors Loaded: ${_favoriteDoctors.length}");

    } catch (e) {
      print("❌ Error fetching favorite doctors: $e");
    }
  }

  /// **Perform search based on user input**
  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    List<Map<String, dynamic>> results =
    await _searchService.searchDoctors(query.toLowerCase());

    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        widget.mode == "message"
              ? AppLocalizations.of(context)!.sendMessageTitle
              : AppLocalizations.of(context)!.searchTitle,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),

      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // 🔍 **Search Bar**
            TextField(
              focusNode: _focusNode,
              controller: _searchController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.searchHint,
                labelStyle: AppTextStyles.getText2(context),
                floatingLabelStyle: AppTextStyles.getText3(context).copyWith( // 🔹 Smaller floating label
                  fontWeight: FontWeight.bold,
                  color: AppColors.main,  // 🔹 Ensure it stays in theme color
                ),
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
                  vertical: 10.h,  // 🔹 Reduces top & bottom padding
                  horizontal: 12.w, // 🔹 Adjusts left & right padding
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

            // 📋 **Favorites Before Typing**
            Expanded(
              child: _searchController.text.isEmpty
                  ? (_favoriteDoctors.isNotEmpty ? _buildFavoritesList() : _buildNoFavorites())
                  : (_searchResults.isEmpty ? _buildNoResults() : _buildResultsList()),
            ),
          ],
        ),
      ),
    );
  }

  /// **No Favorites UI (Title at Start)**
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
  /// **Builds the Favorite Doctors List**
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
            final doctor = _favoriteDoctors[index];
            return _buildDoctorTile(doctor);
          },
        ),
      ],
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

  /// **Builds the Search Results List**
  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doctor = _searchResults[index];
        return _buildDoctorTile(doctor);
      },
    );
  }


  /// **Doctor Search Result Tile**
  Widget _buildDoctorTile(Map<String, dynamic> doctor) {
    String gender = doctor['gender']?.toLowerCase() ?? 'male';
    String title = doctor['title']?.toLowerCase() ?? '';

    String avatarPath = (title == "dr.")
        ? (gender == "female" ? 'assets/images/female-doc.png' : 'assets/images/male-doc.png')
        : (gender == "female" ? 'assets/images/female-phys.png' : 'assets/images/male-phys.png');


    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mainDark.withOpacity(0.2),
        radius: 22.sp,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50.r),
          child: Image.asset(avatarPath, width: 100.w, height: 100.h, fit: BoxFit.cover),
        ),
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
                  AppLocalizations.of(context)!.messagingDisabled,
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
            "${doctor['specialty']} • ${doctor['clinic']}",
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.location_on, size: 12.sp, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                doctor['address']['city'] ?? "Unknown Location",
                style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),

      trailing: Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),

      onTap: () {
        if (widget.mode == "message") {
          Navigator.push(context, fadePageRoute(
            SelectPatientForMessagePage(
              doctorId: doctor['id'],
              doctorName: "${doctor['title']} ${doctor['first_name']} ${doctor['last_name']}",
              doctorGender: doctor['gender'],
              doctorTitle: doctor['title'],
              specialty: doctor['specialty'],
              image: avatarPath,
              attachedDocument: widget.attachedDocument,
            ),
          ));
        }else {
          Navigator.push(context, fadePageRoute(
            DoctorProfilePage(doctor: doctor, doctorId: doctor['id']),
          ));
        }
      },
    );

  }

}
