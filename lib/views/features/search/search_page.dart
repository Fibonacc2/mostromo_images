// apps/mostromo_images/lib/features/search/search_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Arama"),
        actions: [
          IconButton(
            onPressed: () => openSettingsPage(),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(child: Text("Arama Sayfası")),
    );
  }

  // ✅ GÜNCELLENDİ: Rota '/settings_page' değil, '/search/settings' oldu
  void openSettingsPage() {
    context.push('/settings');
  }
}
