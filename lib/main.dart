import 'package:flutter/material.dart';
import 'package:mostromo_images/app_router.dart'; // 2. Aşamada oluşturduğumuz router
import 'package:shared_core/data/notifiers.dart'; // shared_core'dan
import 'package:common_ui/data/themes.dart'; // common_ui'den

// Gerekli olabilecek importlar (eski main.dart'tan)
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_downloader/flutter_downloader.dart'; // Eğer galeri indirmesi de bunu kullanıyorsa

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Downloader (gerekliyse)
  // await FlutterDownloader.initialize(debug: true);

  // Tema (common_ui'den)
  await loadSelectedTheme();
  initThemeListener();

  // MultiProvider'a ŞİMDİLİK gerek yok, çünkü StorageViewModel
  // bu uygulamada kullanılmıyor. Galeri 'ValueNotifier' kullanıyor.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTheme,
      builder: (context, themeId, _) {
        final theme = appThemes[themeId.clamp(0, appThemes.length - 1)].data;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,

          // 2. Aşamada oluşturduğumuz router'ı buraya veriyoruz
          routerConfig: AppRouter().router,

          // Türkçe yerelleştirme (eski main.dart'tan)
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr', ''), Locale('en', '')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
