import 'package:flutter/material.dart';
import '../../models/order_model.dart' as models;
import '../../services/order_service.dart';

/// Tela de acompanhamento do status do pagamento
class PaymentStatusPage extends StatefulWidget {
  final String orderId;

  const PaymentStatusPage({
    super.key,
    required this.orderId,
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  final OrderService _orderService = OrderService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D3B3B),
        title: const Text(
          'Status do Pagamento',
          style: TextStyle(color: Color(0xFFE39110)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE39110)),
        automaticallyImplyLeading: false, // Remove botão voltar
      ),
      body: StreamBuilder<models.Order?>(
        stream: _orderService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE39110)),
              ),
            );
          }

          // Erro
          if (snapshot.hasError) {
            return _buildError('Erro ao carregar status do pagamento');
          }

          // Pedido não encontrado
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildError('Pedido não encontrado');
          }

          final order = snapshot.data!;
          final paymentStatus = order.paymentStatus;

          debugPrint('📊 Status do pagamento: ${paymentStatus.value}');

          // Verificar status e exibir tela apropriada
          switch (paymentStatus) {
            case models.PaymentStatus.approved:
            case models.PaymentStatus.paid:
              return _buildSuccess(order);
            
            case models.PaymentStatus.rejected:
              return _buildRejected(order);
            
            case models.PaymentStatus.cancelled:
              return _buildCancelled(order);
            
            case models.PaymentStatus.pending:
              return _buildPending(order);
          }
        },
      ),
    );
  }

  /// Tela de sucesso - Pagamento aprovado
  Widget _buildSuccess(models.Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone de sucesso
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFF4CAF50),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 100,
              ),
            ),

            const SizedBox(height: 32),

            // Título
            const Text(
              'Pagamento Aprovado!',
              style: TextStyle(
                color: Color(0xFFE39110),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Mensagem
            const Text(
              'Seu pedido foi confirmado e está sendo preparado.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Informações do pedido
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B3B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Pedido', '#${order.id.substring(0, 8)}'),
                  const Divider(color: Colors.white24, height: 24),
                  _buildInfoRow('Restaurante', order.restaurantName),
                  const Divider(color: Colors.white24, height: 24),
                  _buildInfoRow(
                    'Total',
                    'R\$ ${order.total.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Botão voltar ao início
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE39110),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Voltar ao Início',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tela de aguardando pagamento
  Widget _buildPending(models.Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animação de loading
            const SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE39110)),
                strokeWidth: 6,
              ),
            ),

            const SizedBox(height: 32),

            // Título
            const Text(
              'Aguardando Pagamento',
              style: TextStyle(
                color: Color(0xFFE39110),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Mensagem
            const Text(
              'Complete o pagamento no Mercado Pago para confirmar seu pedido.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B3B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE39110).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFE39110),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esta tela será atualizada automaticamente quando o pagamento for confirmado.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Botão cancelar
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Cancelar e Voltar',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tela de pagamento rejeitado
  Widget _buildRejected(models.Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone de erro
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF74241F).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFF74241F),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFF74241F),
                size: 100,
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Pagamento Recusado',
              style: TextStyle(
                color: Color(0xFF74241F),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            const Text(
              'O pagamento não foi aprovado. Tente novamente com outro método de pagamento.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE39110),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Voltar ao Início',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tela de pagamento cancelado
  Widget _buildCancelled(models.Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cancel_outlined,
              color: Colors.orange,
              size: 100,
            ),

            const SizedBox(height: 32),

            const Text(
              'Pagamento Cancelado',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE39110),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Voltar ao Início',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tela de erro genérico
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFF74241F),
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE39110),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Voltar ao Início',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget helper para exibir linha de informação
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE39110),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
