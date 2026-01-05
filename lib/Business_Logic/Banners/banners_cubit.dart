import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Banners/banners_state.dart';
import 'package:docsera/services/supabase/banners/supabase_banner_service.dart';

class BannersCubit extends Cubit<BannersState> {
  final SupabaseBannerService _bannerService;

  BannersCubit(this._bannerService) : super(BannersInitial());

  Future<void> loadBanners() async {
    emit(BannersLoading());
    try {
      final banners = await _bannerService.getActiveBanners();
      emit(BannersLoaded(banners));
    } catch (e) {
      emit(BannersError("Failed to load banners: $e"));
    }
  }
}
