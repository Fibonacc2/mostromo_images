// lib/views/pages/view_image.dart
// ignore_for_file: dead_code

import 'package:common_ui/views/widgets/custom_video_player.dart';
import 'package:common_ui/views/widgets/media_info_widget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'
    hide DownloadProgress;
import 'package:go_router/go_router.dart';
import 'package:mostromo_icons/mostromo_icons.dart';
import 'package:shared_core/services/media_downloader.dart';
import 'package:shared_core/models/media_item.dart';

class ViewImagePage extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const ViewImagePage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<ViewImagePage> createState() => _ViewImagePageState();
}

class _ViewImagePageState extends State<ViewImagePage> {
  late PageController _pageController;
  late int _currentIndex;

  // ✅ 1. ÇÖZÜM İÇİN: Zoom state'i ve controller
  late final TransformationController _transformController;
  bool _isZoomed = false;

  // Mevcut sayfadaki MediaItem'ı kolayca almak için bir getter
  MediaItem get _currentMediaItem => widget.items[_currentIndex];
  bool get _isCurrentVideo => _currentMediaItem.fileType == "media/vid";
  String get _currentOriginalUrl =>
      _currentMediaItem.videoURL ?? _currentMediaItem.imageURL ?? '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // ✅ 1. ÇÖZÜM İÇİN: Controller'ı başlat ve dinleyiciyi ekle
    _transformController = TransformationController();
    _transformController.addListener(_onZoomUpdate);
  }

  @override
  void dispose() {
    _pageController.dispose();

    // ✅ 1. ÇÖZÜM İÇİN: Controller'ı ve dinleyiciyi temizle
    _transformController.removeListener(_onZoomUpdate);
    _transformController.dispose();
    super.dispose();
  }

  // ✅ 1. ÇÖZÜM İÇİN: Zoom dinleyicisi
  void _onZoomUpdate() {
    // Mevcut zoom (scale) değerini al
    final double scale = _transformController.value.getMaxScaleOnAxis();

    // Scale 1.0'dan (biraz toleransla) büyükse yakınlaştırılmış demektir
    final bool currentlyZoomed = (scale - 1.0).abs() > 0.01;

    // State değiştiyse (örn: zoom'dan çıktı veya zoom'a girdi)
    // PageView'in 'physics' özelliğini yeniden oluşturmak için setState çağır
    if (currentlyZoomed != _isZoomed) {
      setState(() {
        _isZoomed = currentlyZoomed;
      });
    }
  }

  // Sayfa değiştikçe _currentIndex'i günceller
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;

      // ✅ 1. ÇÖZÜM İÇİN: Sayfa değiştiğinde,
      // bir sonraki sayfanın zoom'lu başlamaması için controller'ı sıfırla.
      _transformController.value = Matrix4.identity();
      _isZoomed = false; // Zoom state'ini manuel sıfırla
    });
  }

  void _showInfoPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InfoWidget(mediaItem: _currentMediaItem),
    );
  }

  void download() {
    MediaDownloader.downloadMedia(
      context: context,
      url: _currentOriginalUrl,
      isVideo: _isCurrentVideo,
    );
  }

  @override
  Widget build(BuildContext artan) {
    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [_buildErrorWidget(), _buildBackButton()]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMediaContent(),
          _buildBackButton(),
          _buildTopRightButtons(),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.items.length,
      onPageChanged: _onPageChanged,

      // ✅ 1. ÇÖZÜM: Dinamik 'physics'
      // Eğer mevcut sayfa video ise VEYA yakınlaştırılmamışsa kaydırmaya izin ver.
      // Eğer mevcut sayfa bir resimse VE yakınlaştırılmışsa kaydırmayı kilitle.
      physics: _isCurrentVideo
          ? const PageScrollPhysics() // Videolar her zaman kaydırılabilsin
          : _isZoomed
          ? const NeverScrollableScrollPhysics() // Yakınlaşan resim kaydırmayı kilitler
          : const PageScrollPhysics(), // Normal resim kaydırılabilir

      itemBuilder: (context, index) {
        final item = widget.items[index];
        final bool isCurrentPage = (index == _currentIndex);

        // Önce media widget'ını oluşturalım
        Widget mediaWidget;
        if (item.fileType == "media/vid") {
          final videoUrl = item.videoURL ?? '';
          if (videoUrl.isEmpty) {
            mediaWidget = _buildErrorWidget();
          } else {
            mediaWidget = CustomVideoPlayer(
              key: ValueKey(item.id ?? videoUrl),
              videoUrl: videoUrl,
              posterUrl: item.videoPoster ?? item.imageWebp,
              autoPlay: isCurrentPage,
              looping: true,
              fit: BoxFit.contain,
            );
          }
        } else {
          // ✅ 1. ÇÖZÜM: Controller'ı _buildImageContent'e yolla
          mediaWidget = _buildImageContent(item, _transformController);
        }

        // ✅ 2. ÇÖZÜM: Estetik geçiş için AnimatedBuilder ile sarmala
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double pageValue = 0.0;
            if (_pageController.position.haveDimensions) {
              // _pageController.page -> o anki sayfa (örn: 1.5)
              // index -> bu builder'ın oluşturduğu sayfa (örn: 1 veya 2)
              // pageValue -> fark (örn: 0.5 veya -0.5)
              pageValue = _pageController.page! - index;
            } else {
              // Controller henüz hazır değilse (ilk açılış)
              pageValue = (widget.initialIndex - index).toDouble();
            }

            // pageValue.abs() -> sayfa merkezden uzaklaştıkça 0'dan 1'e gider

            // 1. Ölçek (Scale) Efekti
            // Sayfa merkezden uzaklaştıkça %20 küçülsün (1.0 -> 0.8)
            double scale = 1.0 - (pageValue.abs() * 0.2);
            scale = scale.clamp(
              0.8,
              1.0,
            ); // Değeri 0.8 ile 1.0 arasında sınırla

            // 2. Solma (Fade) Efekti
            // Sayfa merkezden uzaklaştıkça opaklığı azalsın
            double opacity = 1.0 - (pageValue.abs() * 0.5);
            opacity = opacity.clamp(
              0.5,
              1.0,
            ); // Değeri %50 ile %100 arasında sınırla

            return Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child:
              mediaWidget, // 'child' -> 'builder' fonksiyonuna giden mediaWidget
        );
      },
    );
  }

  // ✅ 1. ÇÖZÜM: İmza değişti, 'controller' parametresi eklendi
  Widget _buildImageContent(
    MediaItem mediaItem,
    TransformationController controller,
  ) {
    final imageUrl = mediaItem.imageWebp ?? mediaItem.imageURL ?? '';
    if (imageUrl.isEmpty) return _buildErrorWidget();

    return InteractiveViewer(
      // ✅ 1. ÇÖZÜM: Controller'ı InteractiveViewer'a bağla
      transformationController: controller,
      panEnabled: true, // panEnabled'ı true tut, 'physics' zaten kilitleyecek
      minScale: 1.0, // minScale 1.0 olmalı ki _isZoomed=false durumu net olsun
      maxScale: 5.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => _buildErrorWidget(),
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: CircularProgressIndicator(
                value: progress.progress,
                color: Colors.teal,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  Widget _buildTopRightButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      // Opaklık vererek geçişlerde daha yumuşak görünmesini sağlayalım
      child: IgnorePointer(
        ignoring: _isZoomed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          // Sadece yakınlaştırılmamışsa butonları tam opak göster
          opacity: _isZoomed ? 0.0 : 1.0,

          child: Row(
            children: [
              if (widget.items.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              if (widget.items.length > 1) const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(MostromoIcons.download_e946, color: Colors.white),
                  onPressed: download,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.white),
                  onPressed: _showInfoPanel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 60, color: Colors.white),
          SizedBox(height: 10),
          Text('Medya yüklenemedi', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}



/*
// lib/views/pages/view_image.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'
    hide DownloadProgress;
import 'package:go_router/go_router.dart';
import 'package:mostromo_connect/services/media_downloader.dart';
import 'package:mostromo_connect/data/notifiers.dart';
import 'package:mostromo_connect/models/media_item.dart';
import '../widgets/custom_video_player.dart'; // ✅ YENİ IMPORT
import '../widgets/media_info_widget.dart'; // ✅ YENİ IMPORT

class ViewImagePage extends StatefulWidget {
  const ViewImagePage({super.key});

  @override
  State<ViewImagePage> createState() => _ViewImagePageState();
}

class _ViewImagePageState extends State<ViewImagePage> {
  late String originalUrl;
  late bool _isVideo;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  void _initializeMedia() {
    final mediaItem = selectedImageNotifier.value;
    if (mediaItem != null) {
      _isVideo = mediaItem.fileType == "media/vid";
      originalUrl = mediaItem.videoURL ?? mediaItem.imageURL ?? '';
    }
  }

  void _showInfoPanel() {
    final mediaItem = selectedImageNotifier.value;
    if (mediaItem != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => InfoWidget(mediaItem: mediaItem),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<MediaItem?>(
        valueListenable: selectedImageNotifier,
        builder: (context, mediaItem, child) {
          if (mediaItem == null) {
            return _buildErrorWidget();
          }

          _isVideo = mediaItem.fileType == "media/vid";
          originalUrl = mediaItem.videoURL ?? mediaItem.imageURL ?? '';

          return Stack(
            children: [
              // Media içeriği
              _buildMediaContent(mediaItem),

              // Back button
              _buildBackButton(),

              // Sağ üst butonlar
              _buildTopRightButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMediaContent(MediaItem mediaItem) {
    if (_isVideo) {
      return CustomVideoPlayer(
        videoUrl: mediaItem.videoURL ?? mediaItem.imageURL ?? '',
        posterUrl: mediaItem.videoPoster ?? mediaItem.imageWebp,
        autoPlay: false,
        looping: true,
        fit: BoxFit.contain, // ✅ Video ortalanacak
      );
    } else {
      return _buildImageContent(mediaItem);
    }
  }

  Widget _buildImageContent(MediaItem mediaItem) {
    final imageUrl = mediaItem.imageWebp ?? mediaItem.imageURL ?? '';

    return InteractiveViewer(
      panEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => _buildErrorWidget(),
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: CircularProgressIndicator(
                value: progress.progress,
                color: Colors.teal,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  Widget _buildTopRightButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: Row(
        children: [
          // Download butonu
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.download_rounded, color: Colors.white),
              onPressed: download,
            ),
          ),

          SizedBox(width: 8),
          // Info butonu
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showInfoPanel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 60, color: Colors.white),
          SizedBox(height: 10),
          Text('Medya yüklenemedi', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void download() {
    MediaDownloader.downloadMedia(
      context: context,
      url: originalUrl,
      isVideo: _isVideo,
    );
  }
}
*/