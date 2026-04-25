import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final int index;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.index = 0,
  });

  @override
  State<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<TransactionTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  // ─── Extracted fields ──────────────────────────────────────

  Map<String, dynamic> get _tx => widget.transaction;
  int get _points => (_tx['points'] as num?)?.toInt() ?? 0;
  String get _description => _tx['description'] as String? ?? '';
  String get _createdAt => _tx['created_at'] as String? ?? '';
  bool get _dbProcessed => _tx['processed'] as bool? ?? true;
  String? get _doctorName => _tx['doctor_name'] as String?;
  String? get _appointmentDateStr => _tx['appointment_date'] as String?;
  String? get _appointmentTimeStr => _tx['appointment_time'] as String?;
  String? get _patientName => _tx['patient_name'] as String?;
  bool get _isRelative => _tx['is_relative'] as bool? ?? false;
  Map<String, dynamic> get _metadata =>
      _tx['metadata'] as Map<String, dynamic>? ?? {};

  /// Pending if: processed=false OR created_at is in the future
  bool get _isPending {
    if (!_dbProcessed) return true;
    try {
      return DateTime.parse(_createdAt).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// The actual event date. For pending entries with future created_at,
  /// use metadata.event_date or created_at - 72h.
  DateTime? get _eventDate {
    // Try metadata first
    final metaDate = _metadata['event_date'] as String?;
    if (metaDate != null) {
      try {
        return DateTime.parse(metaDate).toLocal();
      } catch (_) {}
    }

    // For pending entries with future created_at, subtract the ripen window.
    // Use metadata.ripen_hours when available (falls back to 72h for legacy).
    try {
      final dt = DateTime.parse(_createdAt);
      if (dt.isAfter(DateTime.now())) {
        final ripen = (_metadata['ripen_hours'] as num?)?.toInt() ?? 72;
        return dt.subtract(Duration(hours: ripen)).toLocal();
      }
      return dt.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// When points will be available (the created_at for pending entries)
  DateTime? get _pointsAvailableDate {
    if (!_isPending) return null;
    try {
      return DateTime.parse(_createdAt).toLocal();
    } catch (_) {
      return null;
    }
  }

  int? get _pendingHoursRemaining {
    if (!_isPending) return null;
    try {
      final target = DateTime.parse(_createdAt);
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) return 0;
      return diff.inHours;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  // ─── Type detection ────────────────────────────────────────

  _TxType get _type {
    final metaType = _metadata['type'] as String?;
    if (metaType == 'referral') return _TxType.referral;
    if (metaType == 'welcome_referral') return _TxType.welcome;
    if (metaType == 'redeem') return _TxType.redeem;

    final desc = _description.toLowerCase();
    if (desc.contains('referral') && desc.contains('new user')) return _TxType.referral;
    if (desc.contains('welcome') || desc.contains('joined via')) return _TxType.welcome;
    if (desc.contains('appointment') || desc.contains('done') || desc.contains('completed')) return _TxType.appointment;
    if (desc.contains('redeem') || desc.contains('claimed')) return _TxType.redeem;
    return _points > 0 ? _TxType.earned : _TxType.spent;
  }

  String _localizedTitle(AppLocalizations l) {
    switch (_type) {
      case _TxType.referral:
        return l.transactionReferral;
      case _TxType.welcome:
        return l.transactionWelcome;
      case _TxType.appointment:
        return l.transactionAppointment;
      case _TxType.redeem:
        return l.transactionRedeemed;
      case _TxType.earned:
        return l.rewardPoints;
      case _TxType.spent:
        return l.transactionRedeemed;
    }
  }

  String _categoryLabel(AppLocalizations l) {
    switch (_type) {
      case _TxType.referral:
        return l.referralInvitation;
      case _TxType.welcome:
        return l.transactionWelcome;
      case _TxType.appointment:
        return l.appointments;
      case _TxType.redeem:
        return l.offers;
      case _TxType.earned:
        return l.rewardPoints;
      case _TxType.spent:
        return l.offers;
    }
  }

  IconData get _icon {
    switch (_type) {
      case _TxType.referral:
        return Icons.person_add_rounded;
      case _TxType.welcome:
        return Icons.card_giftcard_rounded;
      case _TxType.appointment:
        return Icons.calendar_today_rounded;
      case _TxType.redeem:
        return Icons.shopping_bag_rounded;
      case _TxType.earned:
        return Icons.add_circle_rounded;
      case _TxType.spent:
        return Icons.remove_circle_rounded;
    }
  }

  Color get _color {
    if (_isPending) return const Color(0xFFFF9800);
    if (_points <= 0) return const Color(0xFFE53935);
    switch (_type) {
      case _TxType.appointment:
        return const Color(0xFF4CAF50);
      default:
        return AppColors.main;
    }
  }

  // ─── Date/time formatting ──────────────────────────────────

  String _formatDate(BuildContext context, DateTime dt) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('dd MMM yyyy', locale).format(dt);
  }

  String _formatTime12h(BuildContext context, DateTime dt) {
    final l = AppLocalizations.of(context)!;
    final hour = dt.hour;
    final minute = dt.minute;
    final isPm = hour >= 12;
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    final period = isPm ? l.pm : l.am;
    return '$h12:$minuteStr $period';
  }

  String _formatDateTime(BuildContext context, DateTime dt) {
    return '${_formatDate(context, dt)}  •  ${_formatTime12h(context, dt)}';
  }

  String? _formatAppointmentTime(BuildContext context) {
    if (_appointmentTimeStr == null) return null;
    final l = AppLocalizations.of(context)!;
    try {
      final parts = _appointmentTimeStr!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final isPm = hour >= 12;
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final minuteStr = minute.toString().padLeft(2, '0');
      final period = isPm ? l.pm : l.am;
      return '$h12:$minuteStr $period';
    } catch (_) {
      return _appointmentTimeStr;
    }
  }

  String? _formatAppointmentDate(BuildContext context) {
    if (_appointmentDateStr == null) return null;
    try {
      final dt = DateTime.parse(_appointmentDateStr!);
      return _formatDate(context, dt);
    } catch (_) {
      return _appointmentDateStr;
    }
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final isPending = _isPending;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (widget.index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: _toggleExpand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: !isPending && _isExpanded
                ? Border.all(color: color.withOpacity(0.25))
                : null,
            boxShadow: isPending
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _isExpanded
                          ? color.withOpacity(0.08)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: _isExpanded ? 12 : 6,
                      offset: Offset(0, _isExpanded ? 4 : 2),
                    ),
                  ],
          ),
          child: isPending
              ? CustomPaint(
                  painter: _DashedBorderPainter(
                    color: const Color(0xFFFF9800).withOpacity(0.4),
                    borderRadius: 16.r,
                    dashWidth: 6,
                    dashGap: 4,
                    strokeWidth: 1.2,
                  ),
                  child: _buildCardContent(context, color, isPending),
                )
              : _buildCardContent(context, color, isPending),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Color color, bool isPending) {
    final isPositive = _points > 0;
    final eventDt = _eventDate;
    final dateStr = eventDt != null ? _formatDate(context, eventDt) : '—';
    return Column(
            children: [
              // ── Main row ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(
                  children: [
                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(_isExpanded ? 0.2 : 0.12),
                            color.withOpacity(_isExpanded ? 0.08 : 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(_icon, color: color, size: 20.sp),
                          if (isPending)
                            Positioned(
                              bottom: 1.r,
                              right: 1.r,
                              child: Container(
                                padding: EdgeInsets.all(2.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 2),
                                  ],
                                ),
                                child: Icon(Icons.schedule_rounded, size: 8.sp, color: const Color(0xFFFF9800)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizedTitle(AppLocalizations.of(context)!),
                            style: AppTextStyles.getText2(context).copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: isPending ? Colors.grey[700] : null,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 11.sp, color: Colors.grey[400]),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: AppTextStyles.getText3(context).copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ),
                              if (isPending)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 8.sp, color: const Color(0xFFFF9800)),
                                      SizedBox(width: 2.w),
                                      Text(
                                        AppLocalizations.of(context)!.pending,
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFF9800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Points badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}$_points',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),

                    // Expand arrow
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Icon(Icons.expand_more_rounded, size: 18.sp, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),

              // ── Expandable details ──
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: FadeTransition(
                  opacity: _expandAnimation,
                  child: _buildExpandedDetails(context),
                ),
              ),
            ],
          );
  }

  // ─── Expanded details ──────────────────────────────────────

  Widget _buildExpandedDetails(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = _color;
    final isPositive = _points > 0;
    final isPending = _isPending;
    final eventDt = _eventDate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: color.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pending banner ──
            if (isPending) ...[
              _buildPendingBanner(context, l),
              SizedBox(height: 10.h),
            ],

            // ── Type-specific details ──
            ..._buildTypeDetails(context, l),

            // ── Common details ──
            _detailRow(context, Icons.category_rounded, l.transactionType, _categoryLabel(l), color),
            SizedBox(height: 6.h),
            _detailRow(
              context,
              isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              l.transactionAmount,
              '${isPositive ? '+' : ''}$_points ${l.points}',
              color,
            ),
            SizedBox(height: 6.h),
            if (eventDt != null) ...[
              _detailRow(context, Icons.schedule_rounded, l.transactionTime, _formatDateTime(context, eventDt), Colors.grey[600]!),
              SizedBox(height: 6.h),
            ],
            // Points available date for pending
            if (isPending && _pointsAvailableDate != null) ...[
              _detailRow(
                context,
                Icons.event_available_rounded,
                l.pointsAvailableOn,
                _formatDateTime(context, _pointsAvailableDate!),
                const Color(0xFFFF9800),
              ),
              SizedBox(height: 6.h),
            ],
            _detailRow(
              context,
              isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
              l.transactionStatus,
              isPending ? l.transactionProcessing : l.transactionCompleted,
              isPending ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeDetails(BuildContext context, AppLocalizations l) {
    switch (_type) {
      case _TxType.appointment:
        return _appointmentDetails(context, l);
      case _TxType.referral:
        return _referralDetails(context, l);
      case _TxType.welcome:
        return _welcomeDetails(context, l);
      case _TxType.redeem:
        return _redeemDetails(context, l);
      case _TxType.earned:
      case _TxType.spent:
        return _genericDetails(context, l);
    }
  }

  // ── Appointment ──

  List<Widget> _appointmentDetails(BuildContext context, AppLocalizations l) {
    final rows = <Widget>[];

    if (_doctorName != null && _doctorName!.isNotEmpty) {
      rows.add(_detailRow(context, Icons.medical_services_rounded, l.doctor, _doctorName!, AppColors.main));
      rows.add(SizedBox(height: 6.h));
    }

    if (_patientName != null && _patientName!.isNotEmpty) {
      final label = _isRelative ? '${l.patientName} (${l.forRelative})' : l.patientName;
      rows.add(_detailRow(context, Icons.person_rounded, label, _patientName!, Colors.grey[700]!));
      rows.add(SizedBox(height: 6.h));
    }

    final apptDate = _formatAppointmentDate(context);
    final apptTime = _formatAppointmentTime(context);
    if (apptDate != null || apptTime != null) {
      final parts = [apptDate, apptTime].where((s) => s != null);
      rows.add(_detailRow(context, Icons.event_rounded, l.appointmentDate, parts.join('  •  '), Colors.grey[600]!));
      rows.add(SizedBox(height: 6.h));
    }

    if (_eventDate != null) {
      rows.add(_detailRow(context, Icons.done_all_rounded, l.appointmentMarkedDone, _formatDateTime(context, _eventDate!), const Color(0xFF4CAF50)));
      rows.add(SizedBox(height: 6.h));
    }

    if (rows.isNotEmpty) {
      rows.add(Divider(color: Colors.grey.withOpacity(0.15), height: 16.h));
    }
    return rows;
  }

  // ── Referral ──

  List<Widget> _referralDetails(BuildContext context, AppLocalizations l) {
    final rows = <Widget>[];

    // Referred user name from metadata
    final referredName = _metadata['referred_user_name'] as String?;
    if (referredName != null && referredName.isNotEmpty) {
      rows.add(_detailRow(context, Icons.person_add_rounded, l.referredUser, referredName, AppColors.main));
      rows.add(SizedBox(height: 6.h));
    }

    // Event date (when the referral actually happened)
    if (_eventDate != null) {
      rows.add(_detailRow(context, Icons.event_rounded, l.eventDate, _formatDateTime(context, _eventDate!), Colors.grey[600]!));
      rows.add(SizedBox(height: 6.h));
    }

    if (rows.isNotEmpty) {
      rows.add(Divider(color: Colors.grey.withOpacity(0.15), height: 16.h));
    }
    return rows;
  }

  // ── Welcome bonus ──

  List<Widget> _welcomeDetails(BuildContext context, AppLocalizations l) {
    if (_eventDate != null) {
      return [
        _detailRow(context, Icons.event_rounded, l.eventDate, _formatDateTime(context, _eventDate!), Colors.grey[600]!),
        SizedBox(height: 6.h),
        Divider(color: Colors.grey.withOpacity(0.15), height: 16.h),
      ];
    }
    return [];
  }

  // ── Redeem ──

  List<Widget> _redeemDetails(BuildContext context, AppLocalizations l) {
    final rows = <Widget>[];
    final locale = Localizations.localeOf(context).languageCode;

    // Offer title from metadata (localized) or fallback from description
    String offerName;
    if (locale == 'ar' && _metadata['offer_title_ar'] != null) {
      offerName = _metadata['offer_title_ar'] as String;
    } else if (_metadata['offer_title'] != null) {
      offerName = _metadata['offer_title'] as String;
    } else if (_description.contains(':')) {
      offerName = _description.split(':').sublist(1).join(':').trim();
    } else {
      offerName = _description;
    }

    rows.add(_detailRow(context, Icons.local_offer_rounded, l.offerDetails, offerName, const Color(0xFFE53935)));
    rows.add(SizedBox(height: 6.h));

    // Partner name from metadata
    String? partnerName;
    if (locale == 'ar' && _metadata['partner_name_ar'] != null) {
      partnerName = _metadata['partner_name_ar'] as String;
    } else if (_metadata['partner_name'] != null) {
      partnerName = _metadata['partner_name'] as String;
    }
    if (partnerName != null && partnerName.isNotEmpty) {
      rows.add(_detailRow(context, Icons.store_rounded, l.partnerLabel, partnerName, AppColors.main));
      rows.add(SizedBox(height: 6.h));
    }

    // Voucher expires
    final expiresAt = _metadata['expires_at'] as String?;
    if (expiresAt != null) {
      try {
        final dt = DateTime.parse(expiresAt).toLocal();
        rows.add(_detailRow(context, Icons.timer_outlined, l.voucherExpiresOn, _formatDate(context, dt), const Color(0xFFFF9800)));
        rows.add(SizedBox(height: 6.h));
      } catch (_) {}
    }

    // Voucher location info
    rows.add(SizedBox(height: 2.h));
    rows.add(Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.main.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.main.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14.sp, color: AppColors.main),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              l.voucherLocation,
              style: AppTextStyles.getText3(context).copyWith(
                color: AppColors.main,
                fontWeight: FontWeight.w600,
                fontSize: 10.sp,
              ),
            ),
          ),
        ],
      ),
    ));
    rows.add(SizedBox(height: 6.h));

    rows.add(Divider(color: Colors.grey.withOpacity(0.15), height: 16.h));
    return rows;
  }

  // ── Generic ──

  List<Widget> _genericDetails(BuildContext context, AppLocalizations l) {
    if (_description.isNotEmpty) {
      return [
        _detailRow(context, Icons.info_outline_rounded, l.transactionType, _description, Colors.grey[600]!),
        SizedBox(height: 6.h),
        Divider(color: Colors.grey.withOpacity(0.15), height: 16.h),
      ];
    }
    return [];
  }

  // ─── Pending banner ────────────────────────────────────────

  Widget _buildPendingBanner(BuildContext context, AppLocalizations l) {
    final hoursLeft = _pendingHoursRemaining;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13.sp, color: Colors.grey[500]),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  l.pendingPointsNote,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],
          ),
          if (hoursLeft != null && hoursLeft > 0) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  l.hoursRemaining(hoursLeft),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF9800),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      // Use the entry's own ripen window if recorded
                      // (falls back to 72h for legacy entries).
                      value: (() {
                        final ripen = (_metadata['ripen_hours'] as num?)?.toDouble() ?? 72.0;
                        return (1.0 - (hoursLeft / ripen)).clamp(0.0, 1.0);
                      })(),
                      backgroundColor: Colors.grey.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
                      minHeight: 3.h,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Detail row ────────────────────────────────────────────

  Widget _detailRow(BuildContext context, IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Icon(icon, size: 14.sp, color: color.withOpacity(0.7)),
        ),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: AppTextStyles.getText3(context).copyWith(
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
            fontSize: 10.sp,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 10.sp,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

enum _TxType { appointment, referral, welcome, redeem, earned, spent }

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = _createDashedPath(path);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashGap;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      dashWidth != oldDelegate.dashWidth ||
      dashGap != oldDelegate.dashGap ||
      strokeWidth != oldDelegate.strokeWidth;
}
