import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// 🕒 Serviço de Horários de Funcionamento
/// 
/// Consulta a API para atualizar o status de abertura/fechamento dos restaurantes
/// baseado no horário local de Belém do Pará (UTC-3)
class OperatingHoursService {
  static DateTime? _lastRefresh;
  static bool _isRefreshing = false;
  
  /// 🔄 Atualiza os horários de funcionamento dos restaurantes
  /// 
  /// Parâmetros:
  /// - [force]: força atualização mesmo se foi feita recentemente
  /// - [internalKey]: chave interna opcional para autenticação
  /// 
  /// Retorna true se atualizado com sucesso, false caso contrário
  static Future<bool> refreshOperatingHours({
    bool force = false,
    String? internalKey,
  }) async {
    // Evita múltiplas requisições simultâneas
    if (_isRefreshing) {
      debugPrint('⏳ [OperatingHours] Refresh já em andamento');
      return false;
    }
    
    // Só atualiza se passou mais de 1 minuto da última atualização (exceto se force=true)
    if (!force && _lastRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefresh!);
      if (timeSinceLastRefresh.inMinutes < 1) {
        debugPrint('⏭️ [OperatingHours] Última atualização há ${timeSinceLastRefresh.inSeconds}s, pulando');
        return true;
      }
    }
    
    _isRefreshing = true;
    
    try {
      debugPrint('🔄 [OperatingHours] Atualizando horários...');
      
      // 🌎 Obter hora atual de Belém do Pará (UTC-3)
      final belemTime = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      debugPrint('🕒 [OperatingHours] Hora de Belém: ${belemTime.hour}:${belemTime.minute.toString().padLeft(2, '0')}');
      
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants/refresh-operating-hours'),
        headers: {
          if (internalKey != null) 'x-internal-key': internalKey,
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Tempo esgotado ao atualizar horários');
        },
      );
      
      if (response.statusCode == 200) {
        _lastRefresh = DateTime.now();
        debugPrint('✅ [OperatingHours] Horários atualizados com sucesso');
        _isRefreshing = false;
        return true;
      } else {
        debugPrint('❌ [OperatingHours] Erro ${response.statusCode}: ${response.body}');
        _isRefreshing = false;
        return false;
      }
    } catch (e) {
      debugPrint('❌ [OperatingHours] Erro ao atualizar: $e');
      _isRefreshing = false;
      return false;
    }
  }
  
  /// 📅 Retorna a hora atual de Belém do Pará (UTC-3)
  static DateTime getBelemTime() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }
}

/// ⚠️ DEPRECATED: Use OperatingHoursService.refreshOperatingHours() diretamente
@Deprecated('Use OperatingHoursService.refreshOperatingHours() ao invés do timer automático')
void startOperatingHoursRefresh({String? internalKey}) {
  // Timer removido - agora fazemos refresh sob demanda
  debugPrint('⚠️ [OperatingHours] Timer automático desabilitado - usando refresh sob demanda');
}
