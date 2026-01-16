import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/models/popup_banner_model.dart';
import 'package:docsera/services/supabase/popups/supabase_popup_service.dart';
import 'popup_banner_state.dart';

class PopupBannerCubit extends Cubit<PopupBannerState> {
  final SupabasePopupService _service;
  final SharedPreferences _prefs;

  PopupBannerCubit(this._service, this._prefs) : super(PopupBannerInitial());

  List<PopupBannerModel> _allBanners = [];
  int _currentIndex = 0;

  Future<void> checkBanners() async {
    final dismissedIds = _prefs.getStringList('dismissed_banners') ?? [];
    final banners = await _service.getActiveBanners();

    _allBanners = banners.where((b) {
      if (!b.showOnce) return true; // Always show if showOnce is false
      return !dismissedIds.contains(b.id);
    }).toList();

    _currentIndex = 0;
    _showNextBanner();
  }

  void _showNextBanner() {
    if (_currentIndex < _allBanners.length) {
      emit(PopupBannerVisible(_allBanners[_currentIndex]));
    } else {
      emit(PopupBannerHidden());
    }
  }

  Future<void> dismissCurrentBanner() async {
    if (state is PopupBannerVisible) {
      final banner = (state as PopupBannerVisible).banner;
      
      if (banner.showOnce) {
        final dismissedIds = _prefs.getStringList('dismissed_banners') ?? [];
        if (!dismissedIds.contains(banner.id)) {
          dismissedIds.add(banner.id);
          await _prefs.setStringList('dismissed_banners', dismissedIds);
        }
      }
      
      _currentIndex++;
      _showNextBanner();
    }
  }
}
