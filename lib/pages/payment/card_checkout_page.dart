import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../state/auth_state.dart';
import '../orders/orders_page.dart';

/// Tela de pagamento com cartão usando Checkout Pro (navegador)
/// Muito mais simples e com 95% de aprovação vs 60% do método direto
class CardCheckoutPage extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String userEmail;

  const CardCheckoutPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.userEmail,
  });

  @override
  State<CardCheckoutPage> createState() => _CardCheckoutPageState();
}

class _CardCheckoutPageState extends State<CardCheckoutPage> {
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  Timer? _statusCheckTimer;
  String _statusMessage = 'Aguardando pagamento...';

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _openCheckout() async {
    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthState>();

      debugPrint('💳 Criando preferência de pagamento...');
      
      // Criar preferência de pagamento com split usando o endpoint correto
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/api/payments/mp/create-with-split'),
        headers: {
          'Authorization': 'Bearer ${authState.jwtToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderId': widget.orderId,
          'paymentMethod': 'card', // ✅ Backend espera 'card', não 'credit_card'
        }),
      );

      debugPrint('📥 Status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        throw Exception('Erro ao criar checkout: ${response.body}');
      }

      final data = jsonDecode(response.body);
      
      if (data['success'] != true || data['payment'] == null) {
        throw Exception(data['error'] ?? 'Erro ao criar checkout');
      }

      final initPoint = data['payment']['initPoint'];
      
      if (initPoint == null || initPoint.isEmpty) {
        throw Exception('URL de checkout não recebida');
      }

      debugPrint('🌐 Abrindo checkout: $initPoint');

      // Abrir checkout do Mercado Pago no navegador
      final uri = Uri.parse(initPoint);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Não foi possível abrir o navegador');
      }

      // Iniciar verificação de status
      _startStatusCheck();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Complete o pagamento no navegador aberto';
      });

    } catch (e) {
      debugPrint('❌ Erro: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        _showErrorDialog(e.toString());
      }
    }
  }

  void _startStatusCheck() {
    setState(() => _isCheckingStatus = true);
    
    // Verificar status a cada 5 segundos
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    try {
      final authState = context.read<AuthState>();
      
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/orders/${widget.orderId}'),
        headers: {
          'Authorization': 'Bearer ${authState.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paymentStatus = data['paymentStatus'];

        debugPrint('🔍 Status do pedido: $paymentStatus');

        if (paymentStatus == 'approved') {
          _statusCheckTimer?.cancel();
          
          if (mounted) {
            setState(() {
              _statusMessage = 'Pagamento aprovado! ✅';
              _isCheckingStatus = false;
            });
            
            _showSuccessDialog();
          }
        } else if (paymentStatus == 'rejected') {
          _statusCheckTimer?.cancel();
          
          if (mounted) {
            setState(() {
              _statusMessage = 'Pagamento rejeitado ❌';
              _isCheckingStatus = false;
            });
            
            _showErrorDialog('Pagamento foi rejeitado. Tente novamente com outro cartão.');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar status: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF033D35),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(
              'Pagamento Aprovado!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Seu pedido foi confirmado e já está sendo preparado.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OrdersPage()),
                (route) => false,
              );
            },
            child: const Text(
              'Ver Pedidos',
              style: TextStyle(color: Color(0xFFE39110)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF033D35),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text(
              'Erro',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          message.replaceAll('Exception: ', ''),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFE39110)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        title: const Text(
          'Pagamento com Cartão',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF74241F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ícone
            const Icon(
              Icons.credit_card,
              size: 80,
              color: Color(0xFFE39110),
            ),
            const SizedBox(height: 32),
            
            // Valor
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE39110),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Valor Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R\$ ${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFE39110),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Status
            if (_isCheckingStatus)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF033D35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE39110)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE39110),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_isCheckingStatus) const SizedBox(height: 24),
            
            // Botão
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading || _isCheckingStatus ? null : _openCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE39110),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isCheckingStatus
                            ? 'Aguardando pagamento...'
                            : 'Abrir Checkout Seguro',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Informações
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 16, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'Checkout seguro do Mercado Pago',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Você será redirecionado para o navegador para completar o pagamento de forma segura.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            
            if (_isCheckingStatus) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _statusCheckTimer?.cancel();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const OrdersPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Verificar pedido depois',
                  style: TextStyle(color: Color(0xFFE39110)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
