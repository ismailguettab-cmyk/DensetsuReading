import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/motion.dart';
import 'core/services.dart';
import 'core/theme.dart';
import 'ui/login_page.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw under the status and navigation bars (transparent): no black band at the bottom.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));
  await Services.init();
  runApp(const DensetsuApp());
}

class DensetsuApp extends StatelessWidget {
  const DensetsuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.i;
    return ListenableBuilder(
      listenable: Listenable.merge([s.settings, s.session]),
      builder: (context, _) => MaterialApp(
        title: 'Densetsu',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Palette.light, Brightness.light),
        darkTheme: buildTheme(Palette.dark, Brightness.dark),
        themeMode: s.settings.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 320),
        locale: Locale(s.settings.language),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        scrollBehavior: const _AppScroll(),
        home: AnimatedSwitcher(
          duration: Motion.enter,
          switchInCurve: Motion.easeOut,
          child: s.session.hasCredentials ? const Shell(key: ValueKey('shell')) : const LoginPage(key: ValueKey('login')),
        ),
      ),
    );
  }
}

/// Lets a mouse drag pages and lists too (the web preview has no touch).
class _AppScroll extends MaterialScrollBehavior {
  const _AppScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
