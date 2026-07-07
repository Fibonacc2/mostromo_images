// apps/mostromo_images/lib/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // MethodChannel için
import 'package:go_router/go_router.dart';

// Paketlerden gelen importlar
import 'package:shared_core/models/media_item.dart';
import 'package:common_ui/views/widgets/navbar_widget.dart';

// Sayfalar
import 'package:mostromo_images/views/features/gallery/images_page.dart';
import 'package:mostromo_images/views/features/gallery/view_image.dart';
import 'package:mostromo_images/views/features/gallery/upload_page.dart';
import 'package:mostromo_images/views/features/search/search_page.dart';
import 'package:mostromo_images/views/features/search/settings_page.dart';

class AppRouter {
  // Router nesnesi
  late final GoRouter router;

  // ✅ NATIVE KANAL: Android ile konuşmak için
  static const MethodChannel _platform = MethodChannel('mostromo_images/share');

  AppRouter() {
    router = GoRouter(
      initialLocation: '/',

      // ✅ 1. YÖNLENDİRME MANTIĞI (Açılışta Paylaşım Var mı?)
      redirect: _handleRedirect,

      routes: [
        // --- 1. GRUP: TAB BAR GÖRÜNEN SAYFALAR ---
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationWrapper(navigationShell: navigationShell);
          },
          branches: [
            // 1. Sekme: Galeri
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ImagesPage(),
                ),
              ],
            ),
            // 2. Sekme: Arama
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchPage(),
                ),
              ],
            ),
          ],
        ),

        // --- 2. GRUP: TAM EKRAN SAYFALAR ---
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadPage(),
        ),

        GoRoute(
          path: '/view_image',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>?;
            if (args == null ||
                !args.containsKey('items') ||
                !args.containsKey('initialIndex')) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: Text('Medya bilgisi eksik.')),
              );
            }
            return ViewImagePage(
              items: args['items'] as List<MediaItem>,
              initialIndex: args['initialIndex'] as int,
            );
          },
        ),

        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    // ✅ 2. DİNLEYİCİYİ BAŞLAT (Uygulama çalışırken paylaşım gelirse)
    _setupPlatformChannel();
  }

  // --- YARDIMCI FONKSİYONLAR ---

  // Uygulama açılırken çalışır
  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    // Zaten upload sayfasındaysak tekrar kontrol etme
    if (state.uri.path == '/upload') return null;

    // Native tarafa sor: "Paylaşılmış bir dosya var mı?"
    final hasShare = await _checkPendingShare();

    if (hasShare) {
      // Varsa direkt upload sayfasına yönlendir
      return '/upload';
    }
    return null; // Yoksa normal akışa devam et
  }

  // Native tarafa (Kotlin/Java) sorar
  Future<bool> _checkPendingShare() async {
    try {
      final bool? hasShare = await _platform.invokeMethod('hasPendingShare');
      return hasShare ?? false;
    } on PlatformException {
      return false;
    }
  }

  // Native taraftan gelen sinyalleri dinler (App arkadayken paylaşım gelirse)
  void _setupPlatformChannel() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == "navigateToUpload") {
        // Native kod "Hadi Upload sayfasına git" dediğinde:
        router.go('/upload');
      }
      return null;
    });
  }
}

// --- NAVBAR WRAPPER (Değişmedi) ---
class MainNavigationWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationWrapper({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavbarWidget(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
      ),
    );
  }
}
