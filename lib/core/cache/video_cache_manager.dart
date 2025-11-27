import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 🎬 Gerenciador de cache de vídeos para o carrossel
/// 
/// Configurações:
/// - Cache de 7 dias (uma semana)
/// - Máximo de 100 vídeos em cache
/// - Máximo de 500MB em disco
/// 
/// Benefícios:
/// - Vídeos são baixados uma vez e reutilizados
/// - Transições mais fluidas no carrossel
/// - Economia de dados para o usuário
/// - Melhor performance geral
class VideoCacheManager {
  static const key = 'promotional_videos';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // Cache válido por 7 dias
      maxNrOfCacheObjects: 100, // Máximo de 100 vídeos
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Limpa o cache de vídeos (útil para debug ou configurações)
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }

  /// Pré-carrega um vídeo no cache (útil para próximos vídeos do carrossel)
  static Future<void> precacheVideo(String url) async {
    try {
      debugPrint('⏳ [VideoCache] Pré-carregando vídeo: ${url.substring(0, 50)}...');
      await instance.downloadFile(url);
      debugPrint('✅ [VideoCache] Vídeo pré-carregado com sucesso!');
    } catch (e) {
      debugPrint('⚠️ [VideoCache] Erro ao pré-carregar vídeo: $e');
    }
  }

  /// Obtém um vídeo do cache ou baixa se necessário
  static Future<File> getVideoFile(String url) async {
    debugPrint('🔍 [VideoCache] Buscando vídeo: ${url.substring(0, 50)}...');
    
    final fileInfo = await instance.getFileFromCache(url);
    if (fileInfo != null) {
      debugPrint('✅ [VideoCache] Vídeo encontrado no CACHE! Path: ${fileInfo.file.path}');
      debugPrint('📊 [VideoCache] Tamanho: ${(fileInfo.file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
      return fileInfo.file;
    }
    
    debugPrint('⬇️ [VideoCache] Vídeo NÃO está no cache. Baixando...');
    final file = await instance.getSingleFile(url);
    debugPrint('✅ [VideoCache] Vídeo baixado e SALVO no cache! Path: ${file.path}');
    debugPrint('📊 [VideoCache] Tamanho: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
    return file;
  }
}
