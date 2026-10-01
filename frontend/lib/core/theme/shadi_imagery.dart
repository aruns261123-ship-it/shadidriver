import 'package:flutter/material.dart';

/// Central imagery resolver for the reference design's photography.
///
/// The Figma reference uses premium vehicle photography; production Flutter
/// assets must not depend on random remote URLs, so the reference imagery is
/// bundled under `assets/images/`. Vehicle cards, headers, and category tiles
/// render REAL backend photos when the API supplies them
/// ([ShadiImagery.network]) and fall back to the bundled reference treatment
/// when a vehicle has no photo — a placeholder is never a plain gradient.
abstract final class ShadiImagery {
  /// Bundled reference photography.
  static const String heroAsset = 'assets/images/hero_fleet.jpg';
  static const String streetAsset = 'assets/images/street_fleet.jpg';

  /// Hero / detail-header / first-card imagery: dark luxury vehicle, exactly
  /// the reference's hero photo.
  static const String primary = heroAsset;

  /// Secondary imagery: street fleet, the reference's second photo.
  static const String secondary = streetAsset;

  /// The hero scrim the reference layers over its photography.
  /// `linear-gradient(180deg, rgba(25,8,10,.05), rgba(25,8,10,.82))`.
  static const LinearGradient heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0D190810), Color(0xD1190810)],
  );

  /// The category-tile scrim:
  /// `linear-gradient(180deg, transparent, rgba(35,9,13,.75))`.
  static const LinearGradient categoryScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0023090D), Color(0xBF23090D)],
  );

  /// Origin of the backend serving `/media/...` photos (e.g.
  /// `http://10.0.2.2:3000` on the Android emulator). Configured once at
  /// bootstrap from the environment so server-relative image URLs returned
  /// by the API resolve to loadable absolute URLs.
  static String mediaOrigin = '';

  /// Configures [mediaOrigin] from an API base URL such as
  /// `http://10.0.2.2:3000/api/v1` → `http://10.0.2.2:3000`.
  static void configureMediaOrigin(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri != null && uri.scheme.startsWith('http') && uri.host.isNotEmpty) {
      mediaOrigin = '${uri.scheme}://${uri.host}${uri.port == 0 ? '' : ':${uri.port}'}';
    }
  }

  /// Picks imagery for a vehicle with a real photo: [network] when the
  /// backend supplies a URL (absolute http(s) or server-relative `/media/...`),
  /// [primary]/[secondary] alternating when it does not — so lists still
  /// carry the reference's photographic impact.
  static String forVehicle(String? imageUrl, {required String vehicleId}) {
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty && url.startsWith('http')) return url;
    if (url.isNotEmpty && url.startsWith('/') && mediaOrigin.isNotEmpty) {
      return '$mediaOrigin$url';
    }
    // Deterministic alternation keeps rails varied like the reference.
    return vehicleId.hashCode.isEven ? primary : secondary;
  }

  /// True when [source] is a bundled asset (no network → no fade needed).
  static bool isAsset(String source) => source.startsWith('assets/');
}
