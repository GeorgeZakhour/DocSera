import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/services/supabase/supabase_center_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/rotating_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CenterProfilePage extends StatefulWidget {
  final String centerId;
  final Map<String, dynamic>? center;

  const CenterProfilePage({
    super.key,
    required this.centerId,
    this.center,
  });

  @override
  State<CenterProfilePage> createState() => _CenterProfilePageState();
}

class _CenterProfilePageState extends State<CenterProfilePage> {
  final ScrollController _scrollController = ScrollController();
  final SupabaseCenterService _service = SupabaseCenterService();
  
  bool _showAppBar = false;
  Map<String, dynamic>? _centerData;
  List<Map<String, dynamic>> _team = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    double triggerOffset = 200.h;

    if (offset >= triggerOffset && !_showAppBar) {
      setState(() => _showAppBar = true);
    } else if (offset < triggerOffset && _showAppBar) {
      setState(() => _showAppBar = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Initial data from widget if available
    if (widget.center != null) {
      _centerData = widget.center;
    }

    final data = await _service.getCenterData(widget.centerId);
    final team = await _service.fetchCenterTeam(widget.centerId);

    if (mounted) {
      setState(() {
        _centerData = data ?? _centerData;
        _team = team;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _centerData == null) {
      return const Scaffold(
        body: Center(child: RotatingLogoLoader()),
      );
    }

    final l = AppLocalizations.of(context)!;
    final center = _centerData!;
    final imageResult = resolveCenterImagePathAndWidget(center: center);

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(center, imageResult),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 60.h), // Space for logo overlap
                      _buildHeader(center, l),
                      SizedBox(height: 20.h),
                      if (_team.isNotEmpty) ...[
                        _buildTeamSection(_team, l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['description'] != null && center['description'].toString().trim().isNotEmpty) ...[
                        _buildDescriptionSection(center['description']),
                        SizedBox(height: 20.h),
                      ],
                      if (center['gallery'] != null && (center['gallery'] as List).isNotEmpty) ...[
                        _buildGallerySection(center['gallery'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['specialties'] != null && (center['specialties'] as List).isNotEmpty) ...[
                        _buildSpecialtiesSection(center['specialties'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['offered_services'] != null && (center['offered_services'] as Map).isNotEmpty) ...[
                        _buildServicesSection(center['offered_services'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['faqs'] != null && (center['faqs'] as List).isNotEmpty) ...[
                        _buildFaqSection(center['faqs'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['languages'] != null && (center['languages'] as List).isNotEmpty) ...[
                        _buildLanguagesSection(center['languages'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['insurance_accepted'] != null && (center['insurance_accepted'] as List).isNotEmpty) ...[
                        _buildInsuranceSection(center['insurance_accepted'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['facilities'] != null && (center['facilities'] as List).isNotEmpty) ...[
                        _buildFacilitiesSection(center['facilities'], l),
                        SizedBox(height: 20.h),
                      ],
                      if (center['social_media'] != null && (center['social_media'] as Map).isNotEmpty) ...[
                        _buildSocialMediaSection(center['social_media'], l),
                        SizedBox(height: 20.h),
                      ],
                      _buildContactSection(center, l),
                      SizedBox(height: 20.h),
                      _buildAddressSectionDetailed(center, l),
                      SizedBox(height: 20.h),
                      if (center['opening_hours'] != null) ...[
                        _buildOpeningHoursSectionDetailed(center['opening_hours'], l),
                        SizedBox(height: 20.h),
                      ],
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildFloatingTopBar(center, l),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> center, DoctorImageResult imageResult) {
    return SliverAppBar(
      expandedHeight: 250.h,
      automaticallyImplyLeading: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image (Center Logo or generic pattern)
            imageResult.widget,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingTopBar(Map<String, dynamic> center, AppLocalizations l) {
    return AnimatedOpacity(
      opacity: _showAppBar ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: AppColors.mainDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                center['name'] ?? '',
                style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white, fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () => _shareCenter(center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> center, AppLocalizations l) {
    final imageResult = resolveCenterImagePathAndWidget(center: center, width: 80, height: 80);
    final specialties = (center['specialties'] as List?)?.join(' • ') ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              center['name'] ?? '',
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 16.sp),
            ),
            if (specialties.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  specialties,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.main),
                ),
              ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey, size: 14.sp),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    "${center['address']?['city'] ?? ''}, ${center['address']?['street'] ?? ''}",
                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: -100.h,
          left: Localizations.localeOf(context).languageCode == 'ar' ? null : 0,
          right: Localizations.localeOf(context).languageCode == 'ar' ? 0 : null,
          child: Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: CircleAvatar(
              radius: 40.r,
              backgroundColor: Colors.white,
              backgroundImage: imageResult.imageProvider,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({required String title, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.main, size: 18.sp),
            SizedBox(width: 8.w),
            Text(title, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
          ],
        ),
        SizedBox(height: 12.h),
        Card(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtiesSection(List<dynamic> items, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.specialtiesDepartments,
      icon: Icons.local_hospital_outlined,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: items.map((e) => Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.main.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            e.toString(),
            style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark, fontWeight: FontWeight.bold),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildServicesSection(Map<String, dynamic> services, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.offeredServices,
      icon: Icons.fact_check_outlined,
      child: Column(
        children: services.entries.map((e) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.main, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  e.key,
                  style: AppTextStyles.getText2(context),
                ),
              ),
              if (e.value != null && e.value.toString().isNotEmpty)
                Text(
                  e.value.toString(),
                  style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildLanguagesSection(List<dynamic> languages, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.languagesSpoken,
      icon: Icons.translate,
      child: Wrap(
        spacing: 12.w,
        runSpacing: 8.h,
        children: languages.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, color: Colors.grey, size: 14.sp),
            SizedBox(width: 4.w),
            Text(e.toString(), style: AppTextStyles.getText2(context)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildInsuranceSection(List<dynamic> items, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.acceptedInsurance,
      icon: Icons.verified_user_outlined,
      child: Column(
        children: items.map((e) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            children: [
              Icon(Icons.security, color: Colors.green, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(child: Text(e.toString(), style: AppTextStyles.getText2(context))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFacilitiesSection(List<dynamic> items, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.facilitiesAmenities,
      icon: Icons.local_parking_outlined,
      child: Wrap(
        spacing: 16.w,
        runSpacing: 12.h,
        children: items.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getFacilityIcon(e.toString()), color: AppColors.main, size: 14.sp),
            SizedBox(width: 6.w),
            Text(e.toString(), style: AppTextStyles.getText3(context)),
          ],
        )).toList(),
      ),
    );
  }

  IconData _getFacilityIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('parking') || n.contains('موقف')) return Icons.local_parking;
    if (n.contains('wifi') || n.contains('إنترنت')) return Icons.wifi;
    if (n.contains('elevator') || n.contains('مصعد')) return Icons.elevator;
    if (n.contains('pharmacy') || n.contains('صيدلية')) return Icons.local_pharmacy;
    if (n.contains('kids') || n.contains('أطفال')) return Icons.child_care;
    if (n.contains('wheelchair') || n.contains('كراسي')) return Icons.accessible;
    return Icons.check_circle_outline;
  }

  Widget _buildSocialMediaSection(Map<String, dynamic> social, AppLocalizations l) {
    final entries = social.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return _buildSummaryCard(
      title: l.socialMedia,
      icon: Icons.share_outlined,
      child: Column(
        children: entries.map((e) => ListTile(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Icon(_getSocialIcon(e.key), color: AppColors.main, size: 20.sp),
          title: Text(e.key, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(e.value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
          trailing: Icon(Icons.open_in_new, size: 14.sp, color: Colors.grey),
          onTap: () => launchUrl(Uri.parse(e.value.toString()), mode: LaunchMode.externalApplication),
        )).toList(),
      ),
    );
  }

  IconData _getSocialIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains('facebook')) return Icons.facebook;
    if (k.contains('instagram')) return Icons.camera_alt_outlined;
    if (k.contains('twitter') || k.contains('x')) return Icons.alternate_email;
    if (k.contains('linkedin')) return Icons.work_outline;
    if (k.contains('tiktok')) return Icons.music_note;
    if (k.contains('youtube')) return Icons.play_circle_outline;
    if (k.contains('whatsapp')) return Icons.message;
    return Icons.link;
  }

  Widget _buildContactSection(Map<String, dynamic> center, AppLocalizations l) {
    return _buildSummaryCard(
      title: l.contactInformation,
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          if (center['email'] != null)
            _buildContactTile(Icons.email, center['email'].toString(), () => launchUrl(Uri.parse("mailto:${center['email']}"))),
          if (center['mobile_number'] != null)
            _buildContactTile(Icons.phone_android, center['mobile_number'].toString(), () => launchUrl(Uri.parse("tel:${center['mobile_number']}"))),
          if (center['website'] != null)
            _buildContactTile(Icons.language, center['website'].toString(), () => launchUrl(Uri.parse(center['website'].toString()), mode: LaunchMode.externalApplication)),
        ],
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: AppColors.main, size: 18.sp),
      title: Text(value, style: AppTextStyles.getText2(context)),
      onTap: onTap,
    );
  }

  Widget _buildAddressSectionDetailed(Map<String, dynamic> center, AppLocalizations l) {
    final address = center['address'] as Map?;
    if (address == null) return const SizedBox.shrink();

    return _buildSummaryCard(
      title: l.location,
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${address['city'] ?? ''}, ${address['street'] ?? ''} ${address['building_nr'] ?? ''}",
            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp),
          ),
          if (address['details'] != null && address['details'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(address['details'].toString(), style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
            ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final loc = center['location'] as Map?;
                if (loc != null) {
                  launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${loc['lat']},${loc['lng']}"));
                }
              },
              icon: Icon(Icons.map, size: 18.sp),
              label: Text(l.openInMaps),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.main,
                side: BorderSide(color: AppColors.main),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningHoursSectionDetailed(dynamic hours, AppLocalizations l) {
    if (hours == null || hours is! Map) return const SizedBox.shrink();
    
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final filteredDays = dayKeys.where((d) => hours[d] != null).toList();

    return _buildSummaryCard(
      title: l.openingHours,
      icon: Icons.access_time_outlined,
      child: Column(
        children: filteredDays.map((d) {
          final isClosed = hours[d]['is_closed'] == true;
          return Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_getDayLabel(d, l), style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                if (isClosed)
                  Text(l.closed, style: AppTextStyles.getText2(context).copyWith(color: Colors.red))
                else
                  Text("${hours[d]['open']} - ${hours[d]['close']}", style: AppTextStyles.getText2(context)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDayLabel(String key, AppLocalizations l) {
    switch (key) {
      case 'monday': return "Monday"; // Add localized if available
      case 'tuesday': return "Tuesday";
      case 'wednesday': return "Wednesday";
      case 'thursday': return "Thursday";
      case 'friday': return "Friday";
      case 'saturday': return "Saturday";
      case 'sunday': return "Sunday";
      default: return key;
    }
  }

  Widget _buildTeamSection(List<Map<String, dynamic>> team, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.myPractitioners, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
        SizedBox(height: 12.h),
        SizedBox(
          height: 140.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: team.length,
            itemBuilder: (context, index) {
              final doc = team[index];
              final img = resolveDoctorImagePathAndWidget(doctor: doc, width: 60, height: 60);
              return GestureDetector(
                onTap: () => Navigator.push(context, fadePageRoute(DoctorProfilePage(doctorId: doc['id'], doctor: doc))),
                child: Container(
                  width: 100.w,
                  margin: EdgeInsets.only(right: 12.w),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30.r,
                        backgroundImage: img.imageProvider,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "${doc['first_name']} ${doc['last_name']}",
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        doc['specialty'] ?? '',
                        style: AppTextStyles.getText4(context).copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(dynamic description) {
    try {
      final doc = quill.Document.fromJson(jsonDecode(description));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.profile, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
          SizedBox(height: 8.h),
          quill.QuillEditor.basic(
            controller: quill.QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: true,
            ),
            focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildGallerySection(List<dynamic> gallery, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.gallery, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
        SizedBox(height: 12.h),
        SizedBox(
          height: 100.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: gallery.length,
            itemBuilder: (context, index) {
              final path = gallery[index].toString();
              final url = Supabase.instance.client.storage.from('center-images').getPublicUrl(path);
              return Container(
                margin: EdgeInsets.only(right: 8.w),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 150.w,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFaqSection(List<dynamic> faqs, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.faq, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp)),
        SizedBox(height: 8.h),
        ...faqs.map((f) => ExpansionTile(
          title: Text(f['question'] ?? '', style: AppTextStyles.getText2(context)),
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Text(f['answer'] ?? '', style: AppTextStyles.getText3(context)),
            ),
          ],
        )),
      ],
    );
  }


  void _shareCenter(Map<String, dynamic> center) {
    Share.share("${center['name']} - DocSera\n${center['specialties']?.join(' • ') ?? ''}");
  }
}
