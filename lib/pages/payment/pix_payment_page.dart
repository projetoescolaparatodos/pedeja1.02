import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../services/payment_service.dart';
import '../checkout/payment_status_page.dart';
import '../orders/orders_page.dart';

class PixPaymentPage extends StatefulWidget {
  final String orderId;
  final String payerEmail;
  final String restaurantId;
  final String restaurantName;

  const PixPaymentPage({
    super.key,
    required this.orderId,
    required this.payerEmail,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<PixPaymentPage> createState() => _PixPaymentPageState();
}

class _PixPaymentPageState extends State<PixPaymentPage> {
  final PaymentService _paymentService = PaymentService();
  
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _paymentData;
  String? _qrCode;
  String? _qrCodeBase64;

  @override
  void initState() {
    super.initState();
    _createPixPayment();
  }

  Future<void> _createPixPayment() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authState = context.read<AuthState>();
      final userData = authState.userData;

      if (userData == null) {
        throw 'Dados do usuário não encontrados';
      }

      // Obter CPF/CNPJ do usuário
      final cpf = userData['cpf'] ?? userData['document'] ?? '';
      
      debugPrint('🔄 [PixPaymentPage] Criando pagamento PIX...');
      debugPrint('   Order ID: ${widget.orderId}');
      debugPrint('   Email: ${widget.payerEmail}');
      debugPrint('   CPF: $cpf');

      final result = await _paymentService.createDirectPayment(
        orderId: widget.orderId,
        jwtToken: authState.jwtToken,
        paymentMethodId: 'pix',
        payerEmail: widget.payerEmail,
        identificationType: 'CPF',
        identificationNumber: cpf,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final payment = result['payment'];
        
        setState(() {
          _paymentData = payment;
          _qrCode = payment['qrCode'];
          _qrCodeBase64 = payment['qrCodeBase64'];
          _isLoading = false;
        });

        debugPrint('✅ [PixPaymentPage] QR Code PIX gerado com sucesso');
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Erro ao gerar PIX';
          _isLoading = false;
        });

        debugPrint('❌ [PixPaymentPage] Erro: $_errorMessage');
      }
    } catch (e) {
      debugPrint('❌ [PixPaymentPage] Exceção: $e');
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Erro ao criar pagamento: $e';
        _isLoading = false;
      });
    }
  }

  void _copyPixCode() {
    if (_qrCode != null) {
      Clipboard.setData(ClipboardData(text: _qrCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código PIX copiado!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToStatus() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentStatusPage(
          orderId: widget.orderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento PIX'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Gerando QR Code PIX...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildError()
              : _buildPixDisplay(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro ao gerar PIX',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createPixPayment,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixDisplay() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruções
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Como pagar com PIX',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Abra o app do seu banco\n'
                    '2. Escolha pagar com PIX QR Code\n'
                    '3. Escaneie o código abaixo\n'
                    '4. Confirme o pagamento',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code
          if (_qrCodeBase64 != null) ...[
            const Text(
              'QR Code PIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.memory(
                  base64Decode(_qrCodeBase64!),
                  width: 250,
                  height: 250,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Código PIX copia e cola
          if (_qrCode != null) ...[
            const Text(
              'Ou copie o código PIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _qrCode!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[800],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _copyPixCode,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Código PIX'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Valor
          if (_paymentData != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Valor Total:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'R\$ ${(_paymentData!['amount'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (_paymentData!['applicationFee'] != null) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Taxa da plataforma:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'R\$ ${(_paymentData!['applicationFee']).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Botão acompanhar pagamento
          ElevatedButton.icon(
            onPressed: _navigateToStatus,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Acompanhar Pagamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF74241F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: Color(0xFFE39110),
                  width: 2,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Botão ver meus pedidos
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const OrdersPage(),
                ),
              );
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Ver Meus Pedidos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE39110),
              side: const BorderSide(
                color: Color(0xFFE39110),
                width: 2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          
          const SizedBox(height: 24),
          
          // Aviso de expiração
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O código PIX expira em 30 minutos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
