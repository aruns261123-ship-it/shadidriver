import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/providers/app_providers.dart';
import 'core/theme/shadi_imagery.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      // Resolve server-relative media URLs (e.g. `/media/vehicles/...jpg`)
      // against the API origin so real backend photography loads in-app.
      const envBaseUrl = String.fromEnvironment('SHADI_API_BASE_URL');
      ShadiImagery.configureMediaOrigin(
        envBaseUrl.isNotEmpty ? envBaseUrl : defaultDevApiBaseUrl(),
      );
      runApp(const ProviderScope(child: ShadiDriverApp()));
    },
    (error, stackTrace) {
      // Global uncaught error handler for production crash reporting
      debugPrint('[ShadiDriver Uncaught Error]: $error\n$stackTrace');
    },
  );
}
