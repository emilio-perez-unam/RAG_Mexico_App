// Default stub implementation
abstract class ApiClient {
  Future<String> post(String url, Map<String, dynamic> body, Map<String, String> headers);
  
  factory ApiClient() => throw UnimplementedError('Platform not supported');
}