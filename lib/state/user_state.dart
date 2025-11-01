import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Estado do usuário com validação de perfil completo
class UserState extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _loading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? get userData => _userData;
  bool get loading => _loading;
  String? get error => _error;

  /// ✅ Verifica se o perfil está completo com todos os campos obrigatórios
  bool get isProfileComplete {
    if (_userData == null) return false;

    // Valida Nome
    if (_userData!['name'] == null ||
        _userData!['name'].toString().trim().isEmpty) {
      return false;
    }

    // Valida Telefone
    if (_userData!['phone'] == null ||
        _userData!['phone'].toString().trim().isEmpty) {
      return false;
    }

    // Valida Endereço
    final address = _userData!['address'];
    if (address == null || address is! Map) return false;

    // Campos obrigatórios do endereço
    final requiredFields = [
      'street',
      'number',
      'neighborhood',
      'city',
      'state',
      'zipCode'
    ];

    for (final field in requiredFields) {
      if (address[field] == null || address[field].toString().trim().isEmpty) {
        return false;
      }
    }

    return true; // ✅ Tudo OK!
  }

  /// Campos faltantes para completar o perfil
  List<String> get missingFields {
    final missing = <String>[];

    if (_userData == null) {
      return ['Todos os dados'];
    }

    if (_userData!['name'] == null ||
        _userData!['name'].toString().trim().isEmpty) {
      missing.add('Nome completo');
    }

    if (_userData!['phone'] == null ||
        _userData!['phone'].toString().trim().isEmpty) {
      missing.add('Telefone');
    }

    final address = _userData!['address'];
    if (address == null || address is! Map) {
      missing.add('Endereço completo');
    } else {
      if (address['street'] == null ||
          address['street'].toString().trim().isEmpty) {
        missing.add('Rua');
      }
      if (address['number'] == null ||
          address['number'].toString().trim().isEmpty) {
        missing.add('Número');
      }
      if (address['neighborhood'] == null ||
          address['neighborhood'].toString().trim().isEmpty) {
        missing.add('Bairro');
      }
      if (address['city'] == null ||
          address['city'].toString().trim().isEmpty) {
        missing.add('Cidade');
      }
      if (address['state'] == null ||
          address['state'].toString().trim().isEmpty) {
        missing.add('Estado');
      }
      if (address['zipCode'] == null ||
          address['zipCode'].toString().trim().isEmpty) {
        missing.add('CEP');
      }
    }

    return missing;
  }

  /// 📡 Carregar dados do usuário (simulação - substitua por Firebase/API real)
  Future<void> loadUserData(String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Substituir por chamada real ao Firebase/API
      await Future.delayed(const Duration(milliseconds: 500));

      // Dados de exemplo (substitua por dados reais do Firestore)
      _userData = {
        'uid': userId,
        'email': 'usuario@exemplo.com',
        'name': '', // Vazio para forçar completar
        'phone': '', // Vazio para forçar completar
        'address': null, // Nulo para forçar completar
        'createdAt': DateTime.now().toIso8601String(),
      };

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar dados: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// 💾 Atualizar dados do usuário
  Future<void> updateUserData(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Salvar no Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(data, SetOptions(merge: true));
        
        debugPrint('✅ [UserState] Dados salvos no Firestore');
        debugPrint('📋 [UserState] Dados: $data');
      }

      // Atualiza localmente
      _userData = {...?_userData, ...data};

      _loading = false;
      notifyListeners();

      debugPrint('✅ [UserState] Dados atualizados localmente');
      debugPrint('📋 [UserState] Cadastro completo: $isProfileComplete');
    } catch (e) {
      _error = 'Erro ao atualizar dados: $e';
      _loading = false;
      notifyListeners();
      debugPrint('❌ [UserState] Erro ao atualizar: $e');
      rethrow;
    }
  }

  /// Limpar dados do usuário (logout)
  void clearUserData() {
    _userData = null;
    _error = null;
    notifyListeners();
  }

  /// Simula login (para testes - substitua por autenticação real)
  Future<void> mockLogin() async {
    await loadUserData('mock_user_123');
  }
}
