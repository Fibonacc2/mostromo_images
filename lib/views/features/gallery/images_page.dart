// lib/views/features/gallery/images_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 YENİDEN EKLENDİ
import 'package:go_router/go_router.dart';
import 'package:mostromo_images/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/data/notifiers.dart';
import 'package:shared_core/services/api_service.dart';
import 'package:shared_core/models/media_group.dart';
import 'package:shared_core/models/media_item.dart';

class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  bool _initialLoadDone = false;

  // Sayfalama (Pagination) Kontrolleri
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Liste sonuna gelindiğini dinleyen sistem
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() async {
    if (_initialLoadDone || isLoadingMediaNotifier.value) return;

    try {
      if (cachedMediaGroupsNotifier.value == null) {
        _currentPage = 1;
        _hasMoreData = true;
        final userId = context.read<AuthViewModel>().userId ?? 0;
        await ApiService.fetchAndCacheGroupedMedia(
          userId: userId,
          page: _currentPage,
          loadMore: false,
        );

        if (mounted) {
          setState(() {
            _initialLoadDone = true;
          });
        }
      }
    } catch (error) {
      debugPrint('Initial data loading error: $error');
    }
  }

  Future<void> _loadMoreData() async {
    if (isLoadingMediaNotifier.value || !_hasMoreData) return;

    _currentPage++;
    try {
      final beforeCount = _getMediaCount();
      final userId = context.read<AuthViewModel>().userId ?? 0;
      await ApiService.fetchAndCacheGroupedMedia(
        userId: userId,
        page: _currentPage,
        loadMore: true,
      );
      final afterCount = _getMediaCount();

      if (beforeCount == afterCount && mounted) {
        setState(() => _hasMoreData = false);
      }
    } catch (error) {
      debugPrint('Load more error: $error');
      _currentPage--;
    }
  }

  int _getMediaCount() {
    if (cachedMediaGroupsNotifier.value == null) return 0;
    return cachedMediaGroupsNotifier.value!.expand((g) => g.items).length;
  }

  Future<void> _handleRefresh() async {
    try {
      _currentPage = 1;
      _hasMoreData = true;
      final userId = context.read<AuthViewModel>().userId ?? 0;
      await ApiService.fetchAndCacheGroupedMedia(
        userId: userId,
        page: _currentPage,
        loadMore: false,
      );
    } catch (error) {
      debugPrint('Refresh error: $error');
    }
  }

  void _openImageDetail(List<MediaItem> allItems, int index) {
    selectedImageNotifier.value = allItems[index];

    context.push(
      '/view_image',
      extra: {'items': allItems, 'initialIndex': index},
    );
  }

  void _openUploadPage() {
    context.push('/upload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _openUploadPage,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ValueListenableBuilder<List<MediaGroup>?>(
      valueListenable: cachedMediaGroupsNotifier,
      builder: (context, groups, child) {
        if (groups == null && isLoadingMediaNotifier.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groups == null || groups.isEmpty) {
          return const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: Center(child: Text("Hiç medya bulunamadı")),
              ),
            ],
          );
        }

        final List<MediaItem> allItems = groups
            .expand((group) => group.items)
            .toList();
        int itemOffset = 0;

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ...groups.expand((group) {
              final currentOffset = itemOffset;
              itemOffset += group.items.length;

              return [
                SliverToBoxAdapter(
                  key: PageStorageKey<String>('header_${group.date}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 32, 12, 8),
                    child: Text(
                      group.date,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = group.items[index];
                    final globalIndex = currentOffset + index;
                    return _buildMediaItem(item, allItems, globalIndex);
                  }, childCount: group.items.length),
                ),
              ];
            }),

            if (_hasMoreData)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _buildMediaItem(
    MediaItem item,
    List<MediaItem> allItems,
    int globalIndex,
  ) {
    if (item.fileType == "media/img") {
      final String? rawUrl =
          item.imageWebpMini ?? item.imageWebp ?? item.imageURL;
      // 🌟 YENİ: URL Şifreleme eklendi
      final String? imageUrl = rawUrl != null ? Uri.encodeFull(rawUrl) : null;

      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => _openImageDetail(allItems, globalIndex),
            // 🌟 ORİJİNAL KODUNA DÖNÜLDÜ: RAM tüketimini "memCacheWidth" ile kontrol altında tutuyoruz
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const _PlaceholderWidget()
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    placeholder: (context, url) => const _PlaceholderWidget(),
                    errorWidget: (context, url, error) =>
                        const _PlaceholderWidget(icon: Icons.broken_image),
                  ),
          ),
        ),
      );
    } else if (item.fileType == "media/vid") {
      final String? posterUrl = item.videoPoster != null
          ? Uri.encodeFull(item.videoPoster!)
          : null;

      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: GestureDetector(
          onTap: () => _openImageDetail(allItems, globalIndex),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: posterUrl != null && posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (context, url) =>
                            const _VideoPlaceholder(),
                        errorWidget: (context, url, error) =>
                            const _VideoPlaceholder(),
                      )
                    : const _VideoPlaceholder(),
              ),
              const Icon(
                Icons.play_circle_fill,
                size: 36,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// --- YARDIMCI WIDGET'LAR ---

class _PlaceholderWidget extends StatelessWidget {
  final IconData icon;
  const _PlaceholderWidget({this.icon = Icons.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Icon(icon, size: 24, color: Colors.grey),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Icon(Icons.play_arrow, size: 24, color: Colors.white54),
    );
  }
}
