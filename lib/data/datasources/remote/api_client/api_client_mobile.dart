import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client_stub.dart';

// Mobile/Desktop implementation - No CORS
class ApiClient {
  Future<String> post(String url, Map<String, dynamic> body, Map<String, String> headers) async {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }
  
  factory ApiClient() => ApiClient._();
  ApiClient._();
}