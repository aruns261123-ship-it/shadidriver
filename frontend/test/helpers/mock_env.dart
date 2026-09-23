import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/core/config/env_config.dart';

/// Overrides the environment to MOCK mode for tests that exercise mock
/// repositories (the production default is real-API mode). Tests of the API
/// repositories themselves do NOT use this — they assert real-mode wiring.
List<Override> mockModeOverrides() => [
      environmentConfigProvider.overrideWith(
        (ref) => EnvironmentConfig.development(useMockData: true),
      ),
];
