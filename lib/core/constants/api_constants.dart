class ApiConstants {
  // 🔧 DESENVOLVIMENTO: Troque para true para usar proxy CORS local
  // Execute: node cors-proxy.js
  static const bool _useLocalProxy = false;
  
  // Base URL da API
  static const String _productionUrl = 'https://api-pedeja.vercel.app';
  static const String _proxyUrl = 'http://localhost:8080';
  
  static String get baseUrl => _useLocalProxy ? _proxyUrl : _productionUrl;
  
  // Endpoints de Auth
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authResetPassword = '/api/auth/reset-password';
  
  // Endpoints de Restaurantes
  static const String restaurants = '/api/mobile/restaurants';
  static String restaurantById(String id) => '/api/mobile/restaurants/$id';
  static String restaurantStatus(String id) => '/api/restaurants/$id/status';
  
  // Endpoints de Produtos
  static String restaurantProducts(String restaurantId) => 
      '/api/restaurants/$restaurantId/products';
  static String productDetail(String restaurantId, String productId) => 
      '/api/restaurants/$restaurantId/products/$productId';
  
  // Endpoint de Imagem (Proxy)
  static String imageProxy(String id, {String source = 'product', String type = 'thumb'}) =>
      '/api/image/$id?source=$source&type=$type';
  
  // Headers
  static const String contentTypeJson = 'application/json';
  static const String authorizationHeader = 'Authorization';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userNameKey = 'user_name';
}
