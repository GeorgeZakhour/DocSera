import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/conversation.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

import '../../../Business_Logic/Doctor/Messages_page/doctor_messages_cubit.dart';
import '../../../Business_Logic/Doctor/Messages_page/doctor_messages_state.dart';

class DoctorMessagesPage extends StatelessWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorMessagesPage({Key? key, this.doctorData}) : super(key: key);

  String _getDoctorAvatar(Map<String, dynamic>? doctor) {
    if (doctor == null) return 'assets/images/male-doc.png';
    if (doctor['profileImage'] != null && doctor['profileImage'].toString().isNotEmpty) {
      return doctor['profileImage'];
    }
    String gender = doctor['gender']?.toLowerCase() ?? 'male';
    String title = doctor['title']?.toLowerCase() ?? '';
    return (title == "dr.")
        ? (gender == "female" ? 'assets/images/female-doc.png' : 'assets/images/male-doc.png')
        : (gender == "female" ? 'assets/images/female-phys.png' : 'assets/images/male-phys.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DoctorDrawer(doctorData: doctorData),
      appBar: AppBar(
        backgroundColor: AppColors.main,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.whiteText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.messages,
          style: const TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<DoctorMessagesCubit, DoctorMessagesState>(
        builder: (context, state) {
          if (state is DoctorMessagesLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DoctorMessagesError) {
            return Center(child: Text(state.message));
          } else if (state is DoctorMessagesLoaded) {
            final conversations = state.conversations;
            if (conversations.isEmpty) {
              return Center(child: Text('No Message'));
            }

            final grouped = <int, List<Conversation>>{};
            for (final convo in conversations) {
              final year = convo.updatedAt.year;
              grouped.putIfAbsent(year, () => []).add(convo);
            }

            final sortedYears = grouped.keys.toList()..sort((b, a) => a.compareTo(b));

            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              itemCount: sortedYears.length,
              itemBuilder: (context, yearIndex) {
                final year = sortedYears[yearIndex];
                final convos = grouped[year]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h, top: 10.h),
                      child: Row(
                        children: [
                          Text(
                            year.toString(),
                            style: AppTextStyles.getTitle1(context).copyWith(
                              color: AppColors.grayMain,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          const Expanded(child: Divider(color: AppColors.grayMain, thickness: 1)),
                        ],
                      ),
                    ),
                    ...convos.map((convo) => _buildConversationTile(context, convo)).toList(),
                  ],
                );
              },
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, Conversation convo) {
    final lang = Localizations.localeOf(context).languageCode;
    final unreadCount = convo.unreadCountForDoctor ?? 0;
    final timestamp = convo.messages.isNotEmpty
        ? convo.messages.last['timestamp'] as DateTime
        : convo.updatedAt;
    final lastText = convo.lastMessage;
    final patientName = convo.patientName ?? '';
    final accountHolderName = convo.accountHolderName ?? '';

    final isToday = DateTime.now().difference(timestamp).inDays == 0;
    final isYesterday = DateTime.now().difference(timestamp).inDays == 1;

    String timeString;
    if (isToday) {
      final formatted = DateFormat('hh:mm a').format(timestamp);
      timeString = lang == 'ar'
          ? formatted.replaceAll('AM', 'ص').replaceAll('PM', 'م')
          : formatted;
    } else if (isYesterday) {
      timeString = AppLocalizations.of(context)!.yesterday;
    } else {
      timeString = DateFormat('dd/MM/yyyy').format(timestamp);
    }

    final fullName = '${doctorData?['title'] ?? ''} ${doctorData?['first_name'] ?? ''} ${doctorData?['last_name'] ?? ''}'.trim();
    final imageUrl = _getDoctorAvatar(doctorData);

    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorConversationPage(
                  conversationId: convo.id,
                  patientName: patientName,
                  accountHolderName: accountHolderName,
                  selectedReason: convo.selectedReason ?? '',
                  isClosed: convo.isClosed,
                  doctorName: fullName,
                  doctorImage: imageUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppColors.main.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppColors.main),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  patientName,
                                  style: AppTextStyles.getTitle1(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(width: 10.w),
                                if (accountHolderName != patientName)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                    margin: EdgeInsets.only(bottom: 2.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.main.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: lang == 'ar' ? 'من حساب : ' : 'From: ',
                                            style: AppTextStyles.getText3(context).copyWith(
                                              color: AppColors.main,
                                              fontSize: 7.sp,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          TextSpan(
                                            text: accountHolderName,
                                            style: AppTextStyles.getText3(context).copyWith(
                                              color: AppColors.main,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            timeString,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: Colors.grey,
                              fontSize: 9.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              lastText,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.black54,
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (unreadCount > 0)
                            Container(
                              width: 16.w,
                              height: 16.w,
                              decoration: const BoxDecoration(
                                color: AppColors.main,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount.toString(),
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: Colors.white,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1.h, color: Colors.grey.shade300),
      ],
    );
  }

}
