import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/shadi_scroll_behavior.dart';
import 'providers/app_providers.dart';

/// Root application widget for ShadiDriver.
class ShadiDriverApp extends ConsumerWidget {
  const ShadiDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      scrollBehavior: const ShadiScrollBehavior(),
      builder: (context, child) => ScrollConfiguration(
        behavior: const ShadiScrollBehavior(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
