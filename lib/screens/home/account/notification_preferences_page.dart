// Per-category × per-channel notification preferences for the patient.
// Replaces the placeholder row in preferences.dart that previously did
// nothing on tap. All persistence goes through rpc_get_my_notification_settings,
// rpc_set_my_notification_preference and rpc_set_my_quiet_hours.
//
// Design notes:
// - Lazy defaults — if no row exists for (user_id, category) the dispatcher
//   treats every channel as enabled and quiet hours as respected. Users only
//   write rows when they change something.
// - Two categories carry an "always on" tooltip and a confirmation dialog
//   on attempted mute: appointments and security. The toggle still flips
//   if the user confirms — we don't gatekeep them, we just slow them down.
// - Email channel rendered disabled with "coming soon" until Phase 4.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/widgets/base_scaffold.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  static const _categories = <String>[
    'appointments',
    'messages',
    'documents',
    'reports',
    'loyalty',
    'security',
    'marketing',
  ];

  static const _alwaysOnCategories = {'appointments', 'security'};

  bool _loading = true;
  String? _error;

  // category → flags. Defaults applied if no server row.
  final Map<String, _PrefRow> _prefs = {
    for (final c in _categories)
      c: const _PrefRow(push: true, inApp: true, respectQuietHours: true),
  };

  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  DateTime? _dndUntil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client
          .rpc('rpc_get_my_notification_settings');
      final map = res as Map<String, dynamic>;
      final prefList = (map['preferences'] as List?) ?? const [];
      for (final row in prefList) {
        final m = row as Map<String, dynamic>;
        final cat = m['category'] as String;
        if (_prefs.containsKey(cat)) {
          _prefs[cat] = _PrefRow(
            push: (m['push_enabled'] as bool?) ?? true,
            inApp: (m['in_app_enabled'] as bool?) ?? true,
            respectQuietHours:
                (m['respects_quiet_hours'] as bool?) ?? true,
          );
        }
      }
      final qh = (map['quiet_hours'] as Map?)?.cast<String, dynamic>();
      if (qh != null) {
        _quietEnabled = (qh['enabled'] as bool?) ?? false;
        final s = qh['start_local'] as String?;
        final e = qh['end_local'] as String?;
        if (s != null) _quietStart = _parseTime(s) ?? _quietStart;
        if (e != null) _quietEnd = _parseTime(e) ?? _quietEnd;
        final until = qh['dnd_until'] as String?;
        if (until != null) _dndUntil = DateTime.tryParse(until)?.toLocal();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  TimeOfDay? _parseTime(String iso) {
    final parts = iso.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _savePref(String category, _PrefRow row) async {
    try {
      await Supabase.instance.client.rpc(
        'rpc_set_my_notification_preference',
        params: {
          'p_category': category,
          'p_push_enabled': row.push,
          'p_in_app_enabled': row.inApp,
          'p_respects_quiet_hours': row.respectQuietHours,
        },
      );
    } catch (_) {/* swallow — UI already optimistically updated */}
  }

  Future<void> _saveQuietHours() async {
    try {
      await Supabase.instance.client.rpc(
        'rpc_set_my_quiet_hours',
        params: {
          'p_enabled': _quietEnabled,
          'p_start_local': _fmtTime(_quietStart),
          'p_end_local': _fmtTime(_quietEnd),
          'p_dnd_until': _dndUntil?.toUtc().toIso8601String(),
        },
      );
    } catch (_) {/* swallow */}
  }

  Future<bool> _confirmMuteIfNeeded(String category) async {
    if (!_alwaysOnCategories.contains(category)) return true;
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.notificationPrefsConfirmMute),
        content: Text(loc.notificationPrefsConfirmMuteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return BaseScaffold(
      title: Text(
        loc.notificationPrefsTitle,
        style: AppTextStyles.getTitle1(context)
            .copyWith(color: AppColors.whiteText),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  children: [
                    for (final c in _categories) _buildCategoryCard(c, loc),
                    SizedBox(height: 16.h),
                    _buildQuietHoursCard(loc),
                    SizedBox(height: 16.h),
                    _buildTestReminderTile(loc),
                    SizedBox(height: 32.h),
                  ],
                ),
    );
  }

  Widget _buildTestReminderTile(AppLocalizations loc) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.notificationPrefsTestReminderTitle,
            style: AppTextStyles.getText2(context)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4.h),
          Text(
            loc.notificationPrefsTestReminderDescription,
            style: AppTextStyles.getText3(context)
                .copyWith(color: Colors.grey.shade700),
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await NotificationService.instance
                    .sendTestReminder(delaySeconds: 5);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.notificationPrefsTestReminderQueued),
                    backgroundColor: AppColors.main,
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              icon: Icon(Icons.bolt_rounded, size: 16.sp),
              label: Text(
                loc.notificationPrefsTestReminderButton,
                style: TextStyle(fontSize: 12.sp),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.main.withValues(alpha: 0.12),
                foregroundColor: AppColors.main,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, AppLocalizations loc) {
    final row = _prefs[category]!;
    final alwaysOn = _alwaysOnCategories.contains(category);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(0, 8.h, 0, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _categoryLabel(category, loc),
                    style: AppTextStyles.getText2(context)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (alwaysOn)
                  Tooltip(
                    message: loc.notificationPrefsAlwaysOnExplanation,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.giftAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        loc.notificationPrefsAlwaysOn,
                        style: TextStyle(
                          color: AppColors.giftAccent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _channelRow(
            label: loc.notificationPrefsPushChannel,
            value: row.push,
            onChanged: (v) async {
              if (!v && !await _confirmMuteIfNeeded(category)) return;
              setState(() {
                _prefs[category] = row.copyWith(push: v);
              });
              await _savePref(category, _prefs[category]!);
            },
          ),
          _channelRow(
            label: loc.notificationPrefsInAppChannel,
            value: row.inApp,
            onChanged: (v) async {
              if (!v && !await _confirmMuteIfNeeded(category)) return;
              setState(() {
                _prefs[category] = row.copyWith(inApp: v);
              });
              await _savePref(category, _prefs[category]!);
            },
          ),
          _channelRow(
            label:
                '${loc.notificationPrefsEmailChannel} · ${loc.notificationPrefsEmailComingSoon}',
            value: false,
            onChanged: null,
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _channelRow({
    required String label,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.getText3(context).copyWith(
                color: onChanged == null
                    ? Colors.grey.shade500
                    : AppColors.mainDark,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.main,
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursCard(AppLocalizations loc) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.notificationPrefsQuietHoursTitle,
                  style: AppTextStyles.getText2(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: _quietEnabled,
                onChanged: (v) {
                  setState(() => _quietEnabled = v);
                  _saveQuietHours();
                },
                activeColor: AppColors.main,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4.h, bottom: 12.h),
            child: Text(
              loc.notificationPrefsQuietHoursDescription,
              style: AppTextStyles.getText3(context)
                  .copyWith(color: Colors.grey.shade700),
            ),
          ),
          if (_quietEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: _timeButton(
                    label: loc.notificationPrefsQuietHoursStart,
                    value: _quietStart,
                    onPressed: () => _pickTime(true),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _timeButton(
                    label: loc.notificationPrefsQuietHoursEnd,
                    value: _quietEnd,
                    onPressed: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              loc.notificationPrefsQuietHoursOverride,
              style: AppTextStyles.getText4(context)
                  .copyWith(color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay value,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        side: BorderSide(color: AppColors.main.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.getText4(context)
                .copyWith(color: Colors.grey.shade700),
          ),
          SizedBox(height: 2.h),
          Text(
            _fmtTime(value),
            style: AppTextStyles.getText2(context)
                .copyWith(color: AppColors.mainDark, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
      await _saveQuietHours();
    }
  }

  String _categoryLabel(String category, AppLocalizations loc) {
    switch (category) {
      case 'appointments':
        return loc.notificationPrefsCategoryAppointments;
      case 'messages':
        return loc.notificationPrefsCategoryMessages;
      case 'documents':
        return loc.notificationPrefsCategoryDocuments;
      case 'reports':
        return loc.notificationPrefsCategoryReports;
      case 'loyalty':
        return loc.notificationPrefsCategoryLoyalty;
      case 'security':
        return loc.notificationPrefsCategorySecurity;
      case 'marketing':
        return loc.notificationPrefsCategoryMarketing;
      default:
        return category;
    }
  }
}

class _PrefRow {
  final bool push;
  final bool inApp;
  final bool respectQuietHours;

  const _PrefRow({
    required this.push,
    required this.inApp,
    required this.respectQuietHours,
  });

  _PrefRow copyWith({bool? push, bool? inApp, bool? respectQuietHours}) {
    return _PrefRow(
      push: push ?? this.push,
      inApp: inApp ?? this.inApp,
      respectQuietHours: respectQuietHours ?? this.respectQuietHours,
    );
  }
}
