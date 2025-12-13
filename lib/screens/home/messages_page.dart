  import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
  import 'package:docsera/Business_Logic/Messages_page/messages_state.dart';
  import 'package:docsera/screens/home/messages/conversation/conversation_page.dart';
  import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
  import 'package:docsera/screens/search_page.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
  import 'package:docsera/gen_l10n/app_localizations.dart';
  import 'package:flutter_screenutil/flutter_screenutil.dart';
  import 'package:docsera/app/text_styles.dart';
  import 'package:docsera/app/const.dart';
  import 'package:docsera/screens/auth/identification_page.dart';
  import 'package:docsera/utils/page_transitions.dart';
  import 'package:intl/intl.dart';

  import '../../models/conversation.dart';

  class MessagesPage extends StatefulWidget {
    const MessagesPage({Key? key}) : super(key: key);

    @override
    _MessagesPageState createState() => _MessagesPageState();
  }

  class _MessagesPageState extends State<MessagesPage> {
    bool isExpanded = false;

    @override
    void initState() {
      super.initState();
      context.read<MessagesCubit>().loadMessages(context);
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<MessagesCubit, MessagesState>(
          builder: (context, state) {
            if (state is MessagesLoading) {
              return _buildMessagesShimmer();
            } else if (state is MessagesNotLogged) {
              return _buildLoginPrompt();
            } else if (state is MessagesLoaded) {
              return _buildMessagesList(state);
            } else if (state is MessagesError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox();
          },
        ),
        floatingActionButton: BlocBuilder<MessagesCubit, MessagesState>(
          builder: (context, state) {
            if (state is MessagesLoaded) {
              return FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(context, fadePageRoute(const SearchPage(mode: "message")));
                },
                icon: Icon(Icons.edit, color: AppColors.whiteText, size: 16.sp),
                label: Text(
                  AppLocalizations.of(context)!.sendMessage,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.whiteText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                elevation: 0,
                backgroundColor: AppColors.main,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.r),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    Widget _buildMessagesShimmer() {
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 56.h),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerWidget(
                  width: 40.r,
                  height: 40.r,
                  radius: 20.r,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerWidget(width: 120.w, height: 12.h),
                      SizedBox(height: 6.h),
                      ShimmerWidget(width: double.infinity, height: 10.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }


    Widget _buildLoginPrompt() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/messages.png", height: 100.h),
            SizedBox(height: 20.h),
            Text(
              AppLocalizations.of(context)!.sendMessageTitle,
              style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                AppLocalizations.of(context)!.sendMessagesDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, fadePageRoute(const IdentificationPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
              ),
              child: Text(
                AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getText1(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }


    Widget _buildInitialMessagesPage() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/messages.png", height: 100.h),
            SizedBox(height: 20.h),
            Text(
              AppLocalizations.of(context)!.sendMessageTitle,
              style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.grayMain),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                AppLocalizations.of(context)!.sendMessagesDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }



    Widget _buildBannerCard() {
      return Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.main.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/messages_banner.png', // استبدلها بالصورة المناسبة
                width: 45.w,
                height: 45.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.messageAccessInfo, // أضف هذه الترجمة في ARB
                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.blackText),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildMessagesList(MessagesLoaded state) {
      if (state.conversations.isEmpty) {
        return _buildInitialMessagesPage();
      }
      final Map<String, List<Conversation>> groupedByDoctor = {};

      for (final convo in state.conversations) {
        final doctorId = convo.doctorId;
        if (!groupedByDoctor.containsKey(doctorId)) {
          groupedByDoctor[doctorId] = [];
        }
        groupedByDoctor[doctorId]!.add(convo);
      }

      final List<Widget> children = [
        SizedBox(height: 15.h),
        _buildBannerCard(),
      ];

      groupedByDoctor.entries.forEach((entry) {
        final doctorId = entry.key;
        final convos = entry.value;
        final firstConvo = convos.first;

        final isForSelf = convos.length == 1 &&
            (firstConvo.patientName == firstConvo.accountHolderName);

        if (isForSelf) {
          children.add(_buildConversationTile(context, firstConvo, showDoctorName: true));
        } else {
          children.add(_buildGroupedDoctorTile(context, convos));
        }
      });

      children.add(SizedBox(height: 80.h));

      return ListView(
        padding: EdgeInsets.zero,
        children: children,
      );
    }


    Widget _buildGroupedDoctorTile(BuildContext context, List<Conversation> convos) {
      final doctor = convos.first;
      final totalUnread = convos.fold<int>(0, (sum, c) => sum + (c.unreadCountForUser ?? 0));

      final imageResult = resolveDoctorImagePathAndWidget(
        doctor: {
          'doctor_image': doctor.doctorImage,
          'gender': doctor.doctorGender,
          'title': doctor.doctorTitle,
        },
        width: 44,
        height: 44,
      );

      return StatefulBuilder(
        builder: (context, setState) {
          final isRTL = Directionality.of(context).toString().contains('rtl');
          return Container(
            color: isExpanded ? AppColors.main.withOpacity(0.03) : Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => isExpanded = !isExpanded),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22.r,
                                  backgroundColor: AppColors.main.withOpacity(0.1),
                                  backgroundImage: imageResult.imageProvider,

                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(2.w),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Container(
                                      width: 16.w,
                                      height: 16.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.mainDark.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        convos.length.toString(),
                                        style: AppTextStyles.getText3(context).copyWith(
                                          fontSize: 8.sp,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              doctor.doctorName ?? '',
                              style: AppTextStyles.getTitle1(context),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            if (totalUnread > 0)
                              Padding(
                                padding: EdgeInsets.only(left: 6.w),
                                child: Container(
                                  width: 16.w,
                                  height: 16.w,
                                  decoration: const BoxDecoration(
                                    color: AppColors.main,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    totalUnread.toString(),
                                    style: AppTextStyles.getText3(context).copyWith(
                                      color: Colors.white,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  ...convos.map((convo) {
                    return Padding(
                      padding: EdgeInsets.only(left: isRTL? 0 : 16.w , right: isRTL? 24.w  : 0,),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: isRTL
                                ? BorderSide.none
                                : BorderSide(
                              color: convo.patientName == convo.accountHolderName
                                  ? AppColors.main.withOpacity(0.8)
                                  : AppColors.yellow.withOpacity(0.6),
                              width: 4.w,
                            ),
                            right: isRTL
                                ? BorderSide(
                              color: convo.patientName == convo.accountHolderName
                                  ? AppColors.main.withOpacity(0.8)
                                  : AppColors.yellow.withOpacity(0.6),
                              width: 4.w,
                            )
                                : BorderSide.none,
                          ),
                        ),


                        child: _buildConversationTile(context, convo, groupCount: convos.length, showDoctorName: false),
                      ),
                    );
                  }).toList(),

                if (!isExpanded)
                  Divider(color: Colors.grey.shade300, height: 1),
              ],
            ),
          );
        },
      );
    }


    Widget _buildYearHeader(int year) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h, top: 10.h),
        child: Row(
          children: [
            Text(
              year.toString(),
              style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.grayMain, fontSize: 12.sp),
            ),
            SizedBox(width: 8.w),
            const Expanded(
              child: Divider(
                color: AppColors.grayMain,
                thickness: 1,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildConversationTile(BuildContext context, Conversation convo, {int? groupCount, bool showDoctorName = false}){
      final isClosed = convo.isClosed;
      DateTime? lastMessageTime = convo.messages.isNotEmpty
          ? convo.messages.first['timestamp']
          : convo.updatedAt;

      String trailingText = '';
      if (lastMessageTime != null) {
        final now = DateTime.now();
        final isToday = now.year == lastMessageTime.year &&
            now.month == lastMessageTime.month &&
            now.day == lastMessageTime.day;

        final isYesterday = now.subtract(const Duration(days: 1)).year == lastMessageTime.year &&
            now.subtract(const Duration(days: 1)).month == lastMessageTime.month &&
            now.subtract(const Duration(days: 1)).day == lastMessageTime.day;

        if (isToday) {
          final lang = Localizations.localeOf(context).languageCode;
          final timeStr = DateFormat('hh:mm a').format(lastMessageTime);
          if (lang == 'ar') {
            trailingText = timeStr.replaceAll('AM', 'ص').replaceAll('PM', 'م');
          } else {
            trailingText = timeStr;
          }
        } else if (isYesterday) {
          trailingText = AppLocalizations.of(context)!.yesterday;
        } else {
          trailingText = DateFormat('dd/MM/yyyy').format(lastMessageTime);
        }
      }
      print('TITLE: ${convo.doctorTitle} - GENDER: ${convo.doctorGender}');


      final unreadCount = convo.unreadCountForUser ?? 0;

      final imageResult = resolveDoctorImagePathAndWidget(
        doctor: {
          'doctor_image': convo.doctorImage,
          'gender': convo.doctorGender,
          'title': convo.doctorTitle,
        },
        width: 44,
        height: 44,
      );


      return InkWell(
        onTap: () async {
          final imageResult = resolveDoctorImagePathAndWidget(
            doctor: {
              'doctor_image': convo.doctorImage,
              'gender': convo.doctorGender,
              'title': convo.doctorTitle,
            },
            width: 44,
            height: 44,
          );

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => ConversationCubit(ConversationService()),
                child: ConversationPage(
                  conversationId: convo.id,
                  doctorName: convo.doctorName ?? '',
                  patientName: convo.patientName ?? '',
                  accountHolderName: convo.accountHolderName ?? '',
                  doctorAvatar: imageResult.imageProvider,      // أهم شيء
                ),

              ),
            ),
          );


          context.read<MessagesCubit>().loadMessages(context); // ✅ reload after returning
        },


        child: Container(
          color: showDoctorName ? Colors.transparent :AppColors.grayMain.withOpacity(0.05),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: showDoctorName ? 16.w : 0, vertical: 8.h ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupCount != null)
                  const SizedBox()// hide avatar
                    else
                    CircleAvatar(
                          radius: 22.r,
                          backgroundColor: AppColors.main.withOpacity(0.1),
                          backgroundImage: imageResult.imageProvider,

                  ),

                    SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              showDoctorName ? (convo.doctorName ?? '') : (convo.patientName ?? ''),
                              style:  showDoctorName ? AppTextStyles.getTitle1(context) : AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp, color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: showDoctorName ? 0 : 16.w, ),
                            child: Text(
                              trailingText,
                              style: AppTextStyles.getText3(context).copyWith(color: Colors.grey, fontSize: showDoctorName ? 10.sp : 8.sp),
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
                              isClosed
                                  ? AppLocalizations.of(context)!.conversationClosed
                                  : convo.lastMessage,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.black54,
                                fontSize: showDoctorName ? 10.sp: 9.sp,
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          ),
                          SizedBox(width: 8.w),

                          if (unreadCount > 0)
                            Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: Container(
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
                            ),


                        ],
                      ),
                    ],
                  ),
                ),
                  ],
                ),
              ),
              Divider(color: showDoctorName? Colors.grey.shade300 : Colors.grey.shade400, height: 0.5),

            ],
          ),
        ),
      );
    }
  }
