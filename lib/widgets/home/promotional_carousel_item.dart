import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/promotion_model.dart';
import '../../core/cache/video_cache_manager.dart';

/// 🎬 Item do carrossel de promoções com suporte a vídeo
class PromotionalCarouselItem extends StatefulWidget {
  final PromotionModel promotion;
  final bool isActive; // Se este item está visível no carrossel
  final VoidCallback? onVideoEnd; // ✅ Callback quando vídeo terminar

  const PromotionalCarouselItem({
    super.key,
    required this.promotion,
    required this.isActive,
    this.onVideoEnd,
  });

  @override
  State<PromotionalCarouselItem> createState() =>
      PromotionalCarouselItemState();
}

class PromotionalCarouselItemState extends State<PromotionalCarouselItem> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = false; // ✅ Som ativo por padrão

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [CarouselItem] Promotion: ${widget.promotion.title}');
    debugPrint('🎬 [CarouselItem] MediaType: ${widget.promotion.mediaType}');
    debugPrint('🎬 [CarouselItem] IsVideo: ${widget.promotion.isVideo}');
    debugPrint('🎬 [CarouselItem] MediaUrl: ${widget.promotion.mediaUrl}');
    
    if (widget.promotion.isVideo) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(PromotionalCarouselItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Controlar reprodução baseado na visibilidade
    if (widget.promotion.isVideo && _videoController != null) {
      if (widget.isActive && !_videoController!.value.isPlaying) {
        _videoController!.play();
      } else if (!widget.isActive && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('🎬 [Video] Inicializando vídeo: ${widget.promotion.mediaUrl}');
      
      // 🚀 Tentar obter do cache primeiro
      final videoFile = await VideoCacheManager.getVideoFile(widget.promotion.mediaUrl);
      debugPrint('📦 [Cache] Vídeo obtido: ${videoFile.path}');
      
      // Usar arquivo local do cache
      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      debugPrint('✅ [Video] Vídeo inicializado com sucesso!');
      
      // ✅ Configurar loop e autoplay
      _videoController!.setLooping(false); // Sem loop para detectar fim
      _videoController!.setVolume(1.0); // Som ativo por padrão
      
      // ✅ Listener para detectar fim do vídeo
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          debugPrint('🏁 [Video] Vídeo terminou!');
          widget.onVideoEnd?.call();
          // Reiniciar vídeo para loop manual
          _videoController!.seekTo(Duration.zero);
          if (widget.isActive) {
            _videoController!.play();
          }
        }
      });

      if (widget.isActive) {
        _videoController!.play();
        debugPrint('▶️ [Video] Reproduzindo vídeo...');
      }

      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Erro ao inicializar vídeo: $e');
    }
  }

  void _toggleMute() {
    if (_videoController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _videoController!.setVolume(_isMuted ? 0 : 1);
      });
    }
  }

  /// ✅ Método público para pausar vídeo
  void pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      debugPrint('⏸️ [Video] Vídeo pausado');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Conteúdo (imagem ou vídeo)
          _buildContent(),

          // Overlay com informações
          _buildOverlay(),

          // Controles de vídeo (se for vídeo)
          if (widget.promotion.isVideo) _buildVideoControls(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.promotion.isVideo) {
      if (_isVideoInitialized && _videoController != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      } else {
        // ✅ Loading indicator enquanto vídeo carrega
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }
    } else {
      // Imagem estática
      return CachedNetworkImage(
        imageUrl: widget.promotion.mediaUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.error, color: Colors.white),
        ),
      );
    }
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.promotion.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.promotion.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.promotion.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _toggleMute,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
