import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfigResult {
  final bool forceUpdate;
  final String storeUrl;
  final String messageEn;
  final String messageAr;

  const AppConfigResult({
    required this.forceUpdate,
    required this.storeUrl,
    required this.messageEn,
    required this.messageAr,
  });

  static const AppConfigResult ok = AppConfigResult(
    forceUpdate: false,
    storeUrl: '',
    messageEn: '',
    messageAr: '',
  );
}

class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Future<AppConfigResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final response = await Supabase.instance.client
          .rpc('rpc_get_app_config')
          .timeout(const Duration(seconds: 6));
      if (response is! Map) return AppConfigResult.ok;

      final isIos = Platform.isIOS;
      final minVersion = (isIos
          ? response['min_supported_version_ios']
          : response['min_supported_version_android']) as String?;
      final storeUrl = (isIos
          ? response['ios_store_url']
          : response['android_store_url']) as String? ?? '';
      final messageEn = response['force_update_message_en'] as String? ?? '';
      final messageAr = response['force_update_message_ar'] as String? ?? '';

      if (minVersion == null || minVersion.isEmpty) return AppConfigResult.ok;
      if (_isBelow(current, minVersion)) {
        return AppConfigResult(
          forceUpdate: true,
          storeUrl: storeUrl,
          messageEn: messageEn,
          messageAr: messageAr,
        );
      }
      return AppConfigResult.ok;
    } catch (_) {
      // Network/RPC failure: fail open. Don't block users on a transient error.
      return AppConfigResult.ok;
    }
  }

  // Returns true iff `current` < `minimum` using dotted-numeric comparison.
  // Non-numeric segments are treated as 0.
  static bool _isBelow(String current, String minimum) {
    final a = _parts(current);
    final b = _parts(minimum);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x < y) return true;
      if (x > y) return false;
    }
    return false;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
}
