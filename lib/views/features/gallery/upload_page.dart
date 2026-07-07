// apps/mostromo_images/lib/features/gallery/upload_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// import 'package:go_router/go_router.dart'; // Artık pop yapmayacağımız için buna gerek kalmayabilir ama kalsın

// ORTAK PAKETLER
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/services/upload_controller.dart';
import 'package:file_picker/file_picker.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Galeri için özel URL
      create: (_) => UploadController(
        uploadUrl: "https://mostromo.com/connect/myImages/upload.php",
        additionalFields: {"uploadLocation": "gallery"},
      ),
      child: const _UploadPageView(),
    );
  }
}

class _UploadPageView extends StatefulWidget {
  const _UploadPageView();

  @override
  State<_UploadPageView> createState() => _UploadPageViewState();
}

class _UploadPageViewState extends State<_UploadPageView> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List> _thumbnailCache = {};
  static const int _maxSelectionLimit = 20;

  // Galeri için Native Kanal
  static const platform = MethodChannel('mostromo_images/share');

  @override
  void initState() {
    super.initState();
    _checkSharedFiles();
  }

  // --- NATIVE PAYLAŞIM ---
  Future<void> _checkSharedFiles() async {
    try {
      final bool? hasShare = await platform.invokeMethod('hasPendingShare');
      if (hasShare == true) {
        final List<dynamic>? sharedPaths = await platform.invokeMethod(
          'getSharedFiles',
        );
        if (sharedPaths != null && sharedPaths.isNotEmpty && mounted) {
          final controller = context.read<UploadController>();
          await controller.addFilesFromPaths(sharedPaths.cast<String>());

          if (mounted) {
            _showSnackBar('${sharedPaths.length} medya paylaşımdan eklendi.');
          }
        }
      }
    } catch (e) {
      debugPrint("Paylaşım hatası: $e");
    }
  }

  Future<void> _clearNativeSharedFiles() async {
    try {
      await platform.invokeMethod('clearSharedFiles');
    } catch (e) {
      debugPrint("Native temizleme hatası: $e");
    }
  }

  // --- DOSYA SEÇİMİ ---
  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (images.isNotEmpty && mounted) {
        final paths = images.map((e) => e.path).toList();
        context.read<UploadController>().addFilesFromPaths(paths);
      }
    } catch (e) {
      _showSnackBar('Hata: $e');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (photo != null && mounted) {
        context.read<UploadController>().addFilesFromPaths([photo.path]);
      }
    } catch (e) {
      _showSnackBar('Kamera hatası: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        context.read<UploadController>().addFilesFromPaths([video.path]);
      }
    } catch (e) {
      _showSnackBar('Video hatası: $e');
    }
  }

  Future<void> _takeVideoWithCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
      if (video != null && mounted) {
        context.read<UploadController>().addFilesFromPaths([video.path]);
      }
    } catch (e) {
      _showSnackBar('Video çekim hatası: $e');
    }
  }

  // --- YARDIMCILAR ---
  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath))
      return _thumbnailCache[videoPath];
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 150,
        quality: 50,
      );
      if (uint8list != null) _thumbnailCache[videoPath] = uint8list;
      return uint8list;
    } catch (e) {
      return null;
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(ext);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // --- ARAYÜZ ---
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UploadController>();
    final hasFiles = controller.selectedFiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medya Yükle'),
        actions: [
          if (hasFiles)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showSnackBar(
                '${controller.selectedFiles.length} medya seçildi',
              ),
            ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear' && !controller.isUploading) {
                controller.clearAll();
                _thumbnailCache.clear();
              } else if (value == 'info') {
                _showSnackBar(
                  'Maksimum $_maxSelectionLimit medya seçebilirsiniz',
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Tümünü Temizle'),
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Limit Bilgisi'),
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          if (hasFiles)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.teal.withOpacity(0.1),
                border: const Border(
                  bottom: BorderSide(color: Colors.teal, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: Colors.teal[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${controller.selectedFiles.length} medya seçildi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (controller.selectedFiles.length >= _maxSelectionLimit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Limit Doldu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Expanded(
            child: !hasFiles
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Henüz medya seçilmedi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 48.0),
                          child: Text(
                            'Aşağıdaki "+" butonuna tıklayarak medya seçin veya diğer uygulamalardan paylaşım yapın',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: controller.selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = controller.selectedFiles[index];
                      return _buildMediaItem(file, index, controller);
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: controller.isUploading
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    heroTag: "clearBtn",
                    color: Colors.red,
                    icon: Icons.delete,
                    onPressed: hasFiles
                        ? () {
                            controller.clearAll();
                            _thumbnailCache.clear();
                          }
                        : null,
                  ),
                  _buildActionButton(
                    heroTag: "addBtn",
                    color: ThemeColors.secondary,
                    icon: Icons.add,
                    size: 28,
                    onPressed: _showMediaSourceDialog,
                  ),
                  _buildActionButton(
                    heroTag: "uploadBtn",
                    color: Colors.green,
                    icon: Icons.check,
                    onPressed: hasFiles
                        ? () async {
                            // ✅ Yüklemeyi başlatıyoruz ama sayfayı KAPATMIYORUZ
                            await controller.uploadFiles();
                            await _clearNativeSharedFiles();

                            if (context.mounted) {
                              _showSnackBar(
                                'Yükleme başlatıldı. Arka planda devam edecek.',
                              );
                              // context.pop(); // ❌ BU SATIR KALDIRILDI - Sayfa açık kalacak
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // ✅ Yükleme durumu (İlerleme Çubuğu)
      bottomSheet: controller.isUploading
          ? Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: controller.currentProgress),
                  const SizedBox(height: 10),
                  Text(
                    "Yükleniyor... %${(controller.currentProgress * 100).toInt()}",
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildActionButton({
    required String heroTag,
    required Color color,
    required IconData icon,
    VoidCallback? onPressed,
    double size = 26,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: onPressed != null ? color : Colors.grey[400],
      onPressed: onPressed,
      child: Icon(
        icon,
        color: onPressed != null ? Colors.white : Colors.grey[600],
        size: size,
      ),
    );
  }

  Widget _buildMediaItem(
    PlatformFile file,
    int index,
    UploadController controller,
  ) {
    final path = file.path!;
    final isVideo = _isVideoFile(path);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: SizedBox(
              width: 150,
              height: 150,
              child: isVideo
                  ? FutureBuilder<Uint8List?>(
                      future: _getVideoThumbnail(path),
                      builder: (context, snapshot) {
                        if (snapshot.hasData)
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        return const Center(
                          child: Icon(
                            Icons.videocam,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.error),
                    ),
            ),
          ),
          if (isVideo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          if (!controller.isUploading)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => controller.removeFileAt(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.name,
                style: const TextStyle(color: Colors.white, fontSize: 8),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: const Text('Galeriden Resim Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.teal),
                title: const Text('Kamerayla Fotoğraf Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.teal),
                title: const Text('Galeriden Video Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.teal),
                title: const Text('Kamerayla Video Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takeVideoWithCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}



/*
// upload_page.dart - TAM OPTİMİZE + NATIVE PAYLAŞIM
import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_core/services/upload_service.dart';
import 'package:common_ui/views/widgets/upload_progress.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List> _thumbnailCache = {};
  bool _isUploading = false;
  static const int _maxSelectionLimit = 20;

  // ✅ NATIVE CHANNEL - Paylaşım için
  static const platform = MethodChannel('mostromo_images/share');

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  // ✅ OPTİMİZE EDİLMİŞ: Sayfa başlangıcını yönet
  void _initializePage() async {
    // Route animasyonu için kısa bekleme
    await Future.delayed(const Duration(milliseconds: 300));

    // Paylaşımı kontrol et
    await _checkAndLoadSharedFiles();
  }

  // ✅ OPTİMİZE EDİLMİŞ: Paylaşım kontrolü
  Future<void> _checkAndLoadSharedFiles() async {
    try {
      final bool? hasShare = await platform.invokeMethod('hasPendingShare');

      if (hasShare == true) {
        final List<dynamic>? sharedFiles = await platform.invokeMethod(
          'getSharedFiles',
        );

        if (sharedFiles != null && sharedFiles.isNotEmpty) {
          _handleSharedFiles(sharedFiles.cast<String>());

          if (mounted) {
            //_showSnackBar('${sharedFiles.length} medya paylaşımdan eklendi! 📸',);
          }
        } else {
          // Paylaşım işareti var ama dosya yoksa temizle
          _clearNativeSharedFiles();
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Paylaşım kontrol hatası: ${e.message}');
      }
    }
  }

  // ✅ DÜZELTİLMİŞ: Paylaşılan dosyaları işle
  void _handleSharedFiles(List<String> filePaths) {
    if (kDebugMode) {
      print('🔄 Paylaşılan dosya yolları: $filePaths');
    }

    int addedCount = 0;

    for (final filePath in filePaths) {
      if (_selectedMedias.length >= _maxSelectionLimit) break;

      try {
        final file = File(filePath);
        final exists = file.existsSync();

        if (kDebugMode) {
          print('📁 Dosya kontrolü: $filePath');
          print('📁 Dosya var mı: $exists');
          if (exists) {
            print('📁 Dosya boyutu: ${file.lengthSync()} bytes');
          }
        }

        if (exists) {
          final xFile = XFile(filePath);
          _addMedia(xFile);
          addedCount++;

          if (kDebugMode) {
            print('✅ Dosya eklendi: $filePath');
          }
        } else {
          if (kDebugMode) {
            print('❌ Dosya bulunamadı: $filePath');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Dosya hatası: $e');
        }
      }
    }

    if (addedCount > 0 && mounted) {
      //_showSnackBar('$addedCount medya paylaşımdan eklendi! 📸');
      // ❌ BURAYI KALDIR: _clearNativeSharedFiles(); // Dosyaları HEMEN temizleme!
    } else if (mounted) {
      _showSnackBar('Medya yüklenemedi 😞');
    }
  }

  // ✅ GÜNCELLENMİŞ: Sadece upload başarılı olursa temizle
  Future<void> _uploadFiles() async {
    if (_selectedMedias.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      List<File> files = _selectedMedias
          .map((media) => File(media.path))
          .where((file) => file.existsSync())
          .toList();

      if (files.isEmpty) {
        _showSnackBar('Dosyalar bulunamadı');
        return;
      }

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UploadProgressDialog(
          uploadStream: UploadService.uploadFilesWithProgress(files),
        ),
      ).then((result) {
        setState(() {
          _isUploading = false;
        });

        if (result is UploadResult && result.success) {
          _clearAllMedia();
          _clearNativeSharedFiles(); // ✅ SADECE BAŞARILI UPLOAD'DAN SONRA TEMİZLE
        }
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showSnackBar('Upload başlatılamadı: $e');
    }
  }

  // ✅ NATIVE TARAFTAKİ GEÇİCİ DOSYALARI TEMİZLE
  void _clearNativeSharedFiles() async {
    try {
      await platform.invokeMethod('clearSharedFiles');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Clear shared files error: ${e.message}');
      }
    }
  }

  void _addMedia(XFile media) {
    if (_selectedMedias.length >= _maxSelectionLimit) {
      _showSnackBar('Maksimum $_maxSelectionLimit medya seçebilirsiniz');
      return;
    }

    setState(() {
      _selectedMedias.add(media);
    });
  }

  void _clearAllMedia() {
    setState(() {
      _selectedMedias.clear();
      _thumbnailCache.clear();
    });
  }

  void _removeMedia(int index) {
    if (index >= 0 && index < _selectedMedias.length) {
      final removedMedia = _selectedMedias[index];
      _thumbnailCache.remove(removedMedia.path);

      setState(() {
        _selectedMedias.removeAt(index);
      });
    }
  }

  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      if (kIsWeb) return null;

      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 150,
        maxHeight: 150,
        quality: 50,
        timeMs: 1000,
      );

      if (uint8list != null) {
        _thumbnailCache[videoPath] = uint8list;
      }

      return uint8list;
    } catch (e) {
      if (kDebugMode) {
        print('Thumbnail oluşturma hatası: $e');
      }
      return null;
    }
  }

  Widget _buildMediaPreview(XFile media) {
    final isVideo = _isVideoFile(media);

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Media content
          Positioned.fill(
            child: isVideo
                ? (kIsWeb
                      ? _buildVideoFallbackWidget()
                      : FutureBuilder<Uint8List?>(
                          future: _getVideoThumbnail(media.path),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildLoadingWidget();
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return _buildVideoFallbackWidget();
                            }
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              width: 150,
                              height: 150,
                            );
                          },
                        ))
                : Image.file(
                    File(media.path),
                    fit: BoxFit.cover,
                    width: 150,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorWidget('Resim');
                    },
                  ),
          ),

          // Video indicator
          if (isVideo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isVideoFile(XFile media) {
    return media.mimeType?.contains('video') ??
        media.path.toLowerCase().contains('.mp4') ||
            media.path.toLowerCase().contains('.mov') ||
            media.path.toLowerCase().contains('.avi') ||
            media.path.toLowerCase().contains('.mkv');
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 8),
          Text('Yükleniyor...', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildVideoFallbackWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam, size: 40, color: Colors.blue),
        SizedBox(height: 8),
        Text(
          'Video',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String type) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 40, color: Colors.red),
        const SizedBox(height: 4),
        Text(
          '$type yüklenemedi',
          style: const TextStyle(fontSize: 10, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildMediaItem(XFile media, int index) {
    final isVideo = _isVideoFile(media);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Stack(
        children: [
          SizedBox(width: 150, height: 150, child: _buildMediaPreview(media)),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),

          // Media type badge
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVideo ? 'Video' : 'Resim',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // File name
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getFileName(media),
                style: const TextStyle(color: Colors.white, fontSize: 8),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFileName(XFile media) {
    final path = media.path;
    final name = media.name;

    if (name.isNotEmpty && name != path) {
      return name;
    }

    final segments = path.split('/');
    return segments.last;
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      // ignore: unnecessary_null_comparison
      if (images != null && images.isNotEmpty) {
        for (final image in images) {
          _addMedia(image);
        }
        //_showSnackBar('${images.length} resim eklendi');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Resim seçme hatası: $e');
      }
      _showSnackBar('Resim seçilirken hata oluştu');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (photo != null) {
        _addMedia(photo);
        //_showSnackBar('Fotoğraf başarıyla eklendi');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Kamera hatası: $e');
      }
      _showSnackBar('Kamera açılırken hata oluştu');
    }
  }

  Future<void> _takeVideoWithCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        _addMedia(video);
        //_showSnackBar('Video başarıyla eklendi');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Video çekme hatası: $e');
      }
      _showSnackBar('Video çekilirken hata oluştu');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        _addMedia(video);
        // _showSnackBar('Video başarıyla eklendi');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Video seçme hatası: $e');
      }
      _showSnackBar('Video seçilirken hata oluştu');
    }
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: const Text('Galeriden Resim Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.teal),
                title: const Text('Kamerayla Fotoğraf Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.teal),
                title: const Text('Galeriden Video Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.teal),
                title: const Text('Kamerayla Video Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takeVideoWithCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadButton() {
    final bool isEnabled = _selectedMedias.isNotEmpty && !_isUploading;

    return FloatingActionButton(
      heroTag: "uploadBtn",
      backgroundColor: isEnabled ? Colors.green : Colors.grey[400],
      onPressed: isEnabled ? _uploadFiles : null,
      tooltip: 'Yükle',
      child: Icon(
        Icons.check,
        color: isEnabled ? Colors.white : Colors.grey[600],
        size: 26,
      ),
    );
  }

  Widget _buildClearButton() {
    final bool isEnabled = _selectedMedias.isNotEmpty && !_isUploading;

    return FloatingActionButton(
      heroTag: "clearBtn",
      backgroundColor: isEnabled ? Colors.red : Colors.grey[400],
      onPressed: isEnabled ? _clearAllMedia : null,
      tooltip: 'Tümünü Temizle',
      child: Icon(
        Icons.delete,
        color: isEnabled ? Colors.white : Colors.grey[600],
        size: 26,
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      heroTag: "addBtn",
      onPressed: _isUploading ? null : _showMediaSourceDialog,
      backgroundColor: _isUploading ? Colors.grey : ThemeColors.secondary,
      tooltip: 'Medya Ekle',
      child: Icon(
        Icons.add,
        color: _isUploading ? Colors.grey[600] : Colors.white,
        size: 28,
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Tamam', onPressed: () {}),
      ),
    );
  }

  @override
  void dispose() {
    _clearNativeSharedFiles();
    _selectedMedias.clear();
    _thumbnailCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medya Yükle'),
        foregroundColor: ThemeColors.titleText,
        backgroundColor: ThemeColors.surface,
        elevation: 0,
        actions: [
          if (_selectedMedias.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                _showSnackBar('${_selectedMedias.length} medya seçildi');
              },
              tooltip: 'Seçilen Medya Sayısı',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllMedia();
              } else if (value == 'info') {
                _showSnackBar(
                  'Maksimum $_maxSelectionLimit medya seçebilirsiniz',
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Tümünü Temizle'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Limit Bilgisi'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Selection info
          if (_selectedMedias.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.teal.withOpacity(0.1),
                border: const Border(
                  bottom: BorderSide(color: Colors.teal, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: Colors.teal[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedMedias.length} medya seçildi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMedias.length >= _maxSelectionLimit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Limit Doldu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Media grid
          Expanded(
            child: _selectedMedias.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Henüz medya seçilmedi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 48.0),
                          child: Text(
                            'Aşağıdaki "+" butonuna tıklayarak medya seçin veya diğer uygulamalardan paylaşım yapın',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: _selectedMedias.length,
                    itemBuilder: (context, index) {
                      return _buildMediaItem(_selectedMedias[index], index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildClearButton(),
            _buildAddButton(),
            _buildUploadButton(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}





import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedMedias.addAll(images);
        });
      }
    } catch (e) {
      print('Resim seçme hatası: $e');
      _showSnackBar('Resim seçilirken hata oluştu');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _selectedMedias.add(photo);
        });
        _showSnackBar('Fotoğraf başarıyla çekildi');
      }
    } catch (e) {
      print('Kamera hatası: $e');
      _showSnackBar('Kamera açılırken hata oluştu');
    }
  }

  Future<void> _takeVideoWithCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        setState(() {
          _selectedMedias.add(video);
        });
        _showSnackBar('Video başarıyla çekildi');
      }
    } catch (e) {
      print('Video çekme hatası: $e');
      _showSnackBar('Video çekilirken hata oluştu');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        setState(() {
          _selectedMedias.add(video);
        });
      }
    } catch (e) {
      print('Video seçme hatası: $e');
      _showSnackBar('Video seçilirken hata oluştu');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galeriden Resim Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Kamerayla Fotoğraf Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library),
                title: Text('Galeriden Video Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Kamerayla Video Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _takeVideoWithCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedias.removeAt(index);
    });
  }

  Widget _buildMediaPreview(XFile media) {
    final isVideo =
        media.mimeType?.contains('video') ??
        media.path.toLowerCase().contains('.mp4') ||
            media.path.toLowerCase().contains('.mov') ||
            media.path.toLowerCase().contains('.avi') ||
            media.path.toLowerCase().contains('.mkv') ||
            media.name.toLowerCase().contains('.mp4') ||
            media.name.toLowerCase().contains('.mov') ||
            media.name.toLowerCase().contains('.avi') ||
            media.name.toLowerCase().contains('.mkv') ||
            false;
    final isImage = !isVideo;

    return Stack(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: isImage
              ? Image.file(
                  File(media.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorWidget('Resim');
                  },
                )
              : (kIsWeb
                    ? _buildVideoFallbackWidget() // Web'de thumbnail desteklenmez
                    : FutureBuilder<Uint8List?>(
                        future: _getVideoThumbnail(media.path),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingWidget();
                          }

                          if (snapshot.hasError || snapshot.data == null) {
                            return _buildVideoFallbackWidget();
                          }

                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildVideoFallbackWidget();
                            },
                          );
                        },
                      )),
        ),
        if (isVideo)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
            ),
          ),
      ],
    );
  }

  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    try {
      // Web platformunda thumbnail oluşturma desteklenmez
      if (kIsWeb) return null;

      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 300,
        quality: 80,
        timeMs: 1000,
      );
      return uint8list;
    } catch (e) {
      print('Thumbnail oluşturma hatası: $e');
      return null;
    }
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 8),
          Text('Yükleniyor...', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildVideoFallbackWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam, size: 40, color: Colors.blue),
        SizedBox(height: 8),
        Text(
          'Video',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String type) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error, size: 40, color: Colors.red),
        SizedBox(height: 4),
        Text(
          '$type yüklenemedi',
          style: TextStyle(fontSize: 10, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildMediaItem(XFile media, int index) {
    final isVideo =
        media.mimeType?.contains('video') ??
        media.path.toLowerCase().contains('.mp4') ||
            media.path.toLowerCase().contains('.mov') ||
            media.path.toLowerCase().contains('.avi') ||
            media.path.toLowerCase().contains('.mkv') ||
            media.name.toLowerCase().contains('.mp4') ||
            media.name.toLowerCase().contains('.mov') ||
            media.name.toLowerCase().contains('.avi') ||
            media.name.toLowerCase().contains('.mkv') ||
            false;

    return Card(
      margin: EdgeInsets.all(8),
      child: Stack(
        children: [
          Container(width: 150, height: 150, child: _buildMediaPreview(media)),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: IconButton(
                icon: Icon(Icons.close, size: 12, color: Colors.white),
                onPressed: () => _removeMedia(index),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVideo ? 'Video' : 'Resim', // Burada düzeltme yapıldı
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yükle'),
        backgroundColor: Colors.teal,
        actions: [
          if (_selectedMedias.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _selectedMedias.clear();
                });
              },
              tooltip: 'Tümünü Temizle',
            ),
        ],
      ),
      body: Column(
        children: [
          // Seçim Butonları
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showMediaSourceDialog,
                    icon: Icon(Icons.add_photo_alternate),
                    label: Text('Medya Ekle'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedMedias.isNotEmpty
                        ? () {
                            _showSnackBar(
                              '${_selectedMedias.length} medya seçildi',
                            );
                            // Burada seçilen medyaları işleyebilirsiniz
                            print(
                              'Seçilen medyalar: ${_selectedMedias.map((m) => m.path).toList()}',
                            );
                          }
                        : null,
                    icon: Icon(Icons.check),
                    label: Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Medya Listesi
          Expanded(
            child: _selectedMedias.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Henüz medya seçilmedi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aşağıdaki butona tıklayarak medya seçin',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _selectedMedias.length,
                    itemBuilder: (context, index) {
                      return _buildMediaItem(_selectedMedias[index], index);
                    },
                  ),
          ),
          Positioned(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    backgroundColor: _selectedMedias.isNotEmpty
                        ? Colors.red.shade600
                        : Colors.grey[600],
                    onPressed: () {
                      _selectedMedias.isNotEmpty
                          ? setState(() {
                              _selectedMedias.clear();
                            })
                          : null;
                    },
                    child: Icon(
                      Icons.delete_outlined,
                      size: 26,
                      color: _selectedMedias.isNotEmpty
                          ? Colors.white
                          : Colors.grey[400],
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () => _showMediaSourceDialog(),
                    child: Icon(Icons.add_rounded, size: 36),
                  ),
                  FloatingActionButton(
                    backgroundColor: _selectedMedias.isNotEmpty
                        ? Colors.green
                        : Colors.grey[600],
                    onPressed: () {
                      _selectedMedias.isNotEmpty
                          ? _showSnackBar('')
                          : _showSnackBar('');
                    },
                    child: Icon(
                      Icons.check_rounded,
                      size: 26,
                      color: _selectedMedias.isNotEmpty
                          ? Colors.white
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/