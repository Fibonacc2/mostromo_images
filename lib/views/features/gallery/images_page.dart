// apps/mostromo_images/lib/features/gallery/images_page.dart

import 'package:common_ui/views/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/data/notifiers.dart';
import 'package:common_ui/common_ui.dart'; // Ortak UI paketi
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  /// Uygulama ilk açıldığında verileri yükler
  void _loadInitialData() async {
    if (_isLoading || _initialLoadDone) return;

    _isLoading = true;
    try {
      if (cachedMediaGroupsNotifier.value == null) {
        await ApiService.fetchAndCacheGroupedMedia();
        if (mounted) {
          setState(() {
            _initialLoadDone = true;
          });
        }
      }
    } catch (error) {
      debugPrint('Initial data loading error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Aşağı çekince tetiklenen yenileme fonksiyonu
  Future<void> _handleRefresh() async {
    try {
      await ApiService.fetchAndCacheGroupedMedia();
    } catch (error) {
      debugPrint('Refresh error: $error');
    }
  }

  /// Detay sayfasına yönlendirme
  void _openImageDetail(List<MediaItem> allItems, int index) {
    selectedImageNotifier.value = allItems[index];

    context.push(
      '/view_image',
      extra: {'items': allItems, 'initialIndex': index},
    );
  }

  /// Yükleme sayfasına yönlendirme
  void _openUploadPage() {
    context.push('/upload');
  }

  @override
  Widget build(BuildContext context) {
    return MostromoScaffold(
      onRefresh: _handleRefresh, // Yenileme desteği
      floatingActionButton: FloatingActionButton(
        onPressed: _openUploadPage,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return ValueListenableBuilder<List<MediaGroup>?>(
      valueListenable: cachedMediaGroupsNotifier,
      builder: (context, groups, child) {
        if (groups == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: Text("Hiç medya bulunamadı"),
            ),
          );
        }

        // Tüm gruplardaki medyaları tek bir listede topla (Detay sayfasında kaydırmak için)
        final List<MediaItem> allItems = groups
            .expand((group) => group.items)
            .toList();

        int itemOffset = 0;

        return Column(
          children: groups.map((group) {
            final currentOffset = itemOffset;
            itemOffset += group.items.length;
            return _buildMediaGroup(group, allItems, currentOffset);
          }).toList(),
        );
      },
    );
  }

  Widget _buildMediaGroup(
    MediaGroup group,
    List<MediaItem> allItems,
    int itemOffset,
  ) {
    return Column(
      key: PageStorageKey<String>(group.date),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarih Başlığı
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 8),
          child: Text(
            group.date,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Medya Izgarası
        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // Scroll kontrolü MostromoScaffold'da
          itemCount: group.items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final item = group.items[index];
            final globalIndex = itemOffset + index;
            return _buildMediaItem(item, allItems, globalIndex);
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMediaItem(
    MediaItem item,
    List<MediaItem> allItems,
    int globalIndex,
  ) {
    // RESİM ÖĞESİ
    if (item.fileType == "media/img") {
      final String? imageUrl =
          item.imageWebpMini ?? item.imageWebp ?? item.imageURL;

      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => _openImageDetail(allItems, globalIndex),
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
    }
    // VİDEO ÖĞESİ
    else if (item.fileType == "media/vid") {
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: GestureDetector(
          onTap: () => _openImageDetail(allItems, globalIndex),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.videoPoster != null && item.videoPoster!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.videoPoster!,
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
