import 'package:flutter/material.dart';
import '../models/topping_section.dart';

/// 🍕 WIDGET DE SEÇÃO INDIVIDUAL DE ADICIONAIS AVANÇADOS
/// ExpansionTile que mostra uma seção (ex: "Bases", "Cremes")
/// Permite selecionar itens com quantidade e valida min/max
class AdvancedToppingsSectionWidget extends StatefulWidget {
  final ToppingSection section;
  final Map<String, int> selectedItems; // {itemId: quantity}
  final Function(Map<String, int>) onSelectionChanged;
  final Color? accentColor;

  const AdvancedToppingsSectionWidget({
    Key? key,
    required this.section,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.accentColor,
  }) : super(key: key);

  @override
  State<AdvancedToppingsSectionWidget> createState() => _AdvancedToppingsSectionWidgetState();
}

class _AdvancedToppingsSectionWidgetState extends State<AdvancedToppingsSectionWidget> {
  bool _isExpanded = false;

  /// Retorna o total de itens selecionados nesta seção
  int get _totalSelected {
    return widget.selectedItems.values.fold<int>(0, (sum, qty) => sum + qty);
  }

  /// Verifica se a seção está válida (min/max)
  bool get _isValid {
    final total = _totalSelected;
    return total >= widget.section.minItems && total <= widget.section.maxItems;
  }

  /// Cor da seção baseada na validação
  Color get _sectionColor {
    if (_isValid && _totalSelected > 0) return const Color(0xFF4CAF50); // Verde só quando válido
    return const Color(0xFFE39110); // Dourado padrão
  }

  /// Incrementa quantidade de um item
  void _incrementItem(ToppingItem item) {
    if (_totalSelected >= widget.section.maxItems) {
      // Limite máximo atingido
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo de ${widget.section.maxItems} itens permitidos nesta seção'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final newSelection = Map<String, int>.from(widget.selectedItems);
    newSelection[item.id] = (newSelection[item.id] ?? 0) + 1;
    widget.onSelectionChanged(newSelection);
  }

  /// Decrementa quantidade de um item
  void _decrementItem(ToppingItem item) {
    final currentQty = widget.selectedItems[item.id] ?? 0;
    if (currentQty <= 0) return;

    final newSelection = Map<String, int>.from(widget.selectedItems);
    if (currentQty == 1) {
      newSelection.remove(item.id);
    } else {
      newSelection[item.id] = currentQty - 1;
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A1C18), Color(0xFF3D1412)], // Degradê vermelho mais escuro
        ),
        borderRadius: BorderRadius.circular(14), // Cantos arredondados igual botão
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          initiallyExpanded: widget.section.isRequired,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: const Color(0xFFE39110),
            size: 24,
          ),
          trailing: !_isValid || _totalSelected < widget.section.minItems
              ? const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE39110),
                  size: 24,
                )
              : null,
          title: Text(
            widget.section.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                // Badge elegante "Escolha X a Y"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isValid 
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : const Color(0xFFE39110).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isValid 
                        ? const Color(0xFF4CAF50).withOpacity(0.4)
                        : const Color(0xFFE39110).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isValid)
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Color(0xFF4CAF50),
                        ),
                      if (_isValid) const SizedBox(width: 4),
                      Text(
                        widget.section.minItems == widget.section.maxItems
                          ? 'Escolha ${widget.section.minItems}'
                          : 'Escolha ${widget.section.minItems} a ${widget.section.maxItems}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isValid ? const Color(0xFF4CAF50) : const Color(0xFFE39110),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Contador discreto
                Text(
                  '$_totalSelected selecionado${_totalSelected != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          children: widget.section.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final quantity = widget.selectedItems[item.id] ?? 0;
            final isSelected = quantity > 0;
            
            // Verifica se o item anterior também está selecionado para evitar bordas duplas
            final previousItem = index > 0 ? widget.section.items[index - 1] : null;
            final previousSelected = previousItem != null && (widget.selectedItems[previousItem.id] ?? 0) > 0;

            return InkWell(
              onTap: () => _incrementItem(item), // Toda a área é clicável para adicionar
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  // 🎨 Gradiente vermelho escurecendo para a direita quando selecionado
                  gradient: isSelected 
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF74241F), // Vermelho mais claro à esquerda
                            Color(0xFF5A1C18), // Vermelho mais escuro à direita
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF0D3B3B), // Verde escuro quando não selecionado
                  borderRadius: BorderRadius.circular(8), // Cantos arredondados
                  border: Border(
                  // Borda superior dourada apenas se selecionado E o anterior não está selecionado
                  top: isSelected && !previousSelected
                      ? const BorderSide(color: Color(0xFFE39110), width: 2) 
                      : BorderSide.none,
                  // Borda inferior sempre presente - dourada se selecionado, sutil se não
                  bottom: isSelected 
                      ? const BorderSide(color: Color(0xFFE39110), width: 2)
                      : BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                  // Bordas laterais douradas quando selecionado
                  left: isSelected ? const BorderSide(color: Color(0xFFE39110), width: 2) : BorderSide.none,
                  right: isSelected ? const BorderSide(color: Color(0xFFE39110), width: 2) : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  // Nome e preço
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 17, // Fonte maior
                            color: Colors.white, // Sempre branco
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.formattedPrice,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? const Color(0xFFE39110) : const Color(0xFF4CAF50), // Dourado quando selecionado
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Controles - e +
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão - (cinza quando desativado, branco quando ativo)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 26),
                        color: quantity > 0 
                          ? Colors.white // Branco
                          : Colors.white.withOpacity(0.2), // Cinza
                        onPressed: quantity > 0 ? () => _decrementItem(item) : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      
                      // Quantidade
                      SizedBox(
                        width: 40,
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: quantity > 0 
                              ? const Color(0xFF4CAF50) 
                              : Colors.white,
                          ),
                        ),
                      ),
                      
                      // Botão + (sempre verde quando pode adicionar)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 26),
                        color: _totalSelected < widget.section.maxItems
                          ? const Color(0xFF4CAF50) // Verde
                          : Colors.white.withOpacity(0.2), // Cinza quando limite atingido
                        onPressed: () => _incrementItem(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
