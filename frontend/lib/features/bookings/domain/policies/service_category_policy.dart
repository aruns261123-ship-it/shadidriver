/// Maps the customer's chosen ceremony onto a seeded service category.
///
/// This is a domain rule (it decides what the customer is buying), not a wire
/// detail, so it lives with the domain and is used by the API repository when
/// it builds the request DTO.
abstract final class ServiceCategoryPolicy {
  static const String baraat = 'SVC_BARAAT';
  static const String vidai = 'SVC_VIDAI';
  static const String reception = 'SVC_RECEPTION';
  static const String airportVip = 'SVC_AIRPORT_VIP';

  static String forCeremony(String ceremonyType) {
    final normalized = ceremonyType.toUpperCase();
    if (normalized.contains('AIRPORT') || normalized.contains('VIP')) {
      return airportVip;
    }
    if (normalized.contains('RECEPTION') ||
        normalized.contains('ENGAGEMENT')) {
      return reception;
    }
    if (normalized.contains('VIDAI')) return vidai;
    return baraat;
  }
}
