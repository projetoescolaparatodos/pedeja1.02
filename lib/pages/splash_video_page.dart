import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashVideoPage extends StatefulWidget {
  final Widget nextPage;
  const SplashVideoPage({super.key, required this.nextPage});

  @override
  State<SplashVideoPage> createState() => _SplashVideoPageState();
}

class _SplashVideoPageState extends State<SplashVideoPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/Premium_App_Logo_Animation_Creation.mp4',
    )
      ..initialize().then((_) {
        setState(() {
          // vídeo pronto
        });
        _controller.play();
        _fadeController.forward();
      });
    _controller.addListener(_videoListener);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    // ⏱️ TIMEOUT: Máximo 3 segundos na splash
    Future.delayed(const Duration(seconds: 3), () {
      if (!_navigated && mounted) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextPage),
        );
      }
    });
  }

  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextPage),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE39110), // Cor de fundo amarela PedeJá
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo (só aparece antes do vídeo inicializar)
          if (!_controller.value.isInitialized)
            Image.asset(
              'assets/images/capa.jpg',
              fit: BoxFit.cover,
            ),
          // Vídeo em tela cheia
          if (_controller.value.isInitialized)
            FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
