class BrandVariant {
  final String brandName;
  final double brandPrice;
  final int brandStock;
  final String? brandImageUrl;
  final String? brandSKU;
  
  BrandVariant({
    required this.brandName,
    required this.brandPrice,
    required this.brandStock,
    this.brandImageUrl,
    this.brandSKU,
  });
  
  factory BrandVariant.fromJson(Map<String, dynamic> json) => BrandVariant(
    brandName: json['brandName'] ?? '',
    brandPrice: (json['brandPrice'] ?? 0).toDouble(),
    brandStock: json['brandStock'] ?? 0,
    brandImageUrl: json['brandImageUrl'],
    brandSKU: json['brandSKU'],
  );
  
  Map<String, dynamic> toJson() => {
    'brandName': brandName,
    'brandPrice': brandPrice,
    'brandStock': brandStock,
    if (brandImageUrl != null) 'brandImageUrl': brandImageUrl,
    if (brandSKU != null) 'brandSKU': brandSKU,
  };
}
