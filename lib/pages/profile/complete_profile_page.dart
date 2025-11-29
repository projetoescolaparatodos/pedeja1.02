import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/user_state.dart';
import '../../state/auth_state.dart';
import '../../services/location_service.dart';
import '../home/home_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _loading = false;
  bool _loadingGPS = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ [CompleteProfilePage] initState chamado');
    
    // ⚡ Carrega dados após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('⚡ [CompleteProfilePage] PostFrameCallback executado');
      _loadUserData();
    });
  }

  void _loadUserData() {
    debugPrint('📡 [CompleteProfilePage] _loadUserData iniciado');
    
    // Tenta pegar do AuthState primeiro
    final authState = context.read<AuthState>();
    final userState = context.read<UserState>();
    
    var userData = authState.userData ?? userState.userData;

    debugPrint('📋 [CompleteProfilePage] AuthState.userData: ${authState.userData}');
    debugPrint('📋 [CompleteProfilePage] UserState.userData: ${userState.userData}');
    debugPrint('📋 [CompleteProfilePage] userData final: $userData');

    if (userData != null) {
      setState(() {
        _nameController.text = userData['name'] ?? userData['displayName'] ?? '';
        _phoneController.text = userData['phone'] ?? '';

        final address = userData['address'];
        if (address != null && address is Map) {
          _zipCodeController.text = address['zipCode'] ?? '';
          _streetController.text = address['street'] ?? '';
          _numberController.text = address['number'] ?? '';
          _complementController.text = address['complement'] ?? '';
          _neighborhoodController.text = address['neighborhood'] ?? '';
          _cityController.text = address['city'] ?? '';
          _stateController.text = address['state'] ?? '';
        }
      });
      
      debugPrint('✅ [CompleteProfilePage] Dados carregados nos controllers');
    } else {
      debugPrint('⚠️ [CompleteProfilePage] userData é null - iniciando com campos vazios');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final authState = context.read<AuthState>();
      final userState = context.read<UserState>();

      debugPrint('💾 [CompleteProfilePage] Salvando perfil via API...');

      // 1️⃣ Chama API para completar registro
      final success = await authState.completeRegistration(
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: {
          'zipCode': _zipCodeController.text.trim(),
          'street': _streetController.text.trim(),
          'number': _numberController.text.trim(),
          'complement': _complementController.text.trim(),
          'neighborhood': _neighborhoodController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim().toUpperCase(),
          'formatted': '${_streetController.text.trim()}, ${_numberController.text.trim()} - ${_neighborhoodController.text.trim()}, ${_cityController.text.trim()}/${_stateController.text.trim().toUpperCase()}',
        },
      );

      if (!mounted) return;

      if (success) {
        debugPrint('✅ [CompleteProfilePage] Perfil salvo com sucesso');

        // 2️⃣ Atualiza UserState local também
        await userState.updateUserData({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': {
            'zipCode': _zipCodeController.text.trim(),
            'street': _streetController.text.trim(),
            'number': _numberController.text.trim(),
            'complement': _complementController.text.trim(),
            'neighborhood': _neighborhoodController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _stateController.text.trim().toUpperCase(),
          },
          'updatedAt': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cadastro completado com sucesso!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        // 3️⃣ Navega para HomePage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        final error = authState.error ?? 'Erro ao salvar dados';
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $error'),
            backgroundColor: const Color(0xFF74241F),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [CompleteProfilePage] Erro: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro inesperado: $e'),
            backgroundColor: const Color(0xFF74241F),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _useGPSLocation() async {
    setState(() => _loadingGPS = true);

    try {
      debugPrint('📍 [CompleteProfilePage] Obtendo localização GPS...');

      final address = await LocationService.getCurrentAddress();

      if (address == null) {
        throw Exception('Não foi possível obter o endereço');
      }

      setState(() {
        _streetController.text = address['street'] ?? '';
        _numberController.text = address['number'] ?? '';
        _neighborhoodController.text = address['neighborhood'] ?? '';
        _cityController.text = address['city'] ?? '';
        _stateController.text = address['state'] ?? '';
        _zipCodeController.text = address['zipCode'] ?? '';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Endereço preenchido com sua localização!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      debugPrint('✅ [CompleteProfilePage] Endereço GPS preenchido');
    } catch (e) {
      debugPrint('❌ [CompleteProfilePage] Erro ao obter GPS: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFF74241F),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _loadingGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [CompleteProfilePage] build() chamado');
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D3B3B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF74241F),
        elevation: 0,
        title: const Text(
          'Completar Cadastro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aviso
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF74241F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE39110),
                    width: 1,
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
                        'Preencha todos os campos para finalizar seus pedidos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 📝 DADOS PESSOAIS
              const Text(
                'Dados Pessoais',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE39110),
                ),
              ),
              const SizedBox(height: 16),

              // Nome
              _buildTextField(
                controller: _nameController,
                label: 'Nome Completo *',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  if (value.trim().split(' ').length < 2) {
                    return 'Digite seu nome completo';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Telefone
              _buildTextField(
                controller: _phoneController,
                label: 'Telefone *',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _PhoneMaskFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Telefone é obrigatório';
                  }
                  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                  if (digitsOnly.length < 10) {
                    return 'Telefone inválido';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // 🏠 ENDEREÇO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Endereço de Entrega',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE39110),
                    ),
                  ),
                  // Botão GPS
                  ElevatedButton.icon(
                    onPressed: _loadingGPS ? null : _useGPSLocation,
                    icon: _loadingGPS
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(_loadingGPS ? 'Obtendo...' : 'GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CEP
              _buildTextField(
                controller: _zipCodeController,
                label: 'CEP *',
                icon: Icons.location_on,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CepMaskFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'CEP é obrigatório';
                  }
                  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                  if (digitsOnly.length != 8) {
                    return 'CEP inválido';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Rua
              _buildTextField(
                controller: _streetController,
                label: 'Rua/Avenida *',
                icon: Icons.home,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Rua é obrigatória';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Número e Complemento
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _numberController,
                      label: 'Número *',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _complementController,
                      label: 'Complemento',
                      icon: Icons.apartment,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bairro
              _buildTextField(
                controller: _neighborhoodController,
                label: 'Bairro *',
                icon: Icons.location_city,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bairro é obrigatório';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Cidade e Estado
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'Cidade *',
                      icon: Icons.business,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Cidade é obrigatória';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _stateController,
                      label: 'UF *',
                      icon: Icons.map,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'UF obrigatória';
                        }
                        if (value.length != 2) {
                          return 'UF inválida';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 💾 BOTÃO SALVAR
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE39110),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Salvar e Continuar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFE39110)),
        filled: true,
        fillColor: const Color(0xFF022E28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A4747)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE39110), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5722)),
        ),
        counterText: '', // Remove contador
      ),
      style: const TextStyle(color: Colors.white),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}

/// Máscara de telefone: (11) 91234-5678
class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    if (text.isNotEmpty) {
      buffer.write('(');
      buffer.write(text.substring(0, text.length.clamp(0, 2)));

      if (text.length > 2) {
        buffer.write(') ');
        buffer.write(text.substring(2, text.length.clamp(2, 7)));
      }

      if (text.length > 7) {
        buffer.write('-');
        buffer.write(text.substring(7, text.length.clamp(7, 11)));
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Máscara de CEP: 12345-678
class _CepMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    if (text.isNotEmpty) {
      buffer.write(text.substring(0, text.length.clamp(0, 5)));

      if (text.length > 5) {
        buffer.write('-');
        buffer.write(text.substring(5, text.length.clamp(5, 8)));
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
