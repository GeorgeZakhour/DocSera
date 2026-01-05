import 'package:docsera/models/banner_model.dart';

abstract class BannersState {}

class BannersInitial extends BannersState {}

class BannersLoading extends BannersState {}

class BannersLoaded extends BannersState {
  final List<BannerModel> banners;

  BannersLoaded(this.banners);
}

class BannersError extends BannersState {
  final String message;

  BannersError(this.message);
}
