import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:asko_pdf/pages/pdf_viewer_page.dart';
import 'package:asko_pdf/services/settings_service.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/services/custom_language.dart';
import 'package:asko_pdf/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().loadSavedLocale();

  runApp(const MyApp());

  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(1280, 720);
    win.minSize = const Size(800, 600);
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "AskoPDF";
    win.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    final colorScheme = ColorScheme.fromSwatch(
      primarySwatch: AppColors.primarySwatch,
    ).copyWith(secondary: AppColors.primaryBlueSoft);

    return ValueListenableBuilder<int>(
      valueListenable: CustomLanguage.instance.revision,
      builder: (context, translationRevision, _) =>
          ValueListenableBuilder<Locale>(
      valueListenable: SettingsService.localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'AskoPDF',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('en'), CustomLanguage.locale],
          localizationsDelegates: [
            AppLocalizations.delegateFor(translationRevision),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            primarySwatch: AppColors.primarySwatch,
            colorScheme: colorScheme,
            primaryColor: AppColors.primaryBlue,
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppColors.primaryBlue,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primaryBlue;
                }
                return null;
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primaryBlueSoft.withValues(alpha: 0.5);
                }
                return null;
              }),
            ),
            checkboxTheme: CheckboxThemeData(
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primaryBlue;
                }
                return null;
              }),
            ),
            radioTheme: RadioThemeData(
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primaryBlue;
                }
                return null;
              }),
            ),
            scaffoldBackgroundColor: const Color(0xFFE0E0E0),
            textTheme: textTheme,
            primaryTextTheme: textTheme,
          ),
          home: const PdfViewerPage(),
        );
      },
    ),
    );
  }
}
