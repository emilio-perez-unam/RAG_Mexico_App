import 'dart:convert';
import 'dart:html' as html;
import 'api_client_stub.dart';

// Web implementation with JSONP or proxy fallback
class ApiClient {
  // Option 1: Use JSONP (if API supports it)
  Future<String> _jsonpRequest(String url, Map<String, dynamic> params) async {
    // JSONP only works if the API supports callback parameter
    // Most modern APIs don't support this
    throw UnimplementedError('JSONP not supported by OpenRouter');
  }
  
  // Option 2: Use a public CORS proxy (not recommended for production)
  Future<String> post(String url, Map<String, dynamic> body, Map<String, String> headers) async {
    // Using a public CORS proxy (for testing only!)
    // These proxies are unreliable and should not be used in production
    const corsProxy = 'https://corsproxy.io/?';
    final proxiedUrl = '$corsProxy${Uri.encodeComponent(url)}';
    
    final response = await html.HttpRequest.request(
      proxiedUrl,
      method: 'POST',
      requestHeaders: headers,
      sendData: jsonEncode(body),
    );
    
    return response.responseText ?? '';
  }
  
  factory ApiClient() => ApiClient._();
  ApiClient._();
}