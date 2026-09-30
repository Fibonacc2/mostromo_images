// lib/main.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🌟 YENİ
import 'package:window_manager/window_manager.dart';

import 'package:mostromo_images/app_router.dart';
import 'package:shared_core/data/notifiers.dart';
import 'package:common_ui/data/themes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mostromo_images/views/features/mostromo_title_bar.dart';
import 'package:mostromo_images/auth_view_model.dart'; // 🌟 YENİ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "Mostromo Images",
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await loadSelectedTheme();
  initThemeListener();

  // 🌟 YENİ: MultiProvider ile Auth ViewModel'i en tepeye sardık
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthViewModel())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 YENİ: Auth durumu okunana kadar boş/yükleniyor ekranı göster
    final authVM = context.watch<AuthViewModel>();
    if (authVM.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: selectedTheme,
      builder: (context, themeId, _) {
        final theme = appThemes[themeId.clamp(0, appThemes.length - 1)].data;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Mostromo Images',
          theme: theme,
          // 🌟 YENİ: Router'a artık Auth modelini de veriyoruz ki durumu dinleyebilsin
          routerConfig: AppRouter(authVM).router,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr', ''), Locale('en', '')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final bool isDesktop =
                !kIsWeb &&
                (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
            if (isDesktop) {
              return Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    MostromoTitleBar(
                      title: 'Mostromo Images',
                      onClose: () => windowManager.close(),
                    ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              );
            }
            return child!;
          },
        );
      },
    );
  }
}
