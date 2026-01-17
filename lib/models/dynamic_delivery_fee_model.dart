/// Faixa de taxa de entrega dinâmica
/// 
/// Exemplo: minValue: 20, maxValue: 50, customerPays: 3.00
/// Significa: pedidos de R$ 20 a R$ 50, cliente paga R$ 3 de entrega
/// 
/// ⚠️ IMPORTANTE: O subsídio NÃO é salvo no banco!
/// Ele é CALCULADO dinamicamente: deliveryFee - customerPays
class DeliveryFeeTier {
  final double minValue;
  final double? maxValue; // null = sem limite (infinito)
  final double customerPays;

  DeliveryFeeTier({
    required this.minValue,
    this.maxValue,
    required this.customerPays,
  });

  /// Converte de JSON para objeto (vem do Firebase)
  factory DeliveryFeeTier.fromMap(Map<String, dynamic> map) {
    return DeliveryFeeTier(
      minValue: (map['minValue'] ?? 0).toDouble(),
      maxValue: map['maxValue']?.toDouble(),
      customerPays: (map['customerPays'] ?? 0).toDouble(),
      // ⚠️ subsidy NÃO vem do banco - é calculado!
    );
  }

  /// Converte objeto para JSON (para salvar no Firebase)
  Map<String, dynamic> toMap() {
    return {
      'minValue': minValue,
      'maxValue': maxValue,
      'customerPays': customerPays,
      // ⚠️ subsidy NÃO é salvo - backend calcula automaticamente
    };
  }

  /// Calcula subsídio para esta faixa
  /// ✅ SEMPRE calculado, nunca salvo no banco!
  double calculateSubsidy(double realDeliveryFee) {
    final subsidy = realDeliveryFee - customerPays;
    return subsidy > 0 ? subsidy : 0;
  }

  /// Verifica se um valor está nesta faixa
  /// Exemplo: tier.matches(35.00) → true se 20 ≤ 35 < 50
  bool matches(double orderValue) {
    final minMatch = orderValue >= minValue;
    final maxMatch = maxValue == null || orderValue < maxValue!;
    return minMatch && maxMatch;
  }

  @override
  String toString() =>
      'Faixa(R\$ $minValue-${maxValue ?? "∞"}: R\$ $customerPays)';
}

/// Configuração completa de taxa dinâmica
/// O restaurante habilita isso ou usa taxa fixa
class DynamicDeliveryFeeConfig {
  final bool enabled;
  final List<DeliveryFeeTier> tiers;

  DynamicDeliveryFeeConfig({
    required this.enabled,
    required this.tiers,
  });

  /// Converte de JSON para objeto (vem do Firebase)
  factory DynamicDeliveryFeeConfig.fromMap(Map<String, dynamic> map) {
    return DynamicDeliveryFeeConfig(
      enabled: map['enabled'] ?? false,
      tiers: (map['tiers'] as List<dynamic>?)
              ?.map((tier) =>
                  DeliveryFeeTier.fromMap(tier as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Converte objeto para JSON (para salvar no Firebase)
  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'tiers': tiers.map((tier) => tier.toMap()).toList(),
    };
  }

  /// Encontra a faixa correspondente a um valor
  /// Retorna null se nenhuma faixa foi encontrada
  DeliveryFeeTier? findTierForValue(double orderValue) {
    try {
      return tiers.firstWhere((tier) => tier.matches(orderValue));
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() =>
      'Taxa Dinâmica(ativada: $enabled, faixas: ${tiers.length})';
}
