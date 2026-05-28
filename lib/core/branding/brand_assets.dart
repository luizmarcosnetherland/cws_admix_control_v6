import 'package:flutter/widgets.dart';

const kNetherlandLogoAsset = 'assets/logos/netherland.png';
const kCwsAdmixLogoAsset = 'assets/logos/cwsadmix.jpg';
const kCwsWaterproofingLogoAsset = 'assets/logos/cws_waterproofing_systems.jpg';

bool isPtBrLocale(Locale locale) {
  return locale.languageCode.toLowerCase() == 'pt' &&
      locale.countryCode?.toUpperCase() == 'BR';
}

String companyLogoAssetForLocale(Locale locale) {
  return isPtBrLocale(locale)
      ? kNetherlandLogoAsset
      : kCwsWaterproofingLogoAsset;
}

String companyLogoAssetForDeviceLocale() {
  return companyLogoAssetForLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
}
