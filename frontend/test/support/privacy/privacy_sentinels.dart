import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/theme/app_theme.dart';

/// Sentinel values for the customer presentation-layer privacy harness.
///
/// Every value below is unmistakable, unrealistic and can only exist in a
/// fixture — so if one ever appears in a rendered customer surface, the leak
/// is proven, not inferred. Fixtures deliberately inject these into the
/// private/legacy fields (chauffeur identity, partner identity, registration
/// plates, internal notes) so the tests prove the PRESENTATION layer filters
/// them, rather than merely omitting them from the data.
abstract final class PrivacySentinels {
  static const driverName = 'PRIVATE_DRIVER_SHOULD_NOT_RENDER';
  static const driverPhone = '+910000000000';
  static const driverEmail = 'private-driver@example.invalid';
  static const driverAddress = 'PRIVATE_DRIVER_ADDRESS';
  static const driverId = 'PRIVATE_DRIVER_ID';
  static const internalNote = 'PRIVATE_INTERNAL_NOTE';
  static const partnerName = 'PRIVATE_PARTNER_NAME';
  static const registrationPlate = 'PRIVATE_REGISTRATION_PLATE';
  static const internalKey = 'PRIVATE_INTERNAL_KEY';

  /// Every sentinel, in reporting order.
  static const all = <String>[
    driverName,
    driverPhone,
    driverEmail,
    driverAddress,
    driverId,
    internalNote,
    partnerName,
    registrationPlate,
    internalKey,
  ];

  /// A single matcher over all sentinels (used by `find.textContaining` style
  /// checks and by failure messages).
  static final RegExp pattern = RegExp(all.map(RegExp.escape).join('|'));

  /// True when [value] carries any sentinel. Fixtures assert on this so a
  /// silently emptied fixture can never make a privacy test pass vacuously.
  static bool isPresentIn(Object? value) {
    if (value == null) return false;
    return pattern.hasMatch(value.toString());
  }
}

/// A fixed rendering environment for privacy tests.
///
/// Deliberately pinned so the same surface renders identically on any machine:
/// locale, text scale, device pixel ratio and logical viewport. Nothing here
/// depends on the network, the database or the wall clock.
class PrivacyRenderEnvironment {
  static const logicalSize = Size(390, 844); // phone reference surface
  static const devicePixelRatio = 3.0;
  static const textScaleFactor = 1.0;
  static const locale = Locale('en', 'US');

  /// Applies the fixed environment and restores the tester afterwards.
  static void apply(WidgetTester tester) {
    tester.view.physicalSize =
        logicalSize * devicePixelRatio;
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
}

/// Loads the SHIPPED variable fonts so rendered text uses the real ShadiDriver
/// typography instead of the flutter_test marker font (which is much wider and
/// would distort both layout and goldens).
///
/// Call this from `setUpAll` — outside the fake-async test zone — so the asset
/// bundle can be read from disk.
Future<void> loadShadiFonts() async {
  if (_fontsLoaded) return;
  const families = <String, String>{
    'Playfair Display': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
    'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-VariableFont.ttf',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
  _fontsLoaded = true;
}

bool _fontsLoaded = false;

/// Pumps [surface] inside the app's real theme under the fixed environment.
///
/// The surface is wrapped in a [RepaintBoundary] so golden capture is stable
/// and explicit, and in a [Scaffold] because several customer surfaces are
/// bare content widgets that expect a Material ancestor.
Future<void> pumpPrivacySurface(
  WidgetTester tester,
  Widget surface, {
  List<Override> overrides = const [],
  bool settle = true,
  bool decodeImages = false,
  Key boundaryKey = const Key('privacy_surface'),
}) async {
  PrivacyRenderEnvironment.apply(tester);
  final tree = ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: PrivacyRenderEnvironment.locale,
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
          body: surface,
        ),
      ),
    ),
  );

  if (decodeImages) {
    // Bundled photos decode on a real event loop; the fake-async test zone
    // would leave every image as an empty box in the golden. `runAsync` lets
    // the codec finish, then the tree is pumped back in test time.
    await tester.runAsync(() async {
      await tester.pumpWidget(tree);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
    return;
  }

  await tester.pumpWidget(tree);
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Every human-readable string the CURRENT rendered tree can present.
///
/// This is intentionally broader than "all `Text` widgets": a value can leak
/// through a rich text span, a tooltip, an editable field's decoration, a
/// widget-level `Semantics` label, or the compiled accessibility tree (which
/// merges and rewrites labels). All of them are covered here.
Iterable<String> presentedStrings(WidgetTester tester) sync* {
  for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data != null && data.isNotEmpty) yield data;
    final span = text.textSpan;
    if (span != null) {
      final plain = span.toPlainText();
      if (plain.isNotEmpty) yield plain;
    }
  }

  for (final RichText rich
      in tester.widgetList<RichText>(find.byType(RichText))) {
    final plain = rich.text.toPlainText();
    if (plain.isNotEmpty) yield plain;
  }

  for (final Tooltip tooltip
      in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    final message = tooltip.message;
    if (message != null && message.isNotEmpty) yield message;
  }

  for (final EditableText field
      in tester.widgetList<EditableText>(find.byType(EditableText))) {
    final value = field.controller.text;
    if (value.isNotEmpty) yield value;
  }

  for (final Semantics semantics
      in tester.widgetList<Semantics>(find.byType(Semantics))) {
    final properties = semantics.properties;
    for (final candidate in <String?>[
      properties.label,
      properties.value,
      properties.hint,
      properties.tooltip,
      properties.attributedLabel?.string,
      properties.attributedValue?.string,
      properties.attributedHint?.string,
    ]) {
      if (candidate != null && candidate.isNotEmpty) yield candidate;
    }
  }

  yield* semanticsTreeStrings(tester);
}

/// Labels published to the accessibility tree, walked from the root.
///
/// A value that is visually hidden but announced to a screen reader is still a
/// leak, so the accessibility tree gets its own assertion path.
Iterable<String> semanticsTreeStrings(WidgetTester tester) sync* {
  final views = tester.binding.renderViews;
  if (views.isEmpty) return;
  final root = views.first.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) return;

  final queue = <SemanticsNode>[root];
  while (queue.isNotEmpty) {
    final node = queue.removeLast();
    final data = node.getSemanticsData();
    for (final candidate in <String>[
      data.label,
      data.value,
      data.hint,
      data.tooltip,
      data.attributedLabel.string,
      data.attributedValue.string,
      data.attributedHint.string,
    ]) {
      if (candidate.isNotEmpty) yield candidate;
    }
    node.visitChildren((child) {
      queue.add(child);
      return true;
    });
  }
}

/// Fails when ANY private sentinel is present anywhere the customer could read
/// it — in the widget tree, in a tooltip, or in the accessibility tree.
void expectNoPrivateSentinels(
  WidgetTester tester, {
  String? surface,
  String? reason,
}) {
  final leaks = <String>[];
  for (final presented in presentedStrings(tester)) {
    for (final sentinel in PrivacySentinels.all) {
      if (presented.contains(sentinel)) {
        leaks.add('"$sentinel" in "$presented"');
      }
    }
  }
  expect(
    leaks,
    isEmpty,
    reason:
        '${surface ?? 'The customer surface'} exposed private data: '
        '${leaks.join(' | ')}${reason == null ? '' : ' — $reason'}',
  );
}

/// The single string a surface presents, for readable failure output.
String presentedText(WidgetTester tester) =>
    presentedStrings(tester).join(' \u23ce ');
