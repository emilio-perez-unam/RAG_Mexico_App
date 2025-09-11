import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

/// Remote datasource for interacting with OpenRouter API
class OpenRouterDatasource {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'mistralai/mistral-7b-instruct';
  static const double _defaultTemperature = 0.7;
  static const int _defaultMaxTokens = 8192;

  final String apiKey;
  final String baseUrl;
  final Dio dio;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: false,
    ),
  );

  OpenRouterDatasource({
    required this.apiKey,
    String? baseUrl,
    required this.dio,
  }) : baseUrl = baseUrl ?? _baseUrl;

  /// Send a message to OpenRouter (alias for sendChatCompletion for compatibility)
  Future<OpenRouterResponse> sendMessage(
    String message, {
    String? model,
    double? temperature,
    int? maxTokens,
    List<Map<String, dynamic>>? previousMessages,
  }) async {
    return sendChatCompletion(
      message: message,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      previousMessages: previousMessages,
    );
  }

  /// Send a chat completion request to OpenRouter
  Future<OpenRouterResponse> sendChatCompletion({
    required String message,
    String? model,
    double? temperature,
    int? maxTokens,
    List<Map<String, dynamic>>? previousMessages,
  }) async {
    try {
      final messages = [
        if (previousMessages != null) ...previousMessages,
        {
          'role': 'user',
          'content': message,
        },
      ];

      final requestBody = {
        'model': model ?? _defaultModel,
        'messages': messages,
        'temperature': temperature ?? _defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokens,
      };

      // Debug logging
      _logger.d('===== OPENROUTER REQUEST DEBUG =====');
      _logger.d('URL: $baseUrl/chat/completions');
      _logger.d('Model: ${model ?? _defaultModel}');
      _logger.d('API Key (first 20 chars): ${apiKey.substring(0, 20)}...');
      _logger.d('Messages count: ${messages.length}');
      _logger.d('Temperature: ${temperature ?? _defaultTemperature}');
      _logger.d('Max tokens: ${maxTokens ?? _defaultMaxTokens}');
      _logger.d('====================================');

      _logger.i('Sending request to OpenRouter...');
      
      // For web platform, you need a backend proxy or edge function
      // Direct API calls will fail due to CORS
      if (kIsWeb) {
        _logger.w('WARNING: Direct OpenRouter API calls on web platform will fail due to CORS.');
        _logger.w('Configure a backend proxy or Supabase Edge Function for production.');
      }
      
      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://legalragmexico.com',
            'X-Title': 'Legal RAG Mexico',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
        data: requestBody,
      );
      _logger.i('Response received from OpenRouter');

      if (response.statusCode == 200) {
        var data = response.data;
        _logger.d('===== OPENROUTER SUCCESS RESPONSE =====');
        
        // Handle string response that might have extra whitespace
        if (data is String) {
          // Remove all the extra whitespace and newlines before the JSON
          final jsonStartIndex = data.indexOf('{');
          if (jsonStartIndex != -1) {
            final cleanJson = data.substring(jsonStartIndex);
            _logger.d('Cleaned JSON: ${cleanJson.substring(0, 200)}...');
            data = json.decode(cleanJson);
          } else {
            _logger.e('ERROR: No JSON found in response');
            throw OpenRouterException('Invalid response format');
          }
        }
        
        _logger.d('Parsed data type: ${data.runtimeType}');
        _logger.d('========================================');
        return OpenRouterResponse.fromJson(data);
      } else {
        throw OpenRouterException(
          'API request failed with status ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _logger.e('===== OPENROUTER ERROR =====');
      _logger.e('Status Code: ${e.response?.statusCode}');
      _logger.e('Error Message: ${e.response?.data}');
      _logger.e('============================');
      
      if (e.response?.statusCode == 401) {
        throw OpenRouterException('Authentication failed. Please check your API key.');
      }
      throw OpenRouterException('Network error: $e');
    } catch (e) {
      if (e is OpenRouterException) rethrow;
      throw OpenRouterException('Network error: $e');
    }
  }

  /// Get available models
  Future<List<OpenRouterModel>> getAvailableModels() async {
    try {
      if (kIsWeb) {
        _logger.w('WARNING: Direct OpenRouter API calls on web platform will fail due to CORS.');
      }
      
      final response = await dio.get(
        '$baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final models = (data['data'] as List)
            .map((model) => OpenRouterModel.fromJson(model))
            .toList();
        return models;
      } else {
        throw OpenRouterException(
          'Failed to fetch models: ${response.statusMessage}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is OpenRouterException) rethrow;
      throw OpenRouterException('Failed to fetch models: $e');
    }
  }

  /// Check API health status
  Future<bool> checkHealth() async {
    try {
      final models = await getAvailableModels();
      return models.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Response model for OpenRouter API
class OpenRouterResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<Choice> choices;
  final Usage usage;

  OpenRouterResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory OpenRouterResponse.fromJson(Map<String, dynamic> json) {
    return OpenRouterResponse(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      model: json['model'],
      choices: (json['choices'] as List)
          .map((choice) => Choice.fromJson(choice))
          .toList(),
      usage: Usage.fromJson(json['usage']),
    );
  }

  String get content => choices.isNotEmpty ? choices.first.message.content : '';
}

/// Choice model for API responses
class Choice {
  final int index;
  final Message message;
  final String finishReason;

  Choice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      index: json['index'],
      message: Message.fromJson(json['message']),
      finishReason: json['finish_reason'] ?? '',
    );
  }
}

/// Message model
class Message {
  final String role;
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

/// Usage statistics model
class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      promptTokens: json['prompt_tokens'],
      completionTokens: json['completion_tokens'],
      totalTokens: json['total_tokens'],
    );
  }

  /// Calculate approximate cost (example rates, adjust based on actual pricing)
  double calculateCost({
    double promptTokenRate = 0.001, // per 1K tokens
    double completionTokenRate = 0.002, // per 1K tokens
  }) {
    return (promptTokens / 1000 * promptTokenRate) +
        (completionTokens / 1000 * completionTokenRate);
  }
}

/// Model information
class OpenRouterModel {
  final String id;
  final String object;
  final int created;
  final String ownedBy;

  OpenRouterModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
  });

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    return OpenRouterModel(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      ownedBy: json['owned_by'],
    );
  }

  bool get isReasoningModel => id.contains('reason');
  bool get isDistillModel => id.contains('distill');
}

/// Custom exception for OpenRouter API errors
class OpenRouterException implements Exception {
  final String message;
  final int? statusCode;

  OpenRouterException(this.message, {this.statusCode});

  @override
  String toString() => 'OpenRouterException: $message';

  bool get isAuthError => statusCode == 401;
  bool get isRateLimitError => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}