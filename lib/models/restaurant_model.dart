class RestaurantModel {
  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.isActive,
    required this.approved,
    required this.paymentStatus,
    this.email,
    this.ownerId,
    this.phone,
    this.imageUrl,
    this.imageThumbUrl,
    this.averageDeliveryTime,
    this.createdAt,
    this.updatedAt,
    this.apiIsOpen,
    this.minimumOrder = 0.0,
  });

  final String id;
  final String name;
  final String address;
  final bool isActive;
  final bool approved;
  final String paymentStatus;
  final String? email;
  final String? ownerId;
  final String? phone;
  final String? imageUrl;
  final String? imageThumbUrl;
  final int? averageDeliveryTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? apiIsOpen;
  final double minimumOrder;

  bool get isOpen => apiIsOpen ?? (approved && isActive && paymentStatus.toLowerCase() == 'adimplente');
  bool get canAcceptOrders => isOpen;

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    // Tenta buscar primeiro 'apiIsOpen', se não existir, usa 'isOpen'
    bool? apiIsOpenValue;
    if (json.containsKey('apiIsOpen')) {
      apiIsOpenValue = json['apiIsOpen'] as bool?;
    } else if (json.containsKey('isOpen')) {
      apiIsOpenValue = json['isOpen'] as bool?;
    }
    
    return RestaurantModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isActive: json['isActive'] == true,
      approved: json['approved'] == true,
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      email: json['email']?.toString(),
      ownerId: json['ownerId']?.toString(),
      phone: json['phone']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      imageThumbUrl: json['imageThumbUrl']?.toString(),
      averageDeliveryTime: json['averageDeliveryTime'] as int?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      apiIsOpen: apiIsOpenValue,
      minimumOrder: (json['minimumOrder'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'isActive': isActive,
      'approved': approved,
      'paymentStatus': paymentStatus,
      'email': email,
      'ownerId': ownerId,
      'phone': phone,
      'imageUrl': imageUrl,
      'imageThumbUrl': imageThumbUrl,
      'averageDeliveryTime': averageDeliveryTime,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'apiIsOpen': apiIsOpen,
      'minimumOrder': minimumOrder,
    };
  }
}

// Extensions para display
extension RestaurantDisplay on RestaurantModel {
  String get displayTitle => name.isNotEmpty ? name : 'Restaurante';
  
  String get displaySubtitle {
    if (address.isNotEmpty) return address;
    if (email != null && email!.isNotEmpty) return email!;
    return 'Endereço não disponível';
  }
  
  /// Retorna a URL da imagem usando o proxy da API para otimização
  /// Converte URLs do Firebase para o sistema de proxy inteligente
  String? get displayImage {
    final imgUrl = imageUrl ?? imageThumbUrl;
    
    // 🎯 Se a imagem está no Firebase, converte para API proxy
    if (imgUrl != null && imgUrl.contains('firebasestorage.googleapis.com')) {
      return 'https://api-pedeja.vercel.app/api/image/$id?source=restaurant&type=thumb';
    }
    
    return imgUrl; // URL normal se não for Firebase
  }
  
  String get displayStatus {
    if (!approved) return 'Pendente';
    if (!isActive) return 'Inativo';
    if (paymentStatus.toLowerCase() != 'adimplente') return 'Bloqueado';
    if (apiIsOpen == false) return 'Fechado';
    return 'Aberto';
  }
}