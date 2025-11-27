import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 🎬 Tipo de mídia da promoção
enum PromotionMediaType {
  image,
  video,
}

/// 📢 Modelo de promoção com suporte a imagens e vídeos
class PromotionModel {
  final String id;
  final String title;
  final String description;
  final PromotionMediaType mediaType;
  final String mediaUrl; // URL da imagem ou vídeo
  final String? thumbnailUrl; // Thumbnail do vídeo (obrigatório para vídeos)
  final String? targetUrl; // URL de destino ao clicar
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int priority;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? videoDuration; // Duração em segundos (para vídeos)

  PromotionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.targetUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.priority,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.videoDuration,
  });

  /// Verifica se é um vídeo
  bool get isVideo => mediaType == PromotionMediaType.video;

  /// Verifica se é uma imagem
  bool get isImage => mediaType == PromotionMediaType.image;

  /// Converte dados do Firestore para o modelo
  factory PromotionModel.fromFirestore(Map<String, dynamic> data, String id) {
    debugPrint('📦 [PromotionModel] Parsing promotion: ${data['title']}');
    debugPrint('📦 [PromotionModel] mediaType from Firestore: ${data['mediaType']}');
    debugPrint('📦 [PromotionModel] mediaUrl: ${data['mediaUrl']}');
    debugPrint('📦 [PromotionModel] imageUrl: ${data['imageUrl']}');
    debugPrint('📦 [PromotionModel] videoUrl: ${data['videoUrl']}');
    
    return PromotionModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      mediaType: data['mediaType'] == 'video'
          ? PromotionMediaType.video
          : PromotionMediaType.image,
      // Compatibilidade com campos antigos (imageUrl) e novos (mediaUrl)
      mediaUrl: data['mediaUrl'] ?? data['imageUrl'] ?? data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      targetUrl: data['targetUrl'],
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      isActive: data['isActive'] ?? false,
      priority: _parseInt(data['priority']) ?? 0,
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      videoDuration: _parseInt(data['videoDuration']),
    );
  }

  /// Helper para converter data (String ISO ou Timestamp)
  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    
    if (value is Timestamp) {
      return value.toDate();
    }
    
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  /// Helper para converter int (pode vir como String ou int)
  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    
    if (value is int) {
      return value;
    }
    
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  /// Converte o modelo para Map (para salvar no Firestore)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'mediaType': mediaType == PromotionMediaType.video ? 'video' : 'image',
      'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (targetUrl != null) 'targetUrl': targetUrl,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'priority': priority,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (videoDuration != null) 'videoDuration': videoDuration,
    };
  }

  @override
  String toString() {
    return 'PromotionModel(id: $id, title: $title, mediaType: ${mediaType.name}, isActive: $isActive)';
  }
}
