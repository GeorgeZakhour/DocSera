import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/banner_model.dart';
import 'package:docsera/widgets/main_screen_widgets.dart'; // For BannerLogo
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerDetailsPage extends StatelessWidget {
  final BannerModel banner;
  final Color themeColor;

  const BannerDetailsPage({
    super.key,
    required this.banner,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a legible text color based on background luminance
    final isDark = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final String currentLang = Localizations.localeOf(context).languageCode;
    final contentSections = banner.getContentSections(currentLang);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.h,
            pinned: true,
            backgroundColor: themeColor,
            leading: IconButton(
              icon: Icon(Icons.close, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  banner.imagePath.startsWith('http')
                      ? Image.network(
                          banner.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: themeColor),
                        )
                      : Image.asset(
                          banner.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: themeColor),
                        ),
                  // Gradient overlay for text readability if title is on image (optional)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: themeColor.withOpacity(0.1), // Verified matching theme
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 250.h),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section (Logo + Title)
                    Row(
                      children: [
                        if (banner.logoPath != null) ...[
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: banner.logoContainerColor != null
                                  ? Color(int.parse(banner.logoContainerColor!.replaceFirst('#', '0xFF')))
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: SizedBox(
                              width: 40.w,
                              height: 40.w,
                              child: BannerLogo(path: banner.logoPath!, size: 40.w),
                            ),
                          ),
                          SizedBox(width: 15.w),
                        ],
                        Expanded(
                          child: Text(
                            banner.getTitle(currentLang),
                            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 20.sp),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    
                    // Main Body/Description
                    if (banner.getText(currentLang).isNotEmpty)
                      Text(
                        banner.getText(currentLang),
                        style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
                      ),
                    
                    SizedBox(height: 25.h),
                    Divider(color: Colors.grey.withOpacity(0.3)),
                    SizedBox(height: 15.h),

                    // Dynamic Content Sections
                    ...contentSections.map((section) => _buildSection(context, section)),
                    
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, BannerContentSection section) {
    switch (section.type) {
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.title != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  section.title!,
                  style: AppTextStyles.getTitle2(context).copyWith(fontSize: 16.sp),
                ),
              ),
            if (section.body != null)
              Text(
                section.body!,
                style: AppTextStyles.getText2(context).copyWith(height: 1.5),
              ),
            SizedBox(height: 20.h),
          ],
        );
      case 'image':
        return Column(
          children: [
            if (section.url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  section.url!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            SizedBox(height: 20.h),
          ],
        );
      case 'list':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (section.title != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  section.title!,
                  style: AppTextStyles.getTitle2(context).copyWith(fontSize: 16.sp),
                ),
              ),
            ...?section.items?.map((item) => Padding(
              padding: EdgeInsets.only(bottom: 6.h, left: 10.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(fontSize: 16.sp, color: AppColors.main)),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.getText2(context),
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 20.h),
          ],
        );
       case 'button': // Extending for CTA
         return Center(
           child: ElevatedButton(
             onPressed: () async {
                 if (section.url != null) {
                   final uri = Uri.parse(section.url!);
                   if (await canLaunchUrl(uri)) {
                     await launchUrl(uri);
                   }
                 }
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: themeColor,
               padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
             ),
             child: Text(
               section.title ?? 'Learn More',
               style: TextStyle(color: ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black),
             ),
           ),
         );
      default:
        return const SizedBox();
    }
  }
}
