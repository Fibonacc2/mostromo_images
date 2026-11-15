import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:mostromo_images/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/data/notifiers.dart';
import 'package:shared_core/services/api_service.dart';
import 'package:shared_core/models/media_group.dart';
import 'package:shared_core/models/media_item.dart';

enum _GalleryFilter { all, photos, videos }

class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _initialLoadDone = false;
  _GalleryFilter _filter = _GalleryFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 360) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted || _initialLoadDone) return;
    if (cachedMediaGroupsNotifier.value != null) {
      setState(() => _initialLoadDone = true);
      return;
    }
    if (isLoadingMediaNotifier.value) return;

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
      debugPrint('Initial gallery load error: $error');
    } finally {
      if (mounted) setState(() => _initialLoadDone = true);
    }
  }

  Future<void> _loadMoreData() async {
    if (!mounted ||
        !_initialLoadDone ||
        isLoadingMediaNotifier.value ||
        !_hasMoreData) {
      return;
    }

    _currentPage++;
    try {
      final beforeCount = _getMediaCount();
      final userId = context.read<AuthViewModel>().userId ?? 0;
      await ApiService.fetchAndCacheGroupedMedia(
        userId: userId,
        page: _currentPage,
        loadMore: true,
      );
      if (mounted && _getMediaCount() <= beforeCount) {
        setState(() => _hasMoreData = false);
      }
    } catch (error) {
      debugPrint('Gallery pagination error: $error');
      _currentPage--;
    }
  }

  int _getMediaCount() {
    final groups = cachedMediaGroupsNotifier.value;
    if (groups == null) return 0;
    return groups.fold<int>(0, (total, group) => total + group.items.length);
  }

  Future<void> _handleRefresh() async {
    try {
      _currentPage = 1;
      _hasMoreData = true;
      final userId = context.read<AuthViewModel>().userId ?? 0;
      await ApiService.fetchAndCacheGroupedMedia(
        userId: userId,
        page: 1,
        loadMore: false,
      );
      if (mounted) setState(() => _initialLoadDone = true);
    } catch (error) {
      debugPrint('Gallery refresh error: $error');
    }
  }

  List<MediaItem> _filterItems(List<MediaItem> items) {
    switch (_filter) {
      case _GalleryFilter.photos:
        return items.where((item) => item.fileType == 'media/img').toList();
      case _GalleryFilter.videos:
        return items.where((item) => item.fileType == 'media/vid').toList();
      case _GalleryFilter.all:
        return items;
    }
  }

  void _openImageDetail(List<MediaItem> items, int index) {
    if (index < 0 || index >= items.length) return;
    selectedImageNotifier.value = items[index];
    context.push('/view_image',
        extra: {'items': items, 'initialIndex': index});
  }

  void _openUploadPage() => context.push('/upload');
  void _openSearchPage() => context.push('/search');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUploadPage,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yükle'),
        tooltip: 'Fotoğraf veya video yükle',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: _buildGalleryContent(),
        ),
      ),
    );
  }

  Widget _buildGalleryContent() {
    return ValueListenableBuilder<List<MediaGroup>?>(
      valueListenable: cachedMediaGroupsNotifier,
      builder: (context, groups, child) {
        if (groups == null && isLoadingMediaNotifier.value) {
          return const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        final sourceGroups = groups ?? <MediaGroup>[];
        final filteredGroups = sourceGroups
            .map((group) => MapEntry(group, _filterItems(group.items)))
            .where((entry) => entry.value.isNotEmpty)
            .toList();
        final allItems = filteredGroups.expand((entry) => entry.value).toList();

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ValueListenableBuilder<int?>(
                valueListenable: totalMediaCountNotifier,
                builder: (context, totalCount, child) =>
                    _buildHeader(totalCount ?? allItems.length),
              ),
            ),
            SliverToBoxAdapter(child: _buildFilterBar(sourceGroups)),
            if (allItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(sourceGroups.isEmpty),
              )
            else
              ...filteredGroups.map((entry) {
                final items = entry.value;
                return _buildDateSection(
                  date: entry.key.date,
                  items: items,
                  allItems: allItems,
                  startIndex: allItems.indexOf(items.first),
                );
              }),
            if (allItems.isNotEmpty && _hasMoreData)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 100),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int visibleCount) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kütüphanem',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$visibleCount öğe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _openSearchPage,
            tooltip: 'Ara',
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<MediaGroup> groups) {
    final total = groups.fold<int>(
        0, (sum, group) => sum + group.items.length);
    final photos = _countType(groups, 'media/img');
    final videos = _countType(groups, 'media/vid');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Tümü', _GalleryFilter.all, total),
            const SizedBox(width: 8),
            _buildFilterChip('Fotoğraflar', _GalleryFilter.photos, photos),
            const SizedBox(width: 8),
            _buildFilterChip('Videolar', _GalleryFilter.videos, videos),
          ],
        ),
      ),
    );
  }

  int _countType(List<MediaGroup> groups, String type) {
    return groups.fold<int>(
      0,
      (total, group) =>
          total + group.items.where((item) => item.fileType == type).length,
    );
  }

  Widget _buildFilterChip(String label, _GalleryFilter filter, int count) {
    final colors = Theme.of(context).colorScheme;
    final selected = _filter == filter;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = filter),
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.secondaryContainer,
      side: BorderSide(
        color: selected ? colors.secondaryContainer : colors.outlineVariant,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection({
    required String date,
    required List<MediaItem> items,
    required List<MediaItem> allItems,
    required int startIndex,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  items.length.toString(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 156,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMediaItem(
                items[index],
                allItems,
                startIndex + index,
              ),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(
      MediaItem item, List<MediaItem> allItems, int globalIndex) {
    final isVideo = item.fileType == 'media/vid';
    final rawUrl = isVideo
        ? item.videoPoster
        : (item.imageWebpMini ?? item.imageWebp ?? item.imageURL);
    final imageUrl =
        rawUrl == null || rawUrl.isEmpty ? null : Uri.encodeFull(rawUrl);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _openImageDetail(allItems, globalIndex),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              _MediaPlaceholder(isVideo: isVideo)
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 320,
                fadeInDuration: const Duration(milliseconds: 160),
                placeholder: (context, url) =>
                    _MediaPlaceholder(isVideo: isVideo),
                errorWidget: (context, url, error) =>
                    _MediaPlaceholder(isVideo: isVideo, hasError: true),
              ),
            if (isVideo)
              Positioned(
                right: 7,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 17, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool libraryIsEmpty) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 110),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                libraryIsEmpty
                    ? Icons.photo_library_outlined
                    : Icons.filter_alt_off_rounded,
                size: 34,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              libraryIsEmpty ? 'Galerin henüz boş' : 'Burada medya yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              libraryIsEmpty
                  ? 'Fotoğraf ve videolarını yükleyerek kişisel arşivini oluşturmaya başla.'
                  : 'Bu filtreye uygun bir içerik bulunamadı.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (libraryIsEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openUploadPage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('İlk içeriğini yükle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final bool isVideo;
  final bool hasError;

  const _MediaPlaceholder({
    required this.isVideo,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          hasError
              ? Icons.broken_image_outlined
              : isVideo
                  ? Icons.movie_outlined
                  : Icons.image_outlined,
          size: 25,
          color: colors.onSurfaceVariant.withOpacity(0.65),
        ),
      ),
    );
  }
}
