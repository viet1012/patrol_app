// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:chuphinh/routes/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Camera App',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const CameraScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }
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

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void checkWebVersionAndReload() {
    if (!kIsWeb) return;
    final meta = html.document.querySelector('meta[name="app-version"]');
    final v = meta?.getAttribute('content') ?? '';
    final key = 'last_app_version';

    final last = html.window.localStorage[key] ?? '';
    if (last.isNotEmpty && last != v) {
      html.window.localStorage[key] = v;
      html.window.location.reload(); // tự reload khi có bản mới
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
        for (var supportedLocale in supportedLocales) {
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
      // home: const LoginPage(),
      // home: const PatrolReportTable(),
    );
  }
}
