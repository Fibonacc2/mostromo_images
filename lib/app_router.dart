// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_core/models/media_item.dart';
import 'package:common_ui/views/widgets/navbar_widget.dart';

import 'package:mostromo_images/views/features/gallery/images_page.dart';
import 'package:mostromo_images/views/features/gallery/view_image.dart';
import 'package:mostromo_images/views/features/gallery/upload_page.dart';
import 'package:mostromo_images/views/features/search/search_page.dart';
import 'package:mostromo_images/views/features/search/settings_page.dart';

import 'package:mostromo_images/views/features/auth/login_page.dart'; // 🌟 YENİ
import 'package:mostromo_images/auth_view_model.dart'; // 🌟 YENİ

class AppRouter {
  late final GoRouter router;
  static const MethodChannel _platform = MethodChannel('mostromo_images/share');

  final AuthViewModel authViewModel; // 🌟 YENİ

  AppRouter(this.authViewModel) {
    router = GoRouter(
      initialLocation: '/',
      refreshListenable:
          authViewModel, // 🌟 YENİ: Kullanıcı giriş/çıkış yaptığında rotaları tekrar tetikler
      redirect: _handleRedirect,
      routes: [
        // 🌟 YENİ: Login Rotası
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationWrapper(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ImagesPage(),
                ),
              ],
            ),
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

    _setupPlatformChannel();
  }

  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final bool isLoggedIn = authViewModel.isLoggedIn;
    final bool isLoginRoute = state.uri.path == '/login';

    // 🌟 YENİ: KULLANICI GİRİŞ YAPMADIYSA ZORLA LOGİN SAYFASINA AT
    if (!isLoggedIn) {
      return isLoginRoute ? null : '/login';
    }

    // 🌟 YENİ: GİRİŞ YAPMIŞ KULLANICI LOGİN SAYFASINA GİDEMEZ
    if (isLoginRoute) {
      return '/';
    }

    if (state.uri.path == '/upload') return null;

    final hasShare = await _checkPendingShare();
    if (hasShare) {
      return '/upload';
    }
    return null;
  }

  Future<bool> _checkPendingShare() async {
    try {
      final bool? hasShare = await _platform.invokeMethod('hasPendingShare');
      return hasShare ?? false;
    } on PlatformException {
      return false;
    }
  }

  void _setupPlatformChannel() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == "navigateToUpload" && authViewModel.isLoggedIn) {
        router.go('/upload');
      }
      return null;
    });
  }
}

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
