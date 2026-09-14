import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const ProviderScope(child: ShadiDriverApp()));
    },
    (error, stackTrace) {
      // Global uncaught error handler for production crash reporting
      debugPrint('[ShadiDriver Uncaught Error]: $error\n$stackTrace');
    },
  );
}
