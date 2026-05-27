// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:chuphinh/routes/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_idle_detector.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('vi');

  @override
  void initState() {
    super.initState();
    checkWebVersionAndReload();
  }

  ////////////////////////////////////////////////////////////
  /// CHANGE LANGUAGE
  ////////////////////////////////////////////////////////////
  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  ////////////////////////////////////////////////////////////
  /// AUTO RELOAD WHEN NEW VERSION
  ////////////////////////////////////////////////////////////
  void checkWebVersionAndReload() {
    if (!kIsWeb) return;

    final meta = html.document.querySelector('meta[name="app-version"]');

    final v = meta?.getAttribute('content') ?? '';

    const key = 'last_app_version';

    final last = html.window.localStorage[key] ?? '';

    if (last.isNotEmpty && last != v) {
      html.window.localStorage[key] = v;

      ////////////////////////////////////////////////////////////
      /// RELOAD WHEN VERSION CHANGED
      ////////////////////////////////////////////////////////////
      html.window.location.reload();

      return;
    }

    html.window.localStorage[key] = v;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'S-Patrol',
      routerConfig: router,
      locale: _locale,
      supportedLocales: const [Locale('vi'), Locale('en'), Locale('ja')],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;

        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }

        return supportedLocales.first;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansTextTheme(Theme.of(context).textTheme),
      ),
      builder: (context, child) {
        return AppIdleDetector(child: child ?? const SizedBox());
      },
    );
  }
}
