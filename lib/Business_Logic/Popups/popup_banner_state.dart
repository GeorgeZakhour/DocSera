import 'package:docsera/models/popup_banner_model.dart';

abstract class PopupBannerState {}

class PopupBannerInitial extends PopupBannerState {}

class PopupBannerVisible extends PopupBannerState {
  final PopupBannerModel banner;
  PopupBannerVisible(this.banner);
}

class PopupBannerHidden extends PopupBannerState {}
