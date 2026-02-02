import 'package:flutter/material.dart';
import '../models/topping_section.dart';
import 'advanced_toppings_section.dart';

/// 🍕 CONSTRUTOR DE ADICIONAIS AVANÇADOS
/// Gerencia todas as seções de toppings e validação global
class AdvancedToppingsBuilder extends StatefulWidget {
  final List<ToppingSection> sections;
  final Function(List<SelectedTopping> selections, double totalPrice, bool isValid, String? errorMessage) onSelectionsChanged;
  final Color? accentColor;

  const AdvancedToppingsBuilder({
    Key? key,
    required this.sections,
    required this.onSelectionsChanged,
    this.accentColor,
  }) : super(key: key);

  @override
  State<AdvancedToppingsBuilder> createState() => _AdvancedToppingsBuilderState();
}

class _AdvancedToppingsBuilderState extends State<AdvancedToppingsBuilder> {
  /// Mapa de seleções: {sectionId: {itemId: quantity}}
  final Map<String, Map<String, int>> _selections = {};

  @override
  void initState() {
    super.initState();
    // Inicializa mapas vazios para cada seção
    for (var section in widget.sections) {
      _selections[section.id] = {};
    }
  }

  /// Atualiza seleções de uma seção
  void _updateSectionSelection(String sectionId, Map<String, int> items) {
    setState(() {
      _selections[sectionId] = items;
    });
    _notifyChanges();
  }

  /// Converte seleções para lista de SelectedTopping
  List<SelectedTopping> _buildSelections() {
    final List<SelectedTopping> result = [];

    for (var section in widget.sections) {
      final sectionSelections = _selections[section.id] ?? {};
      
      for (var entry in sectionSelections.entries) {
        final itemId = entry.key;
        final quantity = entry.value;
        
        // Encontra o item na seção
        final item = section.items.firstWhere(
          (i) => i.id == itemId,
          orElse: () => ToppingItem(id: '', name: '', price: 0),
        );
        
        if (item.id.isNotEmpty && quantity > 0) {
          result.add(SelectedTopping(
            sectionId: section.id,
            sectionName: section.name,
            itemId: item.id,
            itemName: item.name,
            itemPrice: item.price,
            quantity: quantity,
          ));
        }
      }
    }

    return result;
  }

  /// Calcula preço total dos adicionais
  double _calculateTotalPrice() {
    final selections = _buildSelections();
    return selections.fold<double>(0, (sum, s) => sum + s.totalPrice);
  }

  /// Notifica mudanças para o parent
  void _notifyChanges() {
    final selections = _buildSelections();
    final totalPrice = _calculateTotalPrice();
    widget.onSelectionsChanged(selections, totalPrice, _isValid, _errorMessage);
  }

  /// Verifica se todas as seções obrigatórias estão válidas
  bool get _isValid {
    for (var section in widget.sections) {
      final sectionSelections = _selections[section.id] ?? {};
      final totalSelected = sectionSelections.values.fold<int>(0, (sum, qty) => sum + qty);
      
      // Verifica min/max
      if (totalSelected < section.minItems || totalSelected > section.maxItems) {
        return false;
      }
    }
    return true;
  }

  /// Retorna mensagem de erro da primeira seção inválida
  String? get _errorMessage {
    for (var section in widget.sections) {
      final sectionSelections = _selections[section.id] ?? {};
      final totalSelected = sectionSelections.values.fold<int>(0, (sum, qty) => sum + qty);
      
      if (totalSelected < section.minItems) {
        final needed = section.minItems - totalSelected;
        if (section.minItems == section.maxItems) {
          return 'Selecione ${section.minItems} ${section.name.toLowerCase()}';
        } else {
          return 'Selecione mais $needed ${section.name.toLowerCase()}';
        }
      }
      
      if (totalSelected > section.maxItems) {
        final excess = totalSelected - section.maxItems;
        return 'Remova $excess ${section.name.toLowerCase()}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com título fixo
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                color: Color(0xFFE39110),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Monte seu pedido',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE39110),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Resumo elegante do preço
        if (_calculateTotalPrice() > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Total dos adicionais:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Text(
                  'R\$ ${_calculateTotalPrice().toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Lista de seções
        ...widget.sections.map((section) {
          return AdvancedToppingsSectionWidget(
            section: section,
            selectedItems: _selections[section.id] ?? {},
            onSelectionChanged: (items) => _updateSectionSelection(section.id, items),
            accentColor: widget.accentColor,
          );
        }).toList(),

        const SizedBox(height: 16),
      ],
    );
  }
}
